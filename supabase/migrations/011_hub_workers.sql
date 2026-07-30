-- IPOSB: Hub workers (merged driver + dispatcher) + hub-first assignment
-- Run AFTER 010_shipment_geocodes.sql. Does NOT touch legacy BBB Express.

INSERT INTO roles (name, label) VALUES
  ('hub_worker', 'Hub Worker')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- HUB WORKERS
-- One field staff role per hub: pickup + delivery ops
-- ============================================================
CREATE TABLE IF NOT EXISTS hub_workers (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  hub_id            UUID NOT NULL REFERENCES hubs(id),
  preferred_zones   TEXT[] NOT NULL DEFAULT '{}',
  license_number    TEXT,
  vehicle_type      TEXT,
  vehicle_plate     TEXT,
  is_available      BOOLEAN NOT NULL DEFAULT TRUE,
  shift             TEXT NOT NULL DEFAULT 'day',
  current_lat       DOUBLE PRECISION,
  current_lng       DOUBLE PRECISION,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hub_workers_hub_avail
  ON hub_workers(hub_id, is_available);

CREATE INDEX IF NOT EXISTS idx_hub_workers_zones
  ON hub_workers USING GIN (preferred_zones);

ALTER TABLE hub_workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hub_workers_select_authenticated ON hub_workers;
CREATE POLICY hub_workers_select_authenticated ON hub_workers
  FOR SELECT TO authenticated USING (true);

-- Shipment FKs for hub-first assignment
ALTER TABLE shipments
  ADD COLUMN IF NOT EXISTS pickup_hub_worker_id UUID REFERENCES hub_workers(id),
  ADD COLUMN IF NOT EXISTS delivery_hub_worker_id UUID REFERENCES hub_workers(id);

CREATE INDEX IF NOT EXISTS idx_shipments_pickup_hub_worker
  ON shipments(pickup_hub_worker_id);
CREATE INDEX IF NOT EXISTS idx_shipments_delivery_hub_worker
  ON shipments(delivery_hub_worker_id);

-- ============================================================
-- Hub worker can read assigned shipments + hub queue
-- ============================================================
DROP POLICY IF EXISTS shipments_select_hub_worker ON shipments;
CREATE POLICY shipments_select_hub_worker ON shipments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM hub_workers hw
      WHERE hw.user_id = auth.uid()
        AND (
          hw.id = shipments.pickup_hub_worker_id
          OR hw.id = shipments.delivery_hub_worker_id
          OR hw.hub_id = shipments.origin_hub_id
          OR hw.hub_id = shipments.destination_hub_id
        )
    )
  );

DROP POLICY IF EXISTS shipment_history_select_hub_worker ON shipment_history;
CREATE POLICY shipment_history_select_hub_worker ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM shipments s
      JOIN hub_workers hw ON hw.user_id = auth.uid()
      WHERE s.id = shipment_history.shipment_id
        AND (
          hw.id = s.pickup_hub_worker_id
          OR hw.id = s.delivery_hub_worker_id
          OR hw.hub_id = s.origin_hub_id
          OR hw.hub_id = s.destination_hub_id
        )
    )
  );

-- ============================================================
-- ASSIGNMENT ENGINE — hub-first + preferred zones
-- ============================================================
CREATE OR REPLACE FUNCTION public.run_assignment_engine(p_shipment_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s                         shipments%ROWTYPE;
  rule                      routing_rules%ROWTYPE;
  v_pickup_hub_worker_id    UUID;
  v_delivery_hub_worker_id  UUID;
  v_storekeeper_id          UUID;
  v_eta                     TIMESTAMPTZ;
  v_steps                   JSONB := '[]'::JSONB;
  v_user_id                 UUID;
  v_missing                 TEXT[] := ARRAY[]::TEXT[];
BEGIN
  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
  END IF;

  IF auth.uid() IS DISTINCT FROM s.customer_id THEN
    RAISE EXCEPTION 'Not allowed to assign this shipment';
  END IF;

  IF s.status IS DISTINCT FROM 'pending' AND s.status IS DISTINCT FROM 'failed' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'skipped', true,
      'message', 'Shipment already assigned',
      'status', s.status
    );
  END IF;

  v_steps := v_steps || jsonb_build_array(
    jsonb_build_object('step', 'find_origin_zone', 'zone', s.origin_zone)
  );

  SELECT * INTO rule
  FROM routing_rules
  WHERE origin_zone = s.origin_zone
    AND destination_zone = s.destination_zone
    AND is_active = TRUE
  ORDER BY priority ASC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO shipment_history (shipment_id, status, description, location, performed_by)
    VALUES (
      s.id,
      'failed',
      'Assignment failed: no routing rule for '
        || s.origin_zone || ' → ' || s.destination_zone,
      s.origin_city,
      s.customer_id
    );

    UPDATE shipments
    SET status = 'failed', updated_at = NOW()
    WHERE id = s.id;

    RETURN jsonb_build_object(
      'ok', false,
      'error', 'No routing rule found for '
        || s.origin_zone || ' → ' || s.destination_zone
    );
  END IF;

  v_steps := v_steps || jsonb_build_array(
    jsonb_build_object(
      'step', 'hub_receive_order',
      'origin_hub', rule.origin_hub_id,
      'destination_hub', rule.destination_hub_id,
      'estimated_days', rule.estimated_days
    )
  );

  -- Origin hub worker: available at origin hub, prefers pickup zone
  SELECT id INTO v_pickup_hub_worker_id
  FROM hub_workers
  WHERE hub_id = rule.origin_hub_id
    AND is_available = TRUE
    AND (
      preferred_zones IS NULL
      OR cardinality(preferred_zones) = 0
      OR s.origin_zone = ANY (preferred_zones)
    )
  ORDER BY created_at
  LIMIT 1;

  IF v_pickup_hub_worker_id IS NULL THEN
    -- Fallback: any available worker at origin hub
    SELECT id INTO v_pickup_hub_worker_id
    FROM hub_workers
    WHERE hub_id = rule.origin_hub_id
      AND is_available = TRUE
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF v_pickup_hub_worker_id IS NULL THEN
    v_missing := array_append(v_missing, 'pickup_hub_worker');
  END IF;

  -- Destination hub worker for last-mile later
  SELECT id INTO v_delivery_hub_worker_id
  FROM hub_workers
  WHERE hub_id = rule.destination_hub_id
    AND is_available = TRUE
    AND (
      preferred_zones IS NULL
      OR cardinality(preferred_zones) = 0
      OR s.destination_zone = ANY (preferred_zones)
    )
  ORDER BY created_at
  LIMIT 1;

  IF v_delivery_hub_worker_id IS NULL THEN
    SELECT id INTO v_delivery_hub_worker_id
    FROM hub_workers
    WHERE hub_id = rule.destination_hub_id
      AND is_available = TRUE
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF v_delivery_hub_worker_id IS NULL THEN
    v_missing := array_append(v_missing, 'delivery_hub_worker');
  END IF;

  SELECT id INTO v_storekeeper_id
  FROM storekeepers
  WHERE hub_id = rule.origin_hub_id AND is_active = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_storekeeper_id IS NULL THEN
    v_missing := array_append(v_missing, 'storekeeper');
  END IF;

  v_eta := NOW() + make_interval(days => rule.estimated_days);

  UPDATE shipments SET
    pickup_hub_worker_id      = v_pickup_hub_worker_id,
    delivery_hub_worker_id    = v_delivery_hub_worker_id,
    origin_drop_point_id      = rule.origin_drop_point_id,
    origin_hub_id             = rule.origin_hub_id,
    storekeeper_id            = v_storekeeper_id,
    sorting_hub_id            = rule.sorting_hub_id,
    destination_hub_id        = rule.destination_hub_id,
    destination_drop_point_id = rule.dest_drop_point_id,
    -- Clear legacy split-role FKs (kept for schema compatibility)
    pickup_dispatcher_id      = NULL,
    pickup_driver_id          = NULL,
    delivery_dispatcher_id    = NULL,
    delivery_driver_id        = NULL,
    eta                       = v_eta,
    status                    = 'assigned',
    updated_at                = NOW()
  WHERE id = s.id;

  INSERT INTO shipment_history (shipment_id, status, description, location, performed_by)
  VALUES (
    s.id,
    'assigned',
    'Origin hub received order '
      || s.origin_zone || ' → ' || s.destination_zone
      || CASE
           WHEN array_length(v_missing, 1) IS NULL THEN ''
           ELSE ' (missing staff: ' || array_to_string(v_missing, ', ') || ')'
         END,
    s.origin_city || ' → ' || s.destination_city,
    s.customer_id
  );

  IF v_pickup_hub_worker_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM hub_workers WHERE id = v_pickup_hub_worker_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'New pickup job',
      'Pickup ' || s.tracking_number || ' at ' || s.origin_address,
      'task'
    );
  END IF;

  IF v_storekeeper_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM storekeepers WHERE id = v_storekeeper_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'Incoming parcel',
      'Expect ' || s.tracking_number || ' at origin hub',
      'task'
    );
  END IF;

  IF v_delivery_hub_worker_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM hub_workers WHERE id = v_delivery_hub_worker_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'Delivery job queued',
      'Deliver ' || s.tracking_number || ' to ' || s.destination_address,
      'task'
    );
  END IF;

  INSERT INTO notifications (user_id, shipment_id, title, body, type)
  VALUES (
    s.customer_id, s.id,
    'Shipment assigned',
    'Tracking ' || s.tracking_number || ' received by origin hub. ETA '
      || to_char(v_eta AT TIME ZONE 'UTC', 'YYYY-MM-DD'),
    'status'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'shipment_id', s.id,
    'tracking_number', s.tracking_number,
    'status', 'assigned',
    'eta', v_eta,
    'missing_staff', to_jsonb(v_missing),
    'assignments', jsonb_build_object(
      'pickup_hub_worker_id', v_pickup_hub_worker_id,
      'delivery_hub_worker_id', v_delivery_hub_worker_id,
      'origin_drop_point_id', rule.origin_drop_point_id,
      'origin_hub_id', rule.origin_hub_id,
      'storekeeper_id', v_storekeeper_id,
      'sorting_hub_id', rule.sorting_hub_id,
      'destination_hub_id', rule.destination_hub_id,
      'destination_drop_point_id', rule.dest_drop_point_id
    ),
    'steps', v_steps
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_assignment_engine(UUID) TO authenticated;

-- ============================================================
-- Hub worker status updates (pickup + delivery on one role)
-- ============================================================
CREATE OR REPLACE FUNCTION public.hub_worker_update_shipment_status(
  p_shipment_id UUID,
  p_new_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s              shipments%ROWTYPE;
  v_worker_id    UUID;
  v_is_pickup    BOOLEAN := FALSE;
  v_is_delivery  BOOLEAN := FALSE;
  v_allowed      BOOLEAN := FALSE;
  v_description  TEXT;
  v_location     TEXT;
BEGIN
  SELECT id INTO v_worker_id
  FROM hub_workers
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'Current user is not a hub worker';
  END IF;

  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  v_is_pickup := (s.pickup_hub_worker_id = v_worker_id);
  v_is_delivery := (s.delivery_hub_worker_id = v_worker_id);

  IF NOT v_is_pickup AND NOT v_is_delivery THEN
    RAISE EXCEPTION 'Shipment is not assigned to this hub worker';
  END IF;

  IF v_is_pickup THEN
    IF s.status = 'assigned' AND p_new_status = 'pickup_scheduled' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Pickup scheduled by hub worker');
      v_location := s.origin_city;
    ELSIF s.status IN ('assigned', 'pickup_scheduled') AND p_new_status = 'picked_up' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Parcel picked up from sender');
      v_location := s.origin_address;
    ELSIF s.status = 'picked_up' AND p_new_status = 'at_origin_drop_point' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Parcel handed off to origin drop point');
      v_location := s.origin_zone;
    END IF;
  END IF;

  IF v_is_delivery THEN
    IF s.status IN (
         'at_origin_drop_point',
         'at_origin_hub',
         'sorting',
         'in_transit',
         'at_destination_hub',
         'at_destination_drop_point'
       )
       AND p_new_status = 'out_for_delivery' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Out for delivery');
      v_location := s.destination_city;
    ELSIF s.status = 'out_for_delivery' AND p_new_status = 'delivered' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Parcel delivered to recipient');
      v_location := s.destination_address;
    END IF;
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid status transition: % → % for this hub worker',
      s.status, p_new_status;
  END IF;

  UPDATE shipments
  SET status = p_new_status,
      updated_at = NOW()
  WHERE id = s.id;

  INSERT INTO shipment_history (
    shipment_id, status, description, location, performed_by
  ) VALUES (
    s.id,
    p_new_status,
    v_description,
    v_location,
    auth.uid()
  );

  INSERT INTO notifications (user_id, shipment_id, title, body, type)
  VALUES (
    s.customer_id,
    s.id,
    'Shipment update',
    'Tracking ' || s.tracking_number || ': ' || v_description,
    'status'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'shipment_id', s.id,
    'from_status', s.status,
    'to_status', p_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.hub_worker_update_shipment_status(UUID, TEXT, TEXT)
  TO authenticated;

-- IPOSB Phase 4: Assignment Engine RPC + staff table RLS
-- Run AFTER 004_shipment_history_trigger.sql

-- ============================================================
-- Staff tables: authenticated read (demo dashboards later)
-- ============================================================
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE storekeepers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drivers_select_authenticated ON drivers;
CREATE POLICY drivers_select_authenticated ON drivers
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS dispatchers_select_authenticated ON dispatchers;
CREATE POLICY dispatchers_select_authenticated ON dispatchers
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS storekeepers_select_authenticated ON storekeepers;
CREATE POLICY storekeepers_select_authenticated ON storekeepers
  FOR SELECT TO authenticated USING (true);

-- ============================================================
-- ASSIGNMENT ENGINE (SECURITY DEFINER)
-- Simulates intelligent routing using routing_rules + staff tables
-- ============================================================
CREATE OR REPLACE FUNCTION public.run_assignment_engine(p_shipment_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s                       shipments%ROWTYPE;
  rule                    routing_rules%ROWTYPE;
  v_pickup_dispatcher_id  UUID;
  v_pickup_driver_id      UUID;
  v_storekeeper_id        UUID;
  v_delivery_dispatcher_id UUID;
  v_delivery_driver_id    UUID;
  v_eta                   TIMESTAMPTZ;
  v_steps                 JSONB := '[]'::JSONB;
  v_user_id               UUID;
  v_missing               TEXT[] := ARRAY[]::TEXT[];
BEGIN
  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
  END IF;

  -- Only the owning customer may trigger assignment (demo safety).
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
    jsonb_build_object('step', 'find_pickup_zone', 'zone', s.origin_zone)
  );

  -- Find routing rule (mock intelligent routing)
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
      'step', 'routing_rule_matched',
      'origin_hub', rule.origin_hub_id,
      'sorting_hub', rule.sorting_hub_id,
      'destination_hub', rule.destination_hub_id,
      'estimated_days', rule.estimated_days
    )
  );

  -- Pickup dispatcher (origin zone)
  SELECT id INTO v_pickup_dispatcher_id
  FROM dispatchers
  WHERE zone = s.origin_zone AND is_active = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_pickup_dispatcher_id IS NULL THEN
    v_missing := array_append(v_missing, 'pickup_dispatcher');
  END IF;

  -- Available pickup driver (origin zone)
  SELECT id INTO v_pickup_driver_id
  FROM drivers
  WHERE zone = s.origin_zone AND is_available = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_pickup_driver_id IS NULL THEN
    v_missing := array_append(v_missing, 'pickup_driver');
  END IF;

  -- Storekeeper at origin hub
  SELECT id INTO v_storekeeper_id
  FROM storekeepers
  WHERE hub_id = rule.origin_hub_id AND is_active = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_storekeeper_id IS NULL THEN
    v_missing := array_append(v_missing, 'storekeeper');
  END IF;

  -- Delivery dispatcher (destination zone)
  SELECT id INTO v_delivery_dispatcher_id
  FROM dispatchers
  WHERE zone = s.destination_zone AND is_active = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_delivery_dispatcher_id IS NULL THEN
    v_missing := array_append(v_missing, 'delivery_dispatcher');
  END IF;

  -- Delivery driver (destination zone)
  SELECT id INTO v_delivery_driver_id
  FROM drivers
  WHERE zone = s.destination_zone AND is_available = TRUE
  ORDER BY created_at
  LIMIT 1;
  IF v_delivery_driver_id IS NULL THEN
    v_missing := array_append(v_missing, 'delivery_driver');
  END IF;

  v_eta := NOW() + make_interval(days => rule.estimated_days);

  UPDATE shipments SET
    pickup_dispatcher_id      = v_pickup_dispatcher_id,
    pickup_driver_id          = v_pickup_driver_id,
    origin_drop_point_id      = rule.origin_drop_point_id,
    origin_hub_id             = rule.origin_hub_id,
    storekeeper_id            = v_storekeeper_id,
    sorting_hub_id            = rule.sorting_hub_id,
    destination_hub_id        = rule.destination_hub_id,
    destination_drop_point_id = rule.dest_drop_point_id,
    delivery_dispatcher_id    = v_delivery_dispatcher_id,
    delivery_driver_id        = v_delivery_driver_id,
    eta                       = v_eta,
    status                    = 'assigned',
    updated_at                = NOW()
  WHERE id = s.id;

  INSERT INTO shipment_history (shipment_id, status, description, location, performed_by)
  VALUES (
    s.id,
    'assigned',
    'Assignment Engine completed route '
      || s.origin_zone || ' → ' || s.destination_zone
      || CASE
           WHEN array_length(v_missing, 1) IS NULL THEN ''
           ELSE ' (missing staff: ' || array_to_string(v_missing, ', ') || ')'
         END,
    s.origin_city || ' → ' || s.destination_city,
    s.customer_id
  );

  -- Notify assigned staff (by their user_id)
  IF v_pickup_dispatcher_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM dispatchers WHERE id = v_pickup_dispatcher_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'New pickup dispatch',
      'Shipment ' || s.tracking_number || ' assigned in zone ' || s.origin_zone,
      'task'
    );
  END IF;

  IF v_pickup_driver_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM drivers WHERE id = v_pickup_driver_id;
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

  IF v_delivery_dispatcher_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM dispatchers WHERE id = v_delivery_dispatcher_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'Delivery dispatch queued',
      'Shipment ' || s.tracking_number || ' headed to ' || s.destination_zone,
      'task'
    );
  END IF;

  IF v_delivery_driver_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM drivers WHERE id = v_delivery_driver_id;
    INSERT INTO notifications (user_id, shipment_id, title, body, type)
    VALUES (
      v_user_id, s.id,
      'Delivery job assigned',
      'Deliver ' || s.tracking_number || ' to ' || s.destination_address,
      'task'
    );
  END IF;

  -- Customer confirmation
  INSERT INTO notifications (user_id, shipment_id, title, body, type)
  VALUES (
    s.customer_id, s.id,
    'Shipment assigned',
    'Tracking ' || s.tracking_number || ' is assigned. ETA '
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
      'pickup_dispatcher_id', v_pickup_dispatcher_id,
      'pickup_driver_id', v_pickup_driver_id,
      'origin_drop_point_id', rule.origin_drop_point_id,
      'origin_hub_id', rule.origin_hub_id,
      'storekeeper_id', v_storekeeper_id,
      'sorting_hub_id', rule.sorting_hub_id,
      'destination_hub_id', rule.destination_hub_id,
      'destination_drop_point_id', rule.dest_drop_point_id,
      'delivery_dispatcher_id', v_delivery_dispatcher_id,
      'delivery_driver_id', v_delivery_driver_id
    ),
    'steps', v_steps
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_assignment_engine(UUID) TO authenticated;

-- Allow SECURITY DEFINER function to insert notifications for any user
-- (function runs as owner; no extra policy needed if table owner is postgres/supabase_admin)
-- Ensure notifications insert policy does not block definer... SECURITY DEFINER bypasses RLS.

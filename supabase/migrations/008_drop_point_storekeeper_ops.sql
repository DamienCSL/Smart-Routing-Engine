-- IPOSB Phase 7: Drop Point + Storekeeper ops
-- Run AFTER 007_dispatcher_ops.sql

-- ============================================================
-- Drop point operators can read shipments at their drop points
-- ============================================================
DROP POLICY IF EXISTS shipments_select_drop_point ON shipments;
CREATE POLICY shipments_select_drop_point ON shipments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM drop_points dp
      WHERE dp.operator_id = auth.uid()
        AND (
          dp.id = shipments.origin_drop_point_id
          OR dp.id = shipments.destination_drop_point_id
        )
    )
  );

DROP POLICY IF EXISTS shipment_history_select_drop_point ON shipment_history;
CREATE POLICY shipment_history_select_drop_point ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM shipments s
      JOIN drop_points dp ON dp.operator_id = auth.uid()
      WHERE s.id = shipment_history.shipment_id
        AND (
          dp.id = s.origin_drop_point_id
          OR dp.id = s.destination_drop_point_id
        )
    )
  );

-- ============================================================
-- Storekeepers can read shipments for their hub
-- ============================================================
DROP POLICY IF EXISTS shipments_select_storekeeper ON shipments;
CREATE POLICY shipments_select_storekeeper ON shipments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM storekeepers sk
      WHERE sk.user_id = auth.uid()
        AND sk.is_active = TRUE
        AND (
          sk.id = shipments.storekeeper_id
          OR sk.hub_id = shipments.origin_hub_id
          OR sk.hub_id = shipments.sorting_hub_id
          OR sk.hub_id = shipments.destination_hub_id
        )
    )
  );

DROP POLICY IF EXISTS shipment_history_select_storekeeper ON shipment_history;
CREATE POLICY shipment_history_select_storekeeper ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM shipments s
      JOIN storekeepers sk ON sk.user_id = auth.uid() AND sk.is_active = TRUE
      WHERE s.id = shipment_history.shipment_id
        AND (
          sk.id = s.storekeeper_id
          OR sk.hub_id = s.origin_hub_id
          OR sk.hub_id = s.sorting_hub_id
          OR sk.hub_id = s.destination_hub_id
        )
    )
  );

-- ============================================================
-- Drop point status update
-- ============================================================
CREATE OR REPLACE FUNCTION public.drop_point_update_shipment_status(
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
  s            shipments%ROWTYPE;
  v_dp_id      UUID;
  v_is_origin  BOOLEAN := FALSE;
  v_is_dest    BOOLEAN := FALSE;
  v_allowed    BOOLEAN := FALSE;
  v_description TEXT;
  v_location   TEXT;
BEGIN
  SELECT id INTO v_dp_id
  FROM drop_points
  WHERE operator_id = auth.uid()
  LIMIT 1;

  IF v_dp_id IS NULL THEN
    RAISE EXCEPTION 'Current user is not a drop point operator';
  END IF;

  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  v_is_origin := (s.origin_drop_point_id = v_dp_id);
  v_is_dest := (s.destination_drop_point_id = v_dp_id);

  IF NOT v_is_origin AND NOT v_is_dest THEN
    RAISE EXCEPTION 'Shipment is not assigned to this drop point';
  END IF;

  -- Origin drop point: receive handoff → forward to hub
  IF v_is_origin THEN
    IF s.status = 'at_origin_drop_point' AND p_new_status = 'at_origin_hub' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Forwarded from origin drop point to origin hub');
      v_location := s.origin_zone;
    END IF;
  END IF;

  -- Destination drop point: receive from hub → ready for delivery
  IF v_is_dest THEN
    IF s.status IN ('in_transit', 'at_destination_hub')
       AND p_new_status = 'at_destination_drop_point' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Received at destination drop point');
      v_location := s.destination_city;
    END IF;
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid status transition: % → % for this drop point',
      s.status, p_new_status;
  END IF;

  UPDATE shipments
  SET status = p_new_status, updated_at = NOW()
  WHERE id = s.id;

  INSERT INTO shipment_history (
    shipment_id, status, description, location, performed_by
  ) VALUES (
    s.id, p_new_status, v_description, v_location, auth.uid()
  );

  INSERT INTO notifications (user_id, shipment_id, title, body, type)
  VALUES (
    s.customer_id, s.id, 'Shipment update',
    'Tracking ' || s.tracking_number || ': ' || v_description, 'status'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'shipment_id', s.id,
    'from_status', s.status,
    'to_status', p_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.drop_point_update_shipment_status(UUID, TEXT, TEXT)
  TO authenticated;

-- ============================================================
-- Storekeeper status update
-- ============================================================
CREATE OR REPLACE FUNCTION public.storekeeper_update_shipment_status(
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
  v_sk_id        UUID;
  v_hub_id       UUID;
  v_allowed      BOOLEAN := FALSE;
  v_description  TEXT;
  v_location     TEXT;
BEGIN
  SELECT id, hub_id INTO v_sk_id, v_hub_id
  FROM storekeepers
  WHERE user_id = auth.uid() AND is_active = TRUE
  LIMIT 1;

  IF v_sk_id IS NULL THEN
    RAISE EXCEPTION 'Current user is not a storekeeper';
  END IF;

  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  IF NOT (
    s.storekeeper_id = v_sk_id
    OR s.origin_hub_id = v_hub_id
    OR s.sorting_hub_id = v_hub_id
    OR s.destination_hub_id = v_hub_id
  ) THEN
    RAISE EXCEPTION 'Shipment is not assigned to this storekeeper hub';
  END IF;

  -- Receive at origin hub
  IF s.status = 'at_origin_hub' AND p_new_status = 'sorting' THEN
    v_allowed := TRUE;
    v_description := COALESCE(p_note, 'Parcel entered sorting at origin hub');
    v_location := s.origin_zone;

  -- Dispatch outbound after sorting
  ELSIF s.status = 'sorting' AND p_new_status = 'in_transit' THEN
    v_allowed := TRUE;
    v_description := COALESCE(p_note, 'Sorted and dispatched to destination lane');
    v_location := s.origin_zone || ' → ' || s.destination_zone;

  -- Arrive at destination hub (demo shortcut from in_transit)
  ELSIF s.status = 'in_transit' AND p_new_status = 'at_destination_hub' THEN
    v_allowed := TRUE;
    v_description := COALESCE(p_note, 'Arrived at destination hub');
    v_location := s.destination_zone;
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid status transition: % → % for storekeeper',
      s.status, p_new_status;
  END IF;

  UPDATE shipments
  SET status = p_new_status, updated_at = NOW()
  WHERE id = s.id;

  INSERT INTO shipment_history (
    shipment_id, status, description, location, performed_by
  ) VALUES (
    s.id, p_new_status, v_description, v_location, auth.uid()
  );

  INSERT INTO notifications (user_id, shipment_id, title, body, type)
  VALUES (
    s.customer_id, s.id, 'Shipment update',
    'Tracking ' || s.tracking_number || ': ' || v_description, 'status'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'shipment_id', s.id,
    'from_status', s.status,
    'to_status', p_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.storekeeper_update_shipment_status(UUID, TEXT, TEXT)
  TO authenticated;

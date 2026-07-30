-- IPOSB Phase 5: Driver task visibility + status update RPC
-- Run AFTER 005_assignment_engine.sql

-- ============================================================
-- Drivers can read shipments assigned to them
-- ============================================================
DROP POLICY IF EXISTS shipments_select_assigned_driver ON shipments;
CREATE POLICY shipments_select_assigned_driver ON shipments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.user_id = auth.uid()
        AND (
          d.id = shipments.pickup_driver_id
          OR d.id = shipments.delivery_driver_id
        )
    )
  );

DROP POLICY IF EXISTS shipment_history_select_driver ON shipment_history;
CREATE POLICY shipment_history_select_driver ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM shipments s
      JOIN drivers d ON d.user_id = auth.uid()
      WHERE s.id = shipment_history.shipment_id
        AND (
          d.id = s.pickup_driver_id
          OR d.id = s.delivery_driver_id
        )
    )
  );

-- ============================================================
-- Driver status update (SECURITY DEFINER)
-- ============================================================
CREATE OR REPLACE FUNCTION public.driver_update_shipment_status(
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
  v_driver_id    UUID;
  v_is_pickup    BOOLEAN := FALSE;
  v_is_delivery  BOOLEAN := FALSE;
  v_allowed      BOOLEAN := FALSE;
  v_description  TEXT;
  v_location     TEXT;
BEGIN
  SELECT id INTO v_driver_id
  FROM drivers
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Current user is not a driver';
  END IF;

  SELECT * INTO s FROM shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  v_is_pickup := (s.pickup_driver_id = v_driver_id);
  v_is_delivery := (s.delivery_driver_id = v_driver_id);

  IF NOT v_is_pickup AND NOT v_is_delivery THEN
    RAISE EXCEPTION 'Shipment is not assigned to this driver';
  END IF;

  -- Pickup driver transitions
  IF v_is_pickup THEN
    IF s.status = 'assigned' AND p_new_status = 'pickup_scheduled' THEN
      v_allowed := TRUE;
      v_description := COALESCE(p_note, 'Pickup scheduled by driver');
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

  -- Delivery driver transitions
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
    RAISE EXCEPTION 'Invalid status transition: % → % for this driver role',
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

GRANT EXECUTE ON FUNCTION public.driver_update_shipment_status(UUID, TEXT, TEXT)
  TO authenticated;

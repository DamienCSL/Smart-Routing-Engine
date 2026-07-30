-- IPOSB Phase 6: Dispatcher zone visibility
-- Run AFTER 006_driver_ops.sql

-- Dispatchers can read shipments touching their zone (origin or destination).
DROP POLICY IF EXISTS shipments_select_dispatcher_zone ON shipments;
CREATE POLICY shipments_select_dispatcher_zone ON shipments
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM dispatchers d
      WHERE d.user_id = auth.uid()
        AND d.is_active = TRUE
        AND (
          shipments.origin_zone = d.zone
          OR shipments.destination_zone = d.zone
        )
    )
  );

DROP POLICY IF EXISTS shipment_history_select_dispatcher ON shipment_history;
CREATE POLICY shipment_history_select_dispatcher ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM shipments s
      JOIN dispatchers d ON d.user_id = auth.uid() AND d.is_active = TRUE
      WHERE s.id = shipment_history.shipment_id
        AND (s.origin_zone = d.zone OR s.destination_zone = d.zone)
    )
  );

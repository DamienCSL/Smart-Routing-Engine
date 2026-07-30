-- IPOSB Phase 3: Customer shipment policies + history insert
-- Run AFTER 002_auth_rls.sql

-- Customers may insert the initial history row for their own shipments.
DROP POLICY IF EXISTS shipment_history_insert_customer ON shipment_history;
CREATE POLICY shipment_history_insert_customer ON shipment_history
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.id = shipment_history.shipment_id
        AND s.customer_id = auth.uid()
    )
  );

-- Allow customers to read routing zones indirectly later (hubs/drop points read-only).
ALTER TABLE hubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE drop_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE routing_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hubs_select_authenticated ON hubs;
CREATE POLICY hubs_select_authenticated ON hubs
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS drop_points_select_authenticated ON drop_points;
CREATE POLICY drop_points_select_authenticated ON drop_points
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS routing_rules_select_authenticated ON routing_rules;
CREATE POLICY routing_rules_select_authenticated ON routing_rules
  FOR SELECT TO authenticated USING (true);

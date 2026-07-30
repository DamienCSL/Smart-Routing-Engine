-- IPOSB Phase 3 fix: auto-create shipment_history via trigger
-- Run this in Supabase SQL Editor (fixes RLS violation on history insert)

-- ============================================================
-- Initial history row is created by the database (bypasses RLS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_initial_shipment_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.shipment_history (
    shipment_id,
    status,
    description,
    location,
    performed_by
  ) VALUES (
    NEW.id,
    NEW.status,
    'Shipment created — awaiting intelligent assignment',
    NEW.origin_city || ', ' || NEW.origin_zone,
    NEW.customer_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shipment_initial_history ON shipments;
CREATE TRIGGER trg_shipment_initial_history
  AFTER INSERT ON shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.create_initial_shipment_history();

-- Keep / add customer insert policy for later status updates from the app
DROP POLICY IF EXISTS shipment_history_insert_customer ON shipment_history;
CREATE POLICY shipment_history_insert_customer ON shipment_history
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.id = shipment_history.shipment_id
        AND s.customer_id = auth.uid()
    )
  );

-- Read policies for logistics tables (safe if already applied)
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

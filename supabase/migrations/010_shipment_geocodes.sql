-- IPOSB: Persist customer-picked geocodes on shipments (Sabah last-mile)
ALTER TABLE shipments
  ADD COLUMN IF NOT EXISTS origin_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS origin_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS destination_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION;

COMMENT ON COLUMN shipments.origin_lat IS 'Customer-pinned pickup latitude (Sabah)';
COMMENT ON COLUMN shipments.origin_lng IS 'Customer-pinned pickup longitude (Sabah)';
COMMENT ON COLUMN shipments.destination_lat IS 'Customer-pinned delivery latitude (Sabah)';
COMMENT ON COLUMN shipments.destination_lng IS 'Customer-pinned delivery longitude (Sabah)';

-- IPOSB Demo Seed Data — Sabah, Malaysia
-- Run AFTER 001_initial_schema.sql and AFTER creating auth users
--
-- Logistics zones (stable codes):
--   KK-METRO    Kota Kinabalu, Penampang, Putatan
--   WEST-COAST  Papar, Tuaran, Kota Belud, Kudat
--   INTERIOR    Ranau, Tambunan, Keningau, Tenom, Beaufort
--   SANDAKAN    Sandakan, Beluran, Kinabatangan, Telupid
--   TAWAU       Tawau, Lahad Datu, Semporna, Kunak
--
-- Demo corridor: KK-METRO → SANDAKAN (via INTERIOR sorting)

-- Hubs (upsert so re-seed refreshes PH → Sabah content)
INSERT INTO hubs (code, name, address, city, province, zone, latitude, longitude, hub_type) VALUES
  (
    'HUB-ON-01',
    'Kota Kinabalu Origin Hub',
    'Lot 12, Inanam Industrial Area',
    'Kota Kinabalu',
    'Sabah',
    'KK-METRO',
    5.9950,
    116.1180,
    'origin'
  ),
  (
    'HUB-SH-01',
    'Ranau Sorting Hub',
    'KM 1, Jalan Ranau–Tambunan',
    'Ranau',
    'Sabah',
    'INTERIOR',
    5.9530,
    116.6640,
    'sorting'
  ),
  (
    'HUB-DH-01',
    'Sandakan Destination Hub',
    'Batu 7, Jalan Labuk',
    'Sandakan',
    'Sabah',
    'SANDAKAN',
    5.8750,
    118.0750,
    'destination'
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  city = EXCLUDED.city,
  province = EXCLUDED.province,
  zone = EXCLUDED.zone,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  hub_type = EXCLUDED.hub_type;

-- Drop points
INSERT INTO drop_points (code, name, address, city, province, zone, latitude, longitude, hub_id) VALUES
  (
    'DP-ON-01',
    'KK Likas Drop Point',
    'Likas Square, Jalan Tuaran',
    'Kota Kinabalu',
    'Sabah',
    'KK-METRO',
    5.9965,
    116.1010,
    (SELECT id FROM hubs WHERE code = 'HUB-ON-01')
  ),
  (
    'DP-DH-01',
    'Sandakan Town Drop Point',
    'Harbour Town, Jalan Pryer',
    'Sandakan',
    'Sabah',
    'SANDAKAN',
    5.8400,
    118.1170,
    (SELECT id FROM hubs WHERE code = 'HUB-DH-01')
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  city = EXCLUDED.city,
  province = EXCLUDED.province,
  zone = EXCLUDED.zone,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  hub_id = EXCLUDED.hub_id;

-- Remove legacy PH demo rule if present
DELETE FROM routing_rules
WHERE origin_zone = 'NCR-NORTH'
  AND destination_zone = 'VISAYAS';

-- Routing Rule: KK-METRO → SANDAKAN
INSERT INTO routing_rules (
  origin_zone, destination_zone,
  origin_hub_id, sorting_hub_id, destination_hub_id,
  origin_drop_point_id, dest_drop_point_id,
  priority, estimated_days
) VALUES (
  'KK-METRO', 'SANDAKAN',
  (SELECT id FROM hubs WHERE code = 'HUB-ON-01'),
  (SELECT id FROM hubs WHERE code = 'HUB-SH-01'),
  (SELECT id FROM hubs WHERE code = 'HUB-DH-01'),
  (SELECT id FROM drop_points WHERE code = 'DP-ON-01'),
  (SELECT id FROM drop_points WHERE code = 'DP-DH-01'),
  1, 2
) ON CONFLICT (origin_zone, destination_zone, priority) DO UPDATE SET
  origin_hub_id = EXCLUDED.origin_hub_id,
  sorting_hub_id = EXCLUDED.sorting_hub_id,
  destination_hub_id = EXCLUDED.destination_hub_id,
  origin_drop_point_id = EXCLUDED.origin_drop_point_id,
  dest_drop_point_id = EXCLUDED.dest_drop_point_id,
  estimated_days = EXCLUDED.estimated_days;

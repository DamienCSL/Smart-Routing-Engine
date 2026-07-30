-- IPOSB Initial Schema
-- Run this in Supabase SQL Editor (Phase 1)

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ROLES
-- ============================================================
CREATE TABLE IF NOT EXISTS roles (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO roles (name, label) VALUES
  ('customer',    'Customer'),
  ('driver',      'Driver'),
  ('dispatcher',  'Dispatcher'),
  ('drop_point',  'Drop Point'),
  ('storekeeper', 'Storekeeper'),
  ('admin',       'Admin')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- USERS (extends Supabase auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT NOT NULL,
  phone       TEXT,
  role_id     UUID NOT NULL REFERENCES roles(id),
  avatar_url  TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- HUBS
-- ============================================================
CREATE TABLE IF NOT EXISTS hubs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  address     TEXT NOT NULL,
  city        TEXT NOT NULL,
  province    TEXT NOT NULL,
  zone        TEXT NOT NULL,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  hub_type    TEXT NOT NULL CHECK (hub_type IN ('origin', 'sorting', 'destination')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DROP POINTS
-- ============================================================
CREATE TABLE IF NOT EXISTS drop_points (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  address     TEXT NOT NULL,
  city        TEXT NOT NULL,
  province    TEXT NOT NULL,
  zone        TEXT NOT NULL,
  hub_id      UUID NOT NULL REFERENCES hubs(id),
  operator_id UUID REFERENCES users(id),
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DRIVERS
-- ============================================================
CREATE TABLE IF NOT EXISTS drivers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  license_number  TEXT NOT NULL,
  vehicle_type    TEXT NOT NULL,
  vehicle_plate   TEXT NOT NULL,
  zone            TEXT NOT NULL,
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,
  current_lat     DOUBLE PRECISION,
  current_lng     DOUBLE PRECISION,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DISPATCHERS
-- ============================================================
CREATE TABLE IF NOT EXISTS dispatchers (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  zone        TEXT NOT NULL,
  hub_id      UUID REFERENCES hubs(id),
  shift       TEXT NOT NULL DEFAULT 'day',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- STOREKEEPERS
-- ============================================================
CREATE TABLE IF NOT EXISTS storekeepers (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  hub_id      UUID NOT NULL REFERENCES hubs(id),
  shift       TEXT NOT NULL DEFAULT 'day',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ROUTING RULES (mock intelligent routing)
-- ============================================================
CREATE TABLE IF NOT EXISTS routing_rules (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  origin_zone           TEXT NOT NULL,
  destination_zone      TEXT NOT NULL,
  origin_hub_id         UUID NOT NULL REFERENCES hubs(id),
  sorting_hub_id        UUID NOT NULL REFERENCES hubs(id),
  destination_hub_id    UUID NOT NULL REFERENCES hubs(id),
  origin_drop_point_id  UUID NOT NULL REFERENCES drop_points(id),
  dest_drop_point_id    UUID NOT NULL REFERENCES drop_points(id),
  priority              INT NOT NULL DEFAULT 1,
  estimated_days        INT NOT NULL DEFAULT 3,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (origin_zone, destination_zone, priority)
);

-- ============================================================
-- SHIPMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS shipments (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tracking_number             TEXT NOT NULL UNIQUE,
  customer_id                 UUID NOT NULL REFERENCES users(id),

  -- Addresses
  origin_address              TEXT NOT NULL,
  origin_city                 TEXT NOT NULL,
  origin_province             TEXT NOT NULL,
  origin_zone                 TEXT NOT NULL,
  destination_address         TEXT NOT NULL,
  destination_city            TEXT NOT NULL,
  destination_province        TEXT NOT NULL,
  destination_zone            TEXT NOT NULL,

  -- Package details
  package_description         TEXT,
  weight_kg                   NUMERIC(8,2) NOT NULL DEFAULT 1.0,
  package_count               INT NOT NULL DEFAULT 1,

  -- Status
  status                      TEXT NOT NULL DEFAULT 'pending',
  eta                         TIMESTAMPTZ,

  -- Assignments (populated by Assignment Engine)
  pickup_dispatcher_id        UUID REFERENCES dispatchers(id),
  pickup_driver_id            UUID REFERENCES drivers(id),
  origin_drop_point_id        UUID REFERENCES drop_points(id),
  origin_hub_id               UUID REFERENCES hubs(id),
  storekeeper_id              UUID REFERENCES storekeepers(id),
  sorting_hub_id              UUID REFERENCES hubs(id),
  destination_hub_id          UUID REFERENCES hubs(id),
  destination_drop_point_id   UUID REFERENCES drop_points(id),
  delivery_dispatcher_id      UUID REFERENCES dispatchers(id),
  delivery_driver_id          UUID REFERENCES drivers(id),

  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SHIPMENT HISTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS shipment_history (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id     UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  status          TEXT NOT NULL,
  description     TEXT NOT NULL,
  location        TEXT,
  performed_by    UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shipment_id     UUID REFERENCES shipments(id) ON DELETE SET NULL,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  type            TEXT NOT NULL DEFAULT 'task',
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_shipments_customer    ON shipments(customer_id);
CREATE INDEX IF NOT EXISTS idx_shipments_status      ON shipments(status);
CREATE INDEX IF NOT EXISTS idx_shipments_tracking    ON shipments(tracking_number);
CREATE INDEX IF NOT EXISTS idx_shipment_history_ship ON shipment_history(shipment_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user    ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_drivers_zone          ON drivers(zone, is_available);
CREATE INDEX IF NOT EXISTS idx_routing_rules_zones   ON routing_rules(origin_zone, destination_zone);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (enable in Phase 2 with auth policies)
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE shipments;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE shipment_history;

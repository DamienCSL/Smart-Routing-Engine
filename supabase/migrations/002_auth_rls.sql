-- IPOSB Phase 2: Auth trigger + RLS policies
-- Run AFTER 001_initial_schema.sql

-- ============================================================
-- AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_name TEXT;
  role_uuid UUID;
BEGIN
  role_name := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  SELECT id INTO role_uuid FROM roles WHERE name = role_name;

  IF role_uuid IS NULL THEN
    SELECT id INTO role_uuid FROM roles WHERE name = 'customer';
  END IF;

  INSERT INTO public.users (id, email, full_name, phone, role_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'phone',
    role_uuid
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- HELPER: current user role name
-- ============================================================
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.name
  FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE u.id = auth.uid();
$$;

-- ============================================================
-- RLS: users
-- ============================================================
DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY users_select_own ON users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS users_update_own ON users;
CREATE POLICY users_update_own ON users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS users_insert_own ON users;
CREATE POLICY users_insert_own ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================================
-- RLS: roles (read-only for authenticated users)
-- ============================================================
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS roles_select_all ON roles;
CREATE POLICY roles_select_all ON roles
  FOR SELECT TO authenticated USING (true);

-- ============================================================
-- RLS: notifications
-- ============================================================
DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own ON notifications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- RLS: shipments (basic — expanded in later phases)
-- ============================================================
DROP POLICY IF EXISTS shipments_select_customer ON shipments;
CREATE POLICY shipments_select_customer ON shipments
  FOR SELECT USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS shipments_insert_customer ON shipments;
CREATE POLICY shipments_insert_customer ON shipments
  FOR INSERT WITH CHECK (
    auth.uid() = customer_id
    AND public.current_user_role() = 'customer'
  );

-- ============================================================
-- RLS: shipment_history
-- ============================================================
DROP POLICY IF EXISTS shipment_history_select ON shipment_history;
CREATE POLICY shipment_history_select ON shipment_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.id = shipment_history.shipment_id
        AND s.customer_id = auth.uid()
    )
  );

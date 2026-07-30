-- IPOSB: Demo hub workers (merged driver + dispatcher)
-- Run AFTER demo_data.sql hubs/drop points AND 011_hub_workers.sql
-- Password for all demo accounts: Demo123456!

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public._iposb_ensure_demo_user(
  p_email TEXT,
  p_full_name TEXT,
  p_role TEXT,
  p_phone TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_id UUID;
  v_role_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NOT NULL THEN
    -- Keep role in sync for re-seeds (e.g. driver → hub_worker)
    SELECT id INTO v_role_id FROM roles WHERE name = p_role;
    IF v_role_id IS NOT NULL THEN
      UPDATE public.users
      SET role_id = v_role_id,
          full_name = COALESCE(p_full_name, full_name)
      WHERE id = v_user_id;
      UPDATE auth.users
      SET raw_user_meta_data =
            COALESCE(raw_user_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', p_role, 'full_name', p_full_name)
      WHERE id = v_user_id;
    END IF;
    RETURN v_user_id;
  END IF;

  v_user_id := gen_random_uuid();

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    p_email,
    extensions.crypt('Demo123456!', extensions.gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'full_name', p_full_name,
      'role', p_role,
      'phone', p_phone
    ),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  );

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', p_email),
    'email',
    v_user_id::text,
    NOW(),
    NOW(),
    NOW()
  );

  SELECT id INTO v_role_id FROM roles WHERE name = p_role;
  IF v_role_id IS NULL THEN
    SELECT id INTO v_role_id FROM roles WHERE name = 'customer';
  END IF;

  INSERT INTO public.users (id, email, full_name, phone, role_id)
  VALUES (v_user_id, p_email, p_full_name, p_phone, v_role_id)
  ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role_id = EXCLUDED.role_id;

  RETURN v_user_id;
END;
$$;

DO $$
DECLARE
  uid_kk_worker UUID;
  uid_sk_worker UUID;
  uid_storekeeper UUID;
  hub_origin UUID;
  hub_dest UUID;
BEGIN
  SELECT id INTO hub_origin FROM hubs WHERE code = 'HUB-ON-01';
  SELECT id INTO hub_dest FROM hubs WHERE code = 'HUB-DH-01';

  IF hub_origin IS NULL OR hub_dest IS NULL THEN
    RAISE EXCEPTION 'Run demo_data.sql hubs first (HUB-ON-01 / HUB-DH-01 missing)';
  END IF;

  -- Primary hub workers (use these for the mobile demo)
  uid_kk_worker := public._iposb_ensure_demo_user(
    'hub.kk@iposb.demo', 'KK Hub Worker', 'hub_worker', '60121110001'
  );
  uid_sk_worker := public._iposb_ensure_demo_user(
    'hub.sandakan@iposb.demo', 'Sandakan Hub Worker', 'hub_worker', '60121110002'
  );
  uid_storekeeper := public._iposb_ensure_demo_user(
    'storekeeper.origin@iposb.demo', 'Sam Storekeeper', 'storekeeper', '60121110005'
  );

  -- Also remap old demo emails → hub_worker so existing bookmarks still work
  PERFORM public._iposb_ensure_demo_user(
    'dispatcher.kk@iposb.demo', 'Nina Dispatcher', 'hub_worker', '60121110001'
  );
  PERFORM public._iposb_ensure_demo_user(
    'driver.pickup@iposb.demo', 'Alex Pickup', 'hub_worker', '60121110003'
  );
  PERFORM public._iposb_ensure_demo_user(
    'dispatcher.sandakan@iposb.demo', 'Vic Dispatcher', 'hub_worker', '60121110002'
  );
  PERFORM public._iposb_ensure_demo_user(
    'driver.delivery@iposb.demo', 'Dana Delivery', 'hub_worker', '60121110004'
  );

  INSERT INTO hub_workers (
    user_id, hub_id, preferred_zones, license_number,
    vehicle_type, vehicle_plate, is_available, shift
  ) VALUES (
    uid_kk_worker,
    hub_origin,
    ARRAY['KK-METRO', 'WEST-COAST']::TEXT[],
    'LIC-KK-001',
    'van',
    'SAB 1001',
    TRUE,
    'day'
  )
  ON CONFLICT (user_id) DO UPDATE SET
    hub_id = EXCLUDED.hub_id,
    preferred_zones = EXCLUDED.preferred_zones,
    vehicle_plate = EXCLUDED.vehicle_plate,
    is_available = TRUE;

  INSERT INTO hub_workers (
    user_id, hub_id, preferred_zones, license_number,
    vehicle_type, vehicle_plate, is_available, shift
  ) VALUES (
    uid_sk_worker,
    hub_dest,
    ARRAY['SANDAKAN', 'TAWAU']::TEXT[],
    'LIC-SK-001',
    'motorcycle',
    'SAB 2002',
    TRUE,
    'day'
  )
  ON CONFLICT (user_id) DO UPDATE SET
    hub_id = EXCLUDED.hub_id,
    preferred_zones = EXCLUDED.preferred_zones,
    vehicle_plate = EXCLUDED.vehicle_plate,
    is_available = TRUE;

  -- Ensure remapped legacy accounts also have hub_worker rows
  INSERT INTO hub_workers (
    user_id, hub_id, preferred_zones, license_number,
    vehicle_type, vehicle_plate, is_available, shift
  )
  SELECT u.id, hub_origin, ARRAY['KK-METRO', 'WEST-COAST']::TEXT[],
         'LIC-KK-LEG', 'van', 'SAB 1001', TRUE, 'day'
  FROM auth.users u
  WHERE u.email IN ('dispatcher.kk@iposb.demo', 'driver.pickup@iposb.demo')
  ON CONFLICT (user_id) DO UPDATE SET
    hub_id = EXCLUDED.hub_id,
    preferred_zones = EXCLUDED.preferred_zones,
    is_available = TRUE;

  INSERT INTO hub_workers (
    user_id, hub_id, preferred_zones, license_number,
    vehicle_type, vehicle_plate, is_available, shift
  )
  SELECT u.id, hub_dest, ARRAY['SANDAKAN', 'TAWAU']::TEXT[],
         'LIC-SK-LEG', 'motorcycle', 'SAB 2002', TRUE, 'day'
  FROM auth.users u
  WHERE u.email IN ('dispatcher.sandakan@iposb.demo', 'driver.delivery@iposb.demo')
  ON CONFLICT (user_id) DO UPDATE SET
    hub_id = EXCLUDED.hub_id,
    preferred_zones = EXCLUDED.preferred_zones,
    is_available = TRUE;

  INSERT INTO storekeepers (user_id, hub_id, shift, is_active)
  VALUES (uid_storekeeper, hub_origin, 'day', TRUE)
  ON CONFLICT (user_id) DO UPDATE
    SET hub_id = EXCLUDED.hub_id, is_active = TRUE;
END $$;

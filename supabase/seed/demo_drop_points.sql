-- IPOSB Phase 7: Drop Point operator seed
-- Run AFTER demo_staff.sql (needs _iposb_ensure_demo_user + hubs/drop points)
-- Password for all demo accounts: Demo123456!

DO $$
DECLARE
  uid_origin_dp UUID;
  uid_dest_dp UUID;
  dp_origin UUID;
  dp_dest UUID;
BEGIN
  SELECT id INTO dp_origin FROM drop_points WHERE code = 'DP-ON-01';
  SELECT id INTO dp_dest FROM drop_points WHERE code = 'DP-DH-01';

  IF dp_origin IS NULL OR dp_dest IS NULL THEN
    RAISE EXCEPTION 'Run demo_data.sql first (DP-ON-01 / DP-DH-01 missing)';
  END IF;

  uid_origin_dp := public._iposb_ensure_demo_user(
    'droppoint.origin@iposb.demo', 'Omar DropPoint', 'drop_point', '60121110006'
  );
  uid_dest_dp := public._iposb_ensure_demo_user(
    'droppoint.dest@iposb.demo', 'Dina DropPoint', 'drop_point', '60121110007'
  );

  UPDATE drop_points
  SET operator_id = uid_origin_dp
  WHERE code = 'DP-ON-01';

  UPDATE drop_points
  SET operator_id = uid_dest_dp
  WHERE code = 'DP-DH-01';
END $$;

-- 016 — FMS role-based access (Super Admin / Admin / Hub Manager / Droppoint Manager)
-- Apply on IPOSB ops master (bbbexpress).
-- Canonical copy: D:\iposb source code\deploy\sql\016_fms_app_roles.sql
--
-- Plain ALTER for phpMyAdmin / Railway — ignore "Duplicate column name" on re-run.

ALTER TABLE t_user
  ADD COLUMN app_role VARCHAR(40) NULL
  COMMENT 'FMS role: Super Admin, Admin, Hub Manager, Droppoint Manager, Operation, Agent, Invoice, CSL, Customer';

UPDATE t_user
SET app_role = CASE default_header
    WHEN 'admin_main_header.php' THEN 'Admin'
    WHEN 'ops_kul_header.php' THEN 'Operation'
    WHEN 'ops_agent_header.php' THEN 'Agent'
    WHEN 'bld_admin_header.php' THEN 'Invoice'
    WHEN 'csl_header.php' THEN 'CSL'
    WHEN 'cust_main_header.php' THEN 'Customer'
    WHEN 'cust_track_header.php' THEN 'Customer'
    WHEN 'super_admin_header.php' THEN 'Super Admin'
    WHEN 'hub_mgr_header.php' THEN 'Hub Manager'
    WHEN 'dp_mgr_header.php' THEN 'Droppoint Manager'
    ELSE COALESCE(NULLIF(app_role, ''), 'Others')
END
WHERE app_role IS NULL OR app_role = '';

UPDATE t_user
SET app_role = 'Super Admin',
    default_header = 'super_admin_header.php',
    user_type = 'admin'
WHERE username = 'admin';

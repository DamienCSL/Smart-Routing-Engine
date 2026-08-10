-- 015 — Staff verification for mobile driver / dispatcher
-- Apply on IPOSB ops master (bbbexpress).
-- Canonical copy: D:\iposb source code\deploy\sql\015_staff_verification.sql
--
-- Plain ALTER for phpMyAdmin / Railway — ignore "Duplicate column name" on re-run.

ALTER TABLE t_mobile_user
  ADD COLUMN verification_status VARCHAR(20) NOT NULL DEFAULT 'approved'
  COMMENT 'pending | approved | rejected';

ALTER TABLE t_mobile_user
  ADD COLUMN verified_at DATETIME NULL
  COMMENT 'When staff account was approved or rejected';

ALTER TABLE t_mobile_user
  ADD COLUMN verified_by VARCHAR(80) NULL
  COMMENT 'FMS admin who verified the staff account';

ALTER TABLE t_mobile_user
  ADD COLUMN verification_note VARCHAR(255) NULL
  COMMENT 'Optional reject reason shown on app login';

-- Existing active accounts (including demo seeds) remain approved.
UPDATE t_mobile_user
SET verification_status = 'approved',
    verified_at = COALESCE(verified_at, created_at, NOW())
WHERE is_active = 1
  AND (verification_status IS NULL OR verification_status = '' OR verification_status = 'approved');

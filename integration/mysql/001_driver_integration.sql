-- IPOSB Driver integration for MySQL 5.x / MariaDB (bbbexpress)
-- Apply on the ops master DB. Re-run safe: skips existing objects.

CREATE TABLE IF NOT EXISTS t_driver (
  driver_id       INT AUTO_INCREMENT PRIMARY KEY,
  user_id         VARCHAR(20) NULL,
  firebase_uid    VARCHAR(128) NOT NULL,
  full_name       VARCHAR(120) NOT NULL,
  phone           VARCHAR(32) NULL,
  loc_id          CHAR(3) NOT NULL,
  route_cd        VARCHAR(20) NULL,
  is_available    TINYINT(1) NOT NULL DEFAULT 1,
  created_at      DATETIME NOT NULL,
  updated_at      DATETIME NOT NULL,
  UNIQUE KEY uq_driver_firebase (firebase_uid)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS t_driver_device (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  driver_id       INT NOT NULL,
  fcm_token       VARCHAR(512) NOT NULL,
  platform        VARCHAR(20) NULL,
  updated_at      DATETIME NOT NULL,
  UNIQUE KEY uq_driver_token (driver_id, fcm_token(191)),
  KEY idx_device_driver (driver_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Additive columns on t_consignment (run each once; ignore "Duplicate column" errors)
ALTER TABLE t_consignment ADD COLUMN assigned_driver_id INT NULL;
ALTER TABLE t_consignment ADD COLUMN job_type VARCHAR(16) NULL;
ALTER TABLE t_consignment ADD COLUMN pu_lat DOUBLE NULL;
ALTER TABLE t_consignment ADD COLUMN pu_lng DOUBLE NULL;
ALTER TABLE t_consignment ADD COLUMN dl_lat DOUBLE NULL;
ALTER TABLE t_consignment ADD COLUMN dl_lng DOUBLE NULL;
ALTER TABLE t_consignment ADD COLUMN pod_photo_url VARCHAR(512) NULL;

ALTER TABLE t_consignment ADD INDEX idx_cn_assigned_driver (assigned_driver_id);

INSERT INTO t_driver (firebase_uid, full_name, phone, loc_id, route_cd, is_available, created_at, updated_at)
SELECT 'demo-driver-kk', 'KK Demo Driver', '60121110001', 'BKI', 'BKI001', 1, NOW(), NOW()
 
WHERE NOT EXISTS (SELECT 1 FROM t_driver WHERE firebase_uid = 'demo-driver-kk');

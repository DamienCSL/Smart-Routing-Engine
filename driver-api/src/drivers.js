const { query, withTransaction } = require('./db');
const {
  TO_CN_STATUS,
  isAllowedTransition,
  STATUS,
  TRACK_STATUS_LIST,
  customerLabelOf,
  detailLabelOf,
  nextAllowedScans,
  isTerminalDelivered,
} = require('./statusMap');
const { sendFcm } = require('./firebase');

const TRACK_IN = TRACK_STATUS_LIST.map((s) => `'${s}'`).join(',');

async function getDriverByFirebaseUid(uid) {
  const rows = await query(
    'SELECT * FROM t_driver WHERE firebase_uid = ? LIMIT 1',
    [uid],
  );
  return rows[0] || null;
}

async function ensureDemoDriver(uid, defaults = {}) {
  let driver = await getDriverByFirebaseUid(uid);
  if (driver) return driver;
  await query(
    `INSERT INTO t_driver
      (firebase_uid, full_name, phone, loc_id, route_cd, is_available, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, NOW(), NOW())`,
    [
      uid,
      defaults.fullName || 'Demo Driver',
      defaults.phone || null,
      defaults.locId || 'BKI',
      defaults.routeCd || 'BKI001',
    ],
  );
  return getDriverByFirebaseUid(uid);
}

function mapJob(row) {
  const isPickup = row.job_type === 'pickup';
  const lastMobile = row.last_mobile_status || null;
  return {
    cnNo: String(row.cn_no).trim(),
    jobType: row.job_type || 'pipeline',
    status: row.cn_status,
    lastMobileStatus: lastMobile,
    nextScans: nextAllowedScans(lastMobile || row.cn_status),
    customerLabel: customerLabelOf(lastMobile || row.cn_status),
    recipientName: row.recp_name || '',
    address: row.remarks || row.recp_name || '',
    city: '',
    originLoc: row.cn_origin || '',
    destLoc: row.cn_dstn || '',
    locId: isPickup ? row.cn_origin : row.cn_dstn,
    lat: isPickup ? row.pu_lat : row.dl_lat,
    lng: isPickup ? row.pu_lng : row.dl_lng,
    weight: row.cn_wt != null ? Number(row.cn_wt) : null,
    pieces: row.cn_pcs != null ? Number(row.cn_pcs) : null,
    routeCd: row.route_cd || null,
    assignedDriverId: row.assigned_driver_id,
    podPhotoUrl: row.pod_photo_url || null,
    pickupDate: row.pu_dt || null,
  };
}

const JOB_SELECT = `
  SELECT
    c.cn_no,
    c.cn_status,
    c.assigned_driver_id,
    c.job_type,
    c.pu_lat,
    c.pu_lng,
    c.dl_lat,
    c.dl_lng,
    c.pod_photo_url,
    c.route_cd,
    c.cn_wt,
    c.cn_pcs,
    c.cn_origin,
    c.cn_dstn,
    c.recp_name,
    c.remarks,
    c.pu_dt,
    (
      SELECT t.cn_status FROM t_cn_track t
      WHERE t.cn_no = c.cn_no
        AND t.cn_status IN (${TRACK_IN})
      ORDER BY t.upd_dt_tm DESC
      LIMIT 1
    ) AS last_mobile_status
  FROM t_consignment c
`;

async function listJobs(driver, type) {
  const jobType = type === 'pickup' ? 'pickup' : 'delivery';
  const rows = await query(
    `${JOB_SELECT}
     WHERE c.assigned_driver_id = ?
       AND (c.job_type = ? OR c.job_type = 'pipeline' OR (c.job_type IS NULL AND ? = 'delivery'))
       AND IFNULL(c.cn_status,'') NOT IN ('POD','PCC','PFP','PCB')
     ORDER BY c.cn_no DESC
     LIMIT 100`,
    [driver.driver_id, jobType, jobType],
  );
  return rows.map(mapJob);
}

async function getJob(driver, cnNo) {
  const rows = await query(
    `${JOB_SELECT} WHERE c.cn_no = ? AND c.assigned_driver_id = ? LIMIT 1`,
    [cnNo, driver.driver_id],
  );
  if (!rows[0]) return null;
  return mapJob(rows[0]);
}

async function getJobByCn(cnNo) {
  const rows = await query(`${JOB_SELECT} WHERE c.cn_no = ? LIMIT 1`, [cnNo]);
  if (!rows[0]) return null;
  return mapJob(rows[0]);
}

async function insertTrack(conn, { cnNo, status, driver, remarks }) {
  const updId = String(
    (driver && (driver.firebase_uid || driver.upd_id)) || 'MOBILE',
  ).slice(0, 15);
  const locId = (driver && driver.loc_id) || 'BKI';
  await conn.execute(
    `INSERT INTO t_cn_track
      (cn_no, cn_status, mnf_no, lnhaul_cd, upd_id, upd_dt_tm, loc_id, ref_no, drs_no, remarks, attempt_dt)
     VALUES (?, ?, '', '', ?, NOW(), ?, '', '', ?, CURDATE())`,
    [cnNo, status, updId, locId, String(remarks || '').slice(0, 150)],
  );
}

async function acceptJob(driver, cnNo) {
  return updateStatus(driver, cnNo, {
    status: STATUS.ACC,
    note: 'Accepted by driver',
  });
}

async function updateStatus(driver, cnNo, body) {
  return applyScan({
    cnNo,
    toStatus: body.status,
    note: body.note || null,
    failureCd: body.failureCd || null,
    lat: body.lat != null ? Number(body.lat) : null,
    lng: body.lng != null ? Number(body.lng) : null,
    photoUrl: body.photoUrl || null,
    actor: driver,
    requireAssigned: true,
    locId: body.locId || body.loc_id || null,
  });
}

/**
 * Ops or driver scan — shared write path for Sprint 1 pipeline.
 */
async function applyScan({
  cnNo,
  toStatus,
  note,
  failureCd,
  lat,
  lng,
  photoUrl,
  actor,
  requireAssigned,
  locId: locOverride,
}) {
  if (!cnNo || !toStatus) {
    const err = new Error('cnNo and status required');
    err.status = 400;
    throw err;
  }

  return withTransaction(async (conn) => {
    const [rows] = await conn.execute(
      `SELECT cn_no, cn_status, assigned_driver_id, job_type, cn_origin, cn_dstn
       FROM t_consignment WHERE cn_no = ? LIMIT 1 FOR UPDATE`,
      [cnNo],
    );
    const cn = rows[0];
    if (!cn) {
      const err = new Error('Consignment not found');
      err.status = 404;
      throw err;
    }
    if (
      requireAssigned &&
      actor &&
      actor.driver_id != null &&
      Number(cn.assigned_driver_id) !== Number(actor.driver_id)
    ) {
      const err = new Error('Job not assigned to this driver');
      err.status = 403;
      throw err;
    }

    const jobType = cn.job_type || 'pipeline';
    const [lastRows] = await conn.execute(
      `SELECT cn_status FROM t_cn_track
       WHERE cn_no = ? AND cn_status IN (${TRACK_IN})
       ORDER BY upd_dt_tm DESC LIMIT 1`,
      [cnNo],
    );
    const lastMobile = lastRows[0]?.cn_status || cn.cn_status || null;

    if (!isAllowedTransition(jobType, lastMobile, toStatus)) {
      const err = new Error(
        `Invalid transition for ${jobType}: ${lastMobile || '-'} → ${toStatus}`,
      );
      err.status = 400;
      throw err;
    }

    const trackStatus =
      failureCd && toStatus === STATUS.UND
        ? String(failureCd).slice(0, 3)
        : toStatus;
    const resolvedLoc = resolveScanLoc(toStatus, locOverride, actor, cn);
    const remarks = [
      note,
      failureCd ? `failure=${failureCd}` : null,
      lat != null ? `geo=${lat},${lng}` : null,
    ]
      .filter(Boolean)
      .join(' | ');

    await insertTrack(conn, {
      cnNo,
      status: trackStatus,
      driver: { ...(actor || { firebase_uid: 'OPS' }), loc_id: resolvedLoc },
      remarks,
    });

    const cnStatus = TO_CN_STATUS[toStatus];
    const sets = [];
    const params = [];
    if (cnStatus) {
      sets.push('cn_status = ?');
      params.push(cnStatus);
    }
    if (toStatus === STATUS.POD) {
      sets.push('pod_dt = CURDATE()', 'pod_tm = CURTIME()');
      sets.push("pod_batch = IF(IFNULL(pod_batch,'')='', ?, pod_batch)");
      params.push(`MOB${new Date().toISOString().slice(0, 10).replace(/-/g, '')}`);
    }
    if (toStatus === STATUS.PKU) {
      sets.push('pu_dt = CURDATE()');
    }
    if (photoUrl) {
      sets.push('pod_photo_url = ?');
      params.push(String(photoUrl).slice(0, 512));
    }
    if (lat != null && lng != null) {
      if (toStatus === STATUS.PKU) {
        sets.push('pu_lat = COALESCE(pu_lat, ?)', 'pu_lng = COALESCE(pu_lng, ?)');
        params.push(lat, lng);
      } else if (toStatus === STATUS.OFD || toStatus === STATUS.POD) {
        sets.push('dl_lat = COALESCE(dl_lat, ?)', 'dl_lng = COALESCE(dl_lng, ?)');
        params.push(lat, lng);
      }
    }
    if (actor && actor.route_cd) {
      sets.push("route_cd = IF(IFNULL(route_cd,'')='', ?, route_cd)");
      params.push(String(actor.route_cd).slice(0, 6));
    }
    if (sets.length) {
      params.push(cnNo);
      await conn.execute(
        `UPDATE t_consignment SET ${sets.join(', ')} WHERE cn_no = ?`,
        params,
      );
    }

    return {
      ok: true,
      cnNo,
      from: lastMobile,
      to: toStatus,
      cnStatus: cnStatus || cn.cn_status,
      customerLabel: detailLabelOf(toStatus, resolvedLoc, note),
      shortLabel: customerLabelOf(toStatus),
      location: resolvedLoc,
      nextScans: nextAllowedScans(toStatus),
    };
  });
}

function resolveScanLoc(toStatus, locOverride, actor, cn) {
  const override = String(locOverride || '')
    .trim()
    .toUpperCase();
  if (override) return override;
  const key = String(toStatus || '')
    .trim()
    .toUpperCase();
  const origin = String(cn?.cn_origin || 'BKI')
    .trim()
    .toUpperCase();
  const dest = String(cn?.cn_dstn || origin)
    .trim()
    .toUpperCase();
  if (['ARR', 'SHB', 'HUB', 'SCF'].includes(key)) return 'SBH325';
  if (['SRT', 'MNF'].includes(key)) return '805';
  if (['PKU', 'ACC', 'BDE', 'GWD'].includes(key)) return origin || 'BKI';
  if (['OFD', 'DRS', 'POD', 'UND', 'OVN'].includes(key)) {
    const actorLoc = String(actor?.loc_id || '')
      .trim()
      .toUpperCase();
    return actorLoc || dest || 'BKI';
  }
  return dest || 'BKI';
}

async function opsScan({
  cnNo,
  status,
  note,
  failureCd,
  lat,
  lng,
  photoUrl,
  apiKey,
  actorName,
  locId,
}) {
  if (apiKey !== process.env.DISPATCH_API_KEY) {
    const err = new Error('Invalid dispatch API key');
    err.status = 401;
    throw err;
  }
  return applyScan({
    cnNo,
    toStatus: status,
    note: note || `Ops scan by ${actorName || 'web'}`,
    failureCd,
    lat,
    lng,
    photoUrl,
    actor: { firebase_uid: 'OPS', loc_id: locId || 'BKI', upd_id: 'OPS' },
    requireAssigned: false,
    locId,
  });
}

async function registerFcmToken(driver, token, platform) {
  await query(
    `INSERT INTO t_driver_device (driver_id, fcm_token, platform, updated_at)
     VALUES (?, ?, ?, NOW())
     ON DUPLICATE KEY UPDATE platform = VALUES(platform), updated_at = NOW()`,
    [driver.driver_id, token, platform || null],
  );
  return { ok: true };
}

async function assignJob({ cnNo, firebaseUid, jobType, apiKey }) {
  if (apiKey !== process.env.DISPATCH_API_KEY) {
    const err = new Error('Invalid dispatch API key');
    err.status = 401;
    throw err;
  }
  if (!cnNo || !firebaseUid) {
    const err = new Error('cnNo and firebaseUid required');
    err.status = 400;
    throw err;
  }
  const driver = await getDriverByFirebaseUid(firebaseUid);
  if (!driver) {
    const err = new Error('Driver not found for firebase_uid');
    err.status = 404;
    throw err;
  }

  const type =
    jobType === 'pickup' ? 'pickup' : jobType === 'pipeline' ? 'pipeline' : 'delivery';
  return withTransaction(async (conn) => {
    const [result] = await conn.execute(
      `UPDATE t_consignment
       SET assigned_driver_id = ?,
           job_type = ?,
           route_cd = IF(IFNULL(route_cd,'')='', ?, route_cd)
       WHERE cn_no = ?`,
      [driver.driver_id, type, String(driver.route_cd || '').slice(0, 6), cnNo],
    );
    if (result.affectedRows === 0) {
      const err = new Error('Consignment not found');
      err.status = 404;
      throw err;
    }

    await insertTrack(conn, {
      cnNo,
      status: STATUS.ACC,
      driver: { ...driver, firebase_uid: 'WEB' },
      remarks: `Assigned to ${driver.full_name} (${type})`,
    });

    const [devices] = await conn.execute(
      'SELECT fcm_token FROM t_driver_device WHERE driver_id = ?',
      [driver.driver_id],
    );
    const tokens = devices.map((d) => d.fcm_token).filter(Boolean);
    const fcm = await sendFcm(
      tokens,
      {
        title: 'New job assigned',
        body: `CN ${cnNo} assigned to you`,
      },
      { cn_no: cnNo, job_type: type },
    );

    return {
      ok: true,
      cnNo,
      driverId: driver.driver_id,
      jobType: type,
      fcm,
      customerLabel: customerLabelOf(STATUS.ACC),
    };
  });
}

async function getTracking(cnNo) {
  const rows = await query(
    `SELECT cn_no, cn_status, recp_name, cn_origin, cn_dstn, remarks, pod_dt, pod_tm
     FROM t_consignment WHERE cn_no = ? LIMIT 1`,
    [cnNo],
  );
  if (!rows[0]) {
    const err = new Error('Consignment not found');
    err.status = 404;
    throw err;
  }
  const cn = rows[0];
  const track = await query(
    `SELECT cn_status, upd_dt_tm, loc_id, remarks, upd_id
     FROM t_cn_track WHERE cn_no = ?
     ORDER BY upd_dt_tm ASC, attempt_dt ASC`,
    [cnNo],
  );
  const last =
    [...track].reverse().find((t) => TRACK_STATUS_LIST.includes(t.cn_status)) ||
    null;
  const currentCode = last?.cn_status || cn.cn_status;
  const currentLoc =
    last?.loc_id || cn.cn_dstn || cn.cn_origin || '';
  return {
    cnNo: String(cn.cn_no).trim(),
    statusCode: currentCode,
    customerLabel: detailLabelOf(currentCode, currentLoc),
    shortLabel: customerLabelOf(currentCode),
    recipientName: cn.recp_name || '',
    origin: cn.cn_origin || '',
    destination: cn.cn_dstn || '',
    location: currentLoc,
    delivered: isTerminalDelivered(cn.cn_status),
    podDate: cn.pod_dt || null,
    podTime: cn.pod_tm || null,
    timeline: track.map((t) => ({
      statusCode: t.cn_status,
      customerLabel: detailLabelOf(t.cn_status, t.loc_id, t.remarks),
      shortLabel: customerLabelOf(t.cn_status),
      at: t.upd_dt_tm,
      location: t.loc_id,
      note: t.remarks || '',
      by: t.upd_id || '',
    })),
    nextScans: nextAllowedScans(currentCode),
  };
}

/**
 * Create a demo CN for Sprint 1 local testing when FMS create is unavailable.
 * Uses a random 7–8 digit cn_no compatible with legacy CHAR length.
 */
async function createDemoOrder({ recipientName, address, origin, dest, weight }) {
  // Legacy cn_no is char(8)
  const cnNo = String(20000000 + Math.floor(Math.random() * 7999999)).slice(0, 8);
  const name = (recipientName || 'Demo Buyer').slice(0, 40);
  const remarks = (address || 'Demo address, Kota Kinabalu').slice(0, 100);
  const from = (origin || 'BKI').slice(0, 3);
  const to = (dest || 'BKI').slice(0, 3);
  const wt = weight != null ? Number(weight) : 1;
  const yrMonth = new Date().toISOString().slice(0, 7);

  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO t_consignment
        (cn_no, cust_ac_no, recp_name, pkg_typ, cn_origin, cn_dstn, cn_pcs, cn_wt,
         cn_inv_flg, cn_status, mth_end_flg, yr_month, tot_cn_amt, cn_tax_amt, cn_dt_tm,
         cn_oda, upd_id, tax_exempt, fuel_surchrge, cn_waive, spec_handle, surcharge,
         rev_chrge, srv_typ, ftz, remarks, lnhaul_charge_flg, oda_cd, job_type)
       VALUES
        (?, '00000000', ?, 'P', ?, ?, 1, ?,
         'B', 'BDE', 'N', ?, 0, 0, NOW(),
         'N', 'DEMO', 'N', 'Y', 'N', 'N', 'N',
         'N', 'COU', 'N', ?, 'N', '', 'pipeline')`,
      [cnNo, name, from, to, wt, yrMonth, remarks],
    );
    await insertTrack(conn, {
      cnNo,
      status: 'BDE',
      driver: { firebase_uid: 'DEMO', loc_id: from },
      remarks: 'Demo order created',
    });
  });

  return {
    ok: true,
    cnNo,
    customerLabel: customerLabelOf('BDE'),
    qrPayload: cnNo,
  };
}

function navigateUrl(job) {
  if (job.lat != null && job.lng != null) {
    return `https://www.google.com/maps/dir/?api=1&destination=${job.lat},${job.lng}&travelmode=driving`;
  }
  const q = encodeURIComponent(
    [job.address, job.recipientName, job.destLoc || job.originLoc]
      .filter(Boolean)
      .join(', '),
  );
  return `https://www.google.com/maps/dir/?api=1&destination=${q}&travelmode=driving`;
}

module.exports = {
  getDriverByFirebaseUid,
  ensureDemoDriver,
  listJobs,
  getJob,
  getJobByCn,
  acceptJob,
  updateStatus,
  applyScan,
  opsScan,
  registerFcmToken,
  assignJob,
  getTracking,
  createDemoOrder,
  navigateUrl,
};

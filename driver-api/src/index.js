require('dotenv').config();
const express = require('express');
const cors = require('cors');
const QRCode = require('qrcode');
const { verifyIdToken } = require('./firebase');
const drivers = require('./drivers');
const { ping, mysqlConfig } = require('./db');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

async function requireDriver(req, res, next) {
  try {
    const decoded = await verifyIdToken(req.headers.authorization || '');
    let driver = await drivers.getDriverByFirebaseUid(decoded.uid);
    if (!driver && decoded.demo) {
      driver = await drivers.ensureDemoDriver(decoded.uid);
    }
    if (!driver) {
      return res.status(403).json({
        error:
          'No t_driver row for this Firebase user. Seed integration/mysql/001_driver_integration.sql',
      });
    }
    req.driver = driver;
    req.auth = decoded;
    return next();
  } catch (e) {
    return res.status(e.status || 401).json({ error: e.message });
  }
}

app.get('/health', async (_req, res) => {
  try {
    await ping();
    const cfg = mysqlConfig();
    res.json({
      ok: true,
      service: 'iposb-driver-api',
      sprint: 1,
      database: cfg.database,
      host: cfg.host,
    });
  } catch (e) {
    res.status(503).json({
      ok: false,
      service: 'iposb-driver-api',
      error: e.message,
    });
  }
});

/** Public customer tracking — no auth. */
app.get('/tracking/:cnNo', async (req, res) => {
  try {
    const data = await drivers.getTracking(req.params.cnNo);
    res.json(data);
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

/** QR label for CN (SVG). Public for demo printing/display. */
app.get('/labels/:cnNo', async (req, res) => {
  try {
    const cnNo = String(req.params.cnNo || '').trim();
    if (!cnNo) return res.status(400).json({ error: 'cnNo required' });
    const format = (req.query.format || 'json').toLowerCase();
    const svg = await QRCode.toString(cnNo, {
      type: 'svg',
      margin: 1,
      width: 256,
      errorCorrectionLevel: 'M',
    });
    if (format === 'svg') {
      res.type('image/svg+xml').send(svg);
      return;
    }
    const dataUrl = await QRCode.toDataURL(cnNo, {
      margin: 1,
      width: 256,
      errorCorrectionLevel: 'M',
    });
    res.json({
      cnNo,
      qrPayload: cnNo,
      svg,
      dataUrl,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/** Demo order create for local E2E (no FMS). */
app.post('/demo/orders', async (req, res) => {
  try {
    const key = req.headers['x-dispatch-key'] || req.body?.apiKey;
    if (key !== process.env.DISPATCH_API_KEY) {
      return res.status(401).json({ error: 'Invalid dispatch API key' });
    }
    const result = await drivers.createDemoOrder(req.body || {});
    res.json(result);
  } catch (e) {
    console.error(e);
    res.status(e.status || 500).json({ error: e.message });
  }
});

/** Ops scan (hub / sort / storekeeper / any pipeline step) via dispatch key. */
app.post('/ops/scan', async (req, res) => {
  try {
    const result = await drivers.opsScan({
      cnNo: req.body?.cnNo,
      status: req.body?.status || req.body?.scanType,
      note: req.body?.note,
      failureCd: req.body?.failureCd,
      lat: req.body?.lat,
      lng: req.body?.lng,
      photoUrl: req.body?.photoUrl,
      apiKey: req.headers['x-dispatch-key'] || req.body?.apiKey,
      actorName: req.body?.actorName,
      locId: req.body?.locId || req.body?.loc_id,
    });
    res.json(result);
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

app.get('/driver/me', requireDriver, (req, res) => {
  const d = req.driver;
  res.json({
    driverId: d.driver_id,
    firebaseUid: d.firebase_uid,
    fullName: d.full_name,
    phone: d.phone,
    locId: d.loc_id,
    routeCd: d.route_cd,
    isAvailable: !!d.is_available,
  });
});

app.get('/driver/jobs', requireDriver, async (req, res) => {
  try {
    const type = req.query.type === 'pickup' ? 'pickup' : 'delivery';
    const jobs = await drivers.listJobs(req.driver, type);
    res.json({ jobs });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/driver/jobs/:cnNo', requireDriver, async (req, res) => {
  try {
    let job = await drivers.getJob(req.driver, req.params.cnNo);
    if (!job) {
      // Allow lookup for scan flow — still require auth, but not assignment
      job = await drivers.getJobByCn(req.params.cnNo);
    }
    if (!job) return res.status(404).json({ error: 'Job not found' });
    res.json({ job });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/driver/jobs/:cnNo/navigate', requireDriver, async (req, res) => {
  try {
    const job =
      (await drivers.getJob(req.driver, req.params.cnNo)) ||
      (await drivers.getJobByCn(req.params.cnNo));
    if (!job) return res.status(404).json({ error: 'Job not found' });
    res.json({ url: drivers.navigateUrl(job) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/driver/jobs/:cnNo/accept', requireDriver, async (req, res) => {
  try {
    const result = await drivers.acceptJob(req.driver, req.params.cnNo);
    res.json(result);
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

app.post('/driver/jobs/:cnNo/status', requireDriver, async (req, res) => {
  try {
    const result = await drivers.updateStatus(
      req.driver,
      req.params.cnNo,
      req.body || {},
    );
    res.json(result);
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

/** Scan by CN — assigns if needed for pickup/OFD, else uses ops path when assigned to self. */
app.post('/driver/jobs/:cnNo/scan', requireDriver, async (req, res) => {
  try {
    const body = req.body || {};
    const status = body.status || body.scanType;
    const job = await drivers.getJobByCn(req.params.cnNo);
    if (!job) return res.status(404).json({ error: 'Job not found' });

    const assignedToMe =
      job.assignedDriverId != null &&
      Number(job.assignedDriverId) === Number(req.driver.driver_id);

    if (assignedToMe) {
      const result = await drivers.updateStatus(req.driver, req.params.cnNo, {
        ...body,
        status,
      });
      return res.json(result);
    }

    // Auto-claim for driver field scans when unassigned (demo convenience)
    if (!job.assignedDriverId) {
      await drivers.assignJob({
        cnNo: req.params.cnNo,
        firebaseUid: req.driver.firebase_uid,
        jobType: 'pipeline',
        apiKey: process.env.DISPATCH_API_KEY,
      });
      const result = await drivers.updateStatus(req.driver, req.params.cnNo, {
        ...body,
        status,
      });
      return res.json(result);
    }

    return res.status(403).json({ error: 'Job assigned to another driver' });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

app.post('/driver/devices/fcm-token', requireDriver, async (req, res) => {
  try {
    const token = req.body?.token;
    if (!token) return res.status(400).json({ error: 'token required' });
    const result = await drivers.registerFcmToken(
      req.driver,
      token,
      req.body?.platform,
    );
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/dispatch/assign', async (req, res) => {
  try {
    const result = await drivers.assignJob({
      cnNo: req.body?.cnNo,
      firebaseUid: req.body?.firebaseUid,
      jobType: req.body?.jobType,
      apiKey: req.headers['x-dispatch-key'] || req.body?.apiKey,
    });
    res.json(result);
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message });
  }
});

const port = Number(process.env.PORT || 3080);
app.listen(port, '0.0.0.0', () => {
  console.log(`IPOSB Driver API listening on 0.0.0.0:${port}`);
});

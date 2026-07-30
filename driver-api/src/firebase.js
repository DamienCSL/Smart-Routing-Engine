let admin = null;
let initialized = false;

function initFirebase() {
  if (initialized) return admin;
  initialized = true;
  try {
    // eslint-disable-next-line global-require
    admin = require('firebase-admin');
    if (!admin.apps.length) {
      if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          projectId: process.env.FIREBASE_PROJECT_ID || undefined,
        });
      } else if (process.env.FIREBASE_PROJECT_ID) {
        admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
      } else {
        admin = null;
      }
    }
  } catch (e) {
    console.warn('[firebase] init skipped:', e.message);
    admin = null;
  }
  return admin;
}

async function verifyIdToken(bearer) {
  const demoAuth = String(process.env.DEMO_AUTH || 'true') === 'true';
  if (!bearer || !bearer.startsWith('Bearer ')) {
    const err = new Error('Missing Authorization Bearer token');
    err.status = 401;
    throw err;
  }
  const token = bearer.slice('Bearer '.length).trim();

  // Demo tokens: "demo:<firebase_uid>" for local integration without Firebase
  if (demoAuth && token.startsWith('demo:')) {
    return { uid: token.slice('demo:'.length), demo: true };
  }

  const fb = initFirebase();
  if (!fb) {
    const err = new Error(
      'Firebase not configured. Set DEMO_AUTH=true or GOOGLE_APPLICATION_CREDENTIALS.',
    );
    err.status = 401;
    throw err;
  }
  const decoded = await fb.auth().verifyIdToken(token);
  return { uid: decoded.uid, demo: false };
}

async function sendFcm(tokens, notification, data = {}) {
  const fb = initFirebase();
  if (!fb || !tokens.length) {
    console.warn('[fcm] skip send — no firebase or tokens', { count: tokens.length });
    return { successCount: 0, skipped: true };
  }
  const response = await fb.messaging().sendEachForMulticast({
    tokens,
    notification,
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)]),
    ),
  });
  return response;
}

module.exports = { initFirebase, verifyIdToken, sendFcm };

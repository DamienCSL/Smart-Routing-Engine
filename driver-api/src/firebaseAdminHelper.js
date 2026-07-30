const admin = require('firebase-admin');

/**
 * Optional Firebase bootstrap helper for production.
 * Prefer GOOGLE_APPLICATION_CREDENTIALS env pointing at a service account JSON.
 */
function initFromServiceAccountJson(serviceAccount) {
  if (admin.apps.length) return admin.app();
  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

module.exports = { initFromServiceAccountJson, admin };

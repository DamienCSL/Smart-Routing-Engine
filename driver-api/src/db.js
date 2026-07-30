const mysql = require('mysql2/promise');

let pool;

/**
 * Resolve MySQL settings for local + Railway.
 * Prefer BBBEXPRESS_DB_* (same as deploy/ PHP), then MYSQL_*, then Railway MYSQL*.
 */
function mysqlConfig() {
  const host =
    process.env.BBBEXPRESS_DB_HOST ||
    process.env.MYSQL_HOST ||
    process.env.MYSQLHOST ||
    '127.0.0.1';
  const port = Number(
    process.env.BBBEXPRESS_DB_PORT ||
      process.env.MYSQL_PORT ||
      process.env.MYSQLPORT ||
      3306,
  );
  const user =
    process.env.BBBEXPRESS_DB_USER ||
    process.env.MYSQL_USER ||
    process.env.MYSQLUSER ||
    'root';
  const password =
    process.env.BBBEXPRESS_DB_PASS ||
    process.env.MYSQL_PASSWORD ||
    process.env.MYSQLPASSWORD ||
    '';
  // Never use Railway's default MYSQLDATABASE ("railway") — app DB is bbbexpress.
  const database =
    process.env.BBBEXPRESS_DB_NAME ||
    process.env.MYSQL_DATABASE ||
    'bbbexpress';

  return { host, port, user, password, database };
}

function getPool() {
  if (!pool) {
    const cfg = mysqlConfig();
    console.log(
      `[mysql] connecting ${cfg.user}@${cfg.host}:${cfg.port}/${cfg.database}`,
    );
    pool = mysql.createPool({
      ...cfg,
      waitForConnections: true,
      connectionLimit: 10,
      dateStrings: true,
      timezone: '+08:00',
    });
  }
  return pool;
}

async function query(sql, params = []) {
  const [rows] = await getPool().execute(sql, params);
  return rows;
}

async function withTransaction(fn) {
  const conn = await getPool().getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

async function ping() {
  await query('SELECT 1 AS ok');
  return true;
}

module.exports = { getPool, query, withTransaction, ping, mysqlConfig };

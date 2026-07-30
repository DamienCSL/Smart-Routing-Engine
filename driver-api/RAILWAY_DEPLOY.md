# Deploy Driver API on Railway (pair with existing web MySQL)

## Goal

```
Flutter  →  https://YOUR-API.up.railway.app  →  MySQL bbbexpress (same as web)
Web FMS  →  MySQL bbbexpress
```

Same database = mobile scans appear on web track / POD screens.

---

## 1. Prep MySQL (once)

In Railway MySQL (or any client connected to it), ensure:

1. Database `bbbexpress` exists (same as web deploy).
2. Run [../integration/mysql/001_driver_integration.sql](../integration/mysql/001_driver_integration.sql)  
   (adds `t_driver`, `t_driver_device`, assignment + lat/lng columns).

Ignore “Duplicate column” errors on re-run.

---

## 2. Create Driver API service on Railway

**Option A — from this folder (recommended)**

1. Push `driver-api/` to a GitHub repo (or a monorepo with root = `driver-api`).
2. Railway → **New Project** → **Deploy from GitHub** → select that repo.
3. Root directory = `driver-api` if monorepo; else repo root.
4. Railway detects `Dockerfile` + `railway.json` (healthcheck `/health`).

**Option B — empty service + CLI**

```bash
cd driver-api
railway login
railway init
railway up
```

---

## 3. Environment variables (Driver API service)

In Railway → Driver API → **Variables**, set:

| Variable | Value |
|----------|--------|
| `BBBEXPRESS_DB_HOST` | `${{MySQL.MYSQLHOST}}` (or copy MYSQLHOST) |
| `BBBEXPRESS_DB_PORT` | `${{MySQL.MYSQLPORT}}` |
| `BBBEXPRESS_DB_USER` | `${{MySQL.MYSQLUSER}}` |
| `BBBEXPRESS_DB_PASS` | `${{MySQL.MYSQLPASSWORD}}` |
| `BBBEXPRESS_DB_NAME` | `bbbexpress` |
| `DISPATCH_API_KEY` | strong random secret (same as Flutter / web assign) |
| `DEMO_AUTH` | `true` for first test; later `false` + Firebase |
| `PORT` | leave unset (Railway injects it) |

Optional later:

| Variable | Purpose |
|----------|---------|
| `FIREBASE_PROJECT_ID` | Real Auth / FCM |
| `GOOGLE_APPLICATION_CREDENTIALS` | path/JSON for service account |

Do **not** set `MYSQL_DATABASE` / `MYSQLDATABASE` to Railway’s default `railway` DB name.

---

## 4. Networking

1. Driver API → **Settings** → **Networking** → **Generate Domain**  
   → e.g. `https://iposb-driver-api-production.up.railway.app`
2. Open `https://YOUR-API.up.railway.app/health`  
   Expect `{ "ok": true, "database": "bbbexpress", ... }`
3. Optional custom subdomain in Namecheap:  
   `api.iposb.com` CNAME → Railway domain (same pattern as web `www`).

---

## 5. Point Flutter at production API

In app `.env` (or CI flavor):

```
USE_DRIVER_API=true
DRIVER_API_URL=https://YOUR-API.up.railway.app
DEMO_DRIVER_UID=demo-driver-kk
DISPATCH_API_KEY=same-as-railway
USE_FIREBASE=false
```

- Android emulator local: `http://10.0.2.2:3080`  
- Physical phone on LAN: `http://YOUR_PC_LAN_IP:3080`  
- Production: **https** Railway URL above  

Rebuild / restart the Flutter app after changing `.env`.

---

## 6. Point web assign / track at API (optional)

If using PHP helpers from `integration/web/`:

```
IPOSB_DRIVER_API=https://YOUR-API.up.railway.app
IPOSB_DISPATCH_KEY=same-as-railway
```

FMS track screens that read MySQL do **not** need the API — they already share the DB.

---

## 7. Smoke test

1. `GET /health` → ok  
2. Flutter Demo desk → Create CN → scan PKU…POD  
3. Web track / FMS track for that CN → same timeline  
4. Flutter Track order → same customer labels  

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Health 503 / MySQL error | Check BBBEXPRESS_DB_* and that `bbbexpress` exists |
| Flutter “connection refused” | Wrong URL; use https Railway URL on device |
| Scans work locally but not on web | Different MySQL — must be same Railway instance |
| Healthcheck timeout on deploy | Confirm `/health` and listen `0.0.0.0:$PORT` |

---

## Local vs Railway

| | Local | Railway |
|--|--------|---------|
| API | `npm run dev` :3080 | Docker, public HTTPS |
| DB | local MySQL | Railway MySQL |
| Flutter | `127.0.0.1:3080` | `https://…up.railway.app` |

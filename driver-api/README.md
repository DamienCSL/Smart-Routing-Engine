# IPOSB Driver API

Node Express bridge over MySQL (`bbbexpress`) + optional Firebase Auth/FCM.

## Run locally

```bash
npm i
cp .env.example .env
npm run dev
```

Listens on `0.0.0.0:3080` by default.

## Deploy on Railway (pair with web)

See **[RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md)** — Dockerfile + `railway.json` included.

Summary: same MySQL as FMS → Flutter `DRIVER_API_URL=https://YOUR-API.up.railway.app`.

## Endpoints

| Method | Path | Notes |
|--------|------|-------|
| GET | `/health` | Railway healthcheck + DB ping |
| GET | `/tracking/:cnNo` | Public customer status + timeline |
| GET | `/labels/:cnNo` | QR SVG / data URL |
| POST | `/demo/orders` | Create demo CN (`X-Dispatch-Key`) |
| POST | `/ops/scan` | Hub/sort/storekeeper scans |
| GET | `/driver/me` | Bearer |
| GET | `/driver/jobs` | Bearer |
| POST | `/driver/jobs/:cnNo/scan` | Bearer — field scan |
| POST | `/dispatch/assign` | `X-Dispatch-Key` |

Demo auth: `Authorization: Bearer demo:demo-driver-kk` when `DEMO_AUTH=true`.

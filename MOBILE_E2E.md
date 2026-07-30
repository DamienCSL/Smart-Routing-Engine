# Mobile E2E — Customer order to delivery

Uses Flutter app in `D:\Demo Projects\Smart Routing Engine` against PHP API in `D:\iposb source code\deploy`.

## Prerequisites

1. MySQL/MariaDB with `bbbexpress` loaded:
   - `sql/bbbexpress_schema.sql`
   - `sql/legacy_compat.sql`
   - `sql/002_driver_mobile_api.sql`
   - `sql/003_mobile_api_complete.sql`
2. PHP API running:

```powershell
cd "D:\iposb source code\deploy"
php -S 0.0.0.0:8080 router.php
```

3. Confirm: open `http://127.0.0.1:8080/api/health`

4. Flutter `.env`:

```
USE_DRIVER_API=true
DRIVER_API_URL=http://127.0.0.1:8080/api
DEMO_DRIVER_UID=demo-driver-kk
DISPATCH_API_KEY=iposb-dispatch-dev-key
USE_FIREBASE=false
```

Android emulator: `DRIVER_API_URL=http://10.0.2.2:8080/api`

## Demo accounts

| Role | Email | Password |
|------|-------|----------|
| Customer | `customer@iposb.demo` | `customer123` |
| Driver | `driver@iposb.demo` | `driver123` |
| Legacy demo driver token | `demo@iposb.demo` | any |

## Run the app

```powershell
cd "D:\Demo Projects\Smart Routing Engine"
flutter pub get
flutter run -d windows
# or: flutter run -d chrome
```

## Flows

### A) Customer app path

1. Login as `customer@iposb.demo` / `customer123`
2. Create shipment (map pins → New Shipment)
3. See CN on My Shipments; Track order publicly by CN

### B) Ops / driver path (Demo desk)

1. Login as `driver@iposb.demo` / `driver123` (or `demo@iposb.demo`)
2. **Hub Tasks → Demo desk** (＋ icon)
3. **Create demo CN** → **Assign to me**
4. Driver scan hops until **Delivered (POD)**
5. Customer Track view shows Signed / Delivered

## API surface (v2)

- Auth: `POST /auth/register|login|firebase|logout`, `GET /auth/me`
- Customer: `POST|GET /customer/orders`, `GET|POST cancel /customer/orders/{cn}`
- Driver: jobs, accept/reject/scan/POD, `PATCH /driver/me`
- Dispatch: assign/unassign, drivers, unassigned jobs
- Notifications: `GET /notifications`, `POST /notifications/{id}/read`
- Utils: `/branches`, `/status-map`, `/tracking/{cn}`

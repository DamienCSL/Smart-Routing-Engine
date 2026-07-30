# IPOSB Integration

Bridges the **Flutter driver app** with the **legacy FMS MySQL** master (BBB Express → IPOSB).

| Path | Purpose |
|------|---------|
| [STATUS_MAP.md](STATUS_MAP.md) | SOP scans + customer labels |
| [mysql/001_driver_integration.sql](mysql/001_driver_integration.sql) | `t_driver`, devices, lat/lng, assignment |
| [../driver-api](../driver-api) | Optional legacy Node API (prefer PHP deploy pack) |
| [web/iposb_track.php](web/iposb_track.php) | **Customer** order tracking (public) |
| [web/iposb_ops_scan.php](web/iposb_ops_scan.php) | Ops desk: create demo CN + scan hops |
| [web/iposb_assign_driver.php](web/iposb_assign_driver.php) | Assign driver → FCM |

## Recommended backend: PHP deploy pack

Use `D:\iposb source code\deploy` (same MySQL as FMS). Flutter talks to `/api`.

```bash
# 1) MySQL up + schemas loaded:
#    bbbexpress_schema.sql → legacy_compat.sql → 002_driver_mobile_api.sql

# 2) Start PHP
cd "D:\iposb source code\deploy"
php -S 0.0.0.0:8080 router.php

# 3) Flutter .env
USE_DRIVER_API=true
DRIVER_API_URL=http://127.0.0.1:8080/api
DISPATCH_API_KEY=iposb-dispatch-dev-key
DEMO_DRIVER_UID=demo-driver-kk
```

Android emulator: use `http://10.0.2.2:8080/api`.

## Complete E2E test (customer → receive)

1. Run Flutter app (Windows / Chrome / device).
2. **Sign in** with any email + any password (demo driver auth).
3. Hub Tasks → **Demo desk** (＋):
   1. **Create demo CN** (customer order)
   2. **Assign to me** (dispatch)
   3. Tap **Driver:** scan hops `PKU → … → POD`
   4. **Open customer Track view** — timeline until Signed / Delivered
4. Or open **Hub Tasks → Delivery** after assign and scan from task detail.

Optional: FMS web assign at `/FMS/operations/driver_assign.php`.

### API cheat sheet (PHP)

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/health` | public |
| GET | `/api/tracking/:cnNo` | public |
| POST | `/api/demo/orders` | `X-Dispatch-Key` |
| GET | `/api/dispatch/drivers` | `X-Dispatch-Key` |
| POST | `/api/dispatch/assign` | `X-Dispatch-Key` |
| GET | `/api/driver/jobs` | Bearer `demo:uid` |
| POST | `/api/driver/jobs/:cn/scan` | Bearer |

Dispatch key default: `iposb-dispatch-dev-key`.

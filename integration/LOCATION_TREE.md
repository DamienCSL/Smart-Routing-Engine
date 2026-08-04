# Location tree — Hub → Minihub/Station → Drop Point

Facility hierarchy for IPOSB / BBB Express (MySQL master).

```
Hub (root)                 e.g. BKI, SDK, TWU
 └── Minihub / Station     e.g. SBH325, 805, SBH326, SDK-ST1
      └── Drop Point       e.g. DP-KK-02, DP-KK-03
```

## Receive rules

| Node | Receives shipments from |
|------|-------------------------|
| **Hub** | Upstream network / origin pickups (city root) |
| **Minihub / Station** | **Its parent hub only** |
| **Drop Point** | **Its parent minihub/station only** (never directly from root hub) |

Minihub and Station are the same tier (`location_level` = `minihub` or `station`). Use whichever label fits ops; both sit under a hub and may own drop points.

## Schema

Migration: `D:\iposb source code\deploy\sql\011_location_tree.sql`

- `t_hub.parent_hub_code` — null for root hubs
- `t_hub.location_level` — `hub` | `minihub` | `station`
- `t_drop_point.hub_code` — **must** reference a minihub/station
- `t_route_rule.via_hub_code` — root hub on the corridor
- `t_route_rule.via_station_code` — station/minihub hop under that hub

## API

| Endpoint | Notes |
|----------|--------|
| `GET /hubs` | Optional `?level=hub\|minihub\|station&parent=BKI` |
| `GET /hubs/tree` | Nested hub → stations → dropPoints |
| `GET /drop-points?station=SBH325` | Drops under one station |

Scan `locId` resolves from the tree (ARR → receive station under origin hub, SRT → sort station, etc.).

## Flutter

`lib/core/constants/location_tree.dart` — `FacilityNode`, `DropPointNode`, `LocationTreeRules` for cascading pickers.

## FMS

- **Hub Management** — set level + parent hub
- **Drop Point Management** — parent picker limited to minihubs/stations

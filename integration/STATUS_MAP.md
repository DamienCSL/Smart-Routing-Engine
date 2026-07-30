# IPOSB mobile ↔ FMS status map (Sprint 1 SOP)

Frozen contract for the Driver API. Master tables: `t_consignment.cn_status`, `t_cn_track`.

Timezone for overnight / return windows: **Asia/Kuala_Lumpur (UTC+8)**.

## Happy-path scans (E2E demo)

| Who | Scan / API `status` | FMS `cn_status` | Customer label |
|-----|---------------------|-----------------|----------------|
| Order created | `BDE` (or seed) | `BDE` | Pending Pickup |
| Driver pickup @ seller | `PKU` | `INB` | Collected |
| Arrive at hub (normal) | `ARR` | `INB` | In Transit |
| Hub sort SBH325/326 | `SRT` | `SHB` | In Transit |
| Storekeeper receive | `SHB` | `SHB` | To Be Delivered |
| Dispatcher assign | track `ACC` | (unchanged) | To Be Delivered |
| Driver OFD | `OFD` | `OFD` | To Be Delivered |
| Driver with courier | `DRS` | `DRS` | To Be Delivered |
| Delivered + photo | `POD` | `POD` | Signed / Delivered |
| Failed attempt | `UND` | `UND` | Problematic / Delayed |

## Extra SOP scans (later sprints)

| Scan | Meaning | Customer label |
|------|---------|----------------|
| `OVN` | Overnight (before 15:00 MYT) | Problematic / Delayed |
| `SCF` | Self-collection T1/T2/T3 | To Be Delivered |
| `RTN` | Return registration | Returning to Sender |
| `N13` | Departed no arrival 24h | Problematic / Delayed |
| `N12` / `N9` | Damage | Problematic / Delayed |
| `HUB` | Hub handoff shortcut (skip sort; maps toward SHB) | In Transit |
| `GWD` | Gateway depart | In Transit |
| `ACC` | Accept / assigned | Pending Pickup / To Be Delivered |

## Allowed transitions (Sprint 1 pipeline)

```
* → ACC → PKU → ARR → SRT → SHB → OFD|DRS → POD
                              OFD|DRS → UND
```

Also allowed for compatibility with prior mobile build:
- pickup path: `ACC → PKU → HUB` (HUB treated like SHB for CN status)
- delivery path: `OFD|DRS → POD|UND`

Terminal success: `POD` (and POD variants `PCC`/`PFP`/`PCB`).

## Customer web tracking

- Public `GET /tracking/{cn_no}` returns detailed timeline text with hub/location, e.g.
  - `Parcel arrived at SBH325 hub`
  - `Parcel sorting at 805 hub`
  - `Parcel out for delivery from BKI`
- `shortLabel` still has the coarse bucket (`In Transit`, `To Be Delivered`, …).
- `customerLabel` on timeline rows uses the detailed sentence.
- Scans may send `locId` (e.g. `SBH325`, `805`); otherwise SOP defaults apply (ARR/SHB→SBH325, SRT→805).
- Web UI: `integration/web/iposb_track.php` — customer enters CN/AWB.

## QR / barcode

- Label payload = plain `cn_no` (AWB).
- `GET /labels/{cn_no}` returns QR (SVG/data URL).
- Mobile camera scan → confirm next allowed scan → `POST /ops/scan` or `/driver/jobs/{cn}/status`.

## Identity keys

| Concept | FMS | Mobile / Web |
|---------|-----|--------------|
| AWB | `t_consignment.cn_no` | trackingNumber / QR payload |
| Branch | `t_location.loc_id` | locId |
| Driver | `t_driver.driver_id` + `firebase_uid` | Firebase Auth uid |
| Event | `t_cn_track` row | scan POST |

## Notes

- Web clerks still create CNs in FMS; Sprint 1 also has `POST /demo/orders` for local demos.
- Mobile never invents a second shipment master.
- Firebase is Auth + FCM only.

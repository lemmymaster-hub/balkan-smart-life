# Sarajevo public transport: lines 106 and 3

The existing **Gradski prevoz** home tile opens a native BSL map for:

- trolleybus **106 Otoka – Vogošća**, Ministry line ID `225`;
- tram **3 Baščaršija – Ilidža**, Ministry line ID `130`.

Both directions are fetched from the Ministry. The screen explicitly identifies
Sarajevo regardless of the home screen's selected city; it does not imply that
these routes operate in other BSL cities.

## Source and verification

The public endpoint paths and JSON contracts were identified by inspecting the
user-supplied Arrivo BiH 1.9.3 (137) APK. BSL implements an independent REST
client; it does not copy Arrivo code, graphics, map tokens or bundled datasets.

Direct HTTPS checks on **15 October 2026** returned HTTP 200 for both lines,
both directions, all four station lists and route geometries, both timetables,
and POST requests for arrivals. No account session or API key was supplied.
The Arrivo vehicle proxy returned HTTP 403 and is not used.

| Data | Ministry path | Identifier |
| --- | --- | --- |
| Directions | `/api/public/lines/line/{id}/directions/list` | line ID |
| Stops | `/api/public/lines/terminus-line/{id}/stations-with-distance/list/0/0` | direction ID |
| Geometry | `/public-api/public/lines/terminus-line/{id}/station-line/points/list` | direction ID |
| Timetable | `/api/public/lines/timetables/{id}/list` | line ID |
| Arrivals | POST `/api/public/lines/upcoming-arrivals` | JSON `line_id`, `terminus_line_id`, `station_id`, `limit` |

Verified directions: `1132` Otoka → Vogošća, `1133` Vogošća → Otoka,
`1125` Baščaršija → Ilidža, `207` Ilidža → Baščaršija.

Stops are returned alphabetically. The model orders them by projection onto the
actual direction geometry. Geometry point IDs are **not** station IDs and must
not be used as the `station_id` in an arrival request. Terminal station IDs are
`171` Otoka, `1337` Vogošća, `1454` Baščaršija and `149` Ilidža.

## Live-data semantics

- Arrival requests run for the selected station only, every 30 seconds while
  foregrounded. Changing the route or station invalidates old asynchronous results.
- Arrival responses were observed to contain duplicate travel orders and both
  destination stations despite a direction filter. BSL filters by line and the
  direction's destination terminal, deduplicates by travel order and removes
  expired predictions.
- The map uses the coordinates returned **with the arrival predictions**. The
  API does not supply a GPS measurement timestamp in this response. BSL labels
  that limitation and does not claim to show every vehicle in the fleet.
- Arrival data and vehicle markers expire after 60 seconds. Network errors clear
  vehicle markers, show an error and preserve the loaded route/stop list.
- At the checked time tram 3 returned predictions and coordinates. Trolleybus
  106 returned an empty arrival list; this is displayed explicitly rather than
  replaced with simulated vehicles or timetable-based ETAs.
- Timetables are terminal departures, never intermediate-stop arrival estimates.
  They respect validity, weekday, passenger service and a user-selectable holiday
  schedule. Times use Sarajevo civil time including EU DST boundaries, independent
  of the phone timezone. Automatic holiday detection is not provided.

## BSL integration

Uses `BslModuleTopBar`, `BslColors`, glass cards, the existing dark map style,
`GoogleMapsNavigationView`, and `BslLocationContext`. Native navigation UI remains
disabled in this screen. Existing parking, EV, ATM, wallet, authentication and
AI flows are unchanged. No new packages, database schemas, Firebase rules,
credentials or backend deployment are required for these public requests.

Public availability can change. An authenticated future feed must use the
existing BSL backend for server-side credentials; do not embed a private token
in the Flutter client. The current integration targets the native Android/iOS
app; browser CORS support has not been established.

## Verification

Tests cover source paths/request IDs, HTTP failures, route order, duplicate and
opposite-direction arrivals, expired positions, Sarajevo DST, timetable validity,
late asynchronous responses, background refresh suppression, independent timetable
failures, and the small-phone line selector/search UI without a native map.
A signed-device test remains necessary for Google map rendering and GPS controls.

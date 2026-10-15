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

- Arrival requests run for the selected station only, every 5 seconds while
  foregrounded. Changing the route or station invalidates old asynchronous results.
- Arrival responses were observed to contain duplicate travel orders and both
  destination stations despite a direction filter. BSL filters by line and the
  direction's destination terminal, deduplicates by travel order and removes
  expired predictions (with a short grace for zero-minute arrivals).
- The map uses the coordinates returned **with the arrival predictions**. The
  API does not supply a GPS measurement timestamp in this response. BSL labels
  that limitation and does not claim to show every vehicle in the fleet.
- Arrival data and vehicle markers are treated as stale after 20 seconds. Network errors freeze/fade
  last known vehicle markers, suppress ETAs and preserve the loaded route/stop list.
- At the checked time tram 3 returned predictions and coordinates. Trolleybus
  106 returned an empty arrival list; this is displayed explicitly rather than
  replaced with simulated vehicles or timetable-based ETAs.
- Timetables are terminal departures, never intermediate-stop arrival estimates.
  They respect validity, weekday, passenger service and a user-selectable holiday
  schedule. Times use Sarajevo civil time including EU DST boundaries, independent
  of the phone timezone. Automatic holiday detection is not provided.

## Vehicle interaction and rendering

The first view is a compact map, line/direction controls, and one arrival card.
Station search is in a picker; the terminal timetable is in the overflow menu.
No raw API URLs, GPS implementation details or update timestamps clutter the map.

Station ETA prioritizes `arrival_minutes` up to 59 minutes, matching the official
website. The `expected_arrival` field can disagree; it is only a fallback for
longer-range times. The source has minute precision, so the UI shows `≈ N min`
or `Stiže`, not an unsupported exact second countdown.

The destination-terminal arrival query supplies available direction vehicles
independently of the selected boarding station. A vehicle tap projects its
latest observed position onto the direction geometry, selects the next stop
(at most 100 m off the route), and requests that station's prediction for the
same travel-order ID. If the source has no matching prediction, ETA is unknown;
no average-speed or scheduled-time estimate is substituted.

Yellow articulated tram and trolleybus geometric meshes are rendered in
perspective with roofs, windows, doors, wheels, articulation and respective
pantograph/trolley poles. Google Navigation's marker API accepts bitmaps, not
world-space GLB models: 36 depth-sorted mesh views per vehicle type form a
pre-rendered 3D rotation atlas. The map uses a fixed north-up viewing angle so
the mesh's heading stays aligned. This is volumetric 3D rendering to native
marker images, not a GLB object inserted into Google's scene.

Stable native markers are batch-updated up to 20 FPS. Movement interpolates
along route geometry between confirmed observations, with up to one observation
interval of visual delay; it never predicts motion past the newest sample.
Repeated coordinates stop, long gaps/large jumps reset, and backgrounding pauses
animation/polling. No higher GPS accuracy or sampling frequency than the source
can provide is implied.

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

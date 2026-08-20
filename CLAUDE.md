# Baby Bullet (repo/Xcode project: CT)

iOS app, plan Caltrain rides. Swift 6, iOS 26+, SwiftUI, strict concurrency on.

## What it does
Riders plan Caltrain trips: timetables, station info, service status. No booking (Caltrain has no seat reservation).
Full feature list: `docs/FEATURES.md`.

## Data sources
- **Timetable + holidays**: 511.org Open Data API (GTFS), always `format=json` — never XML. Downloaded offline via local Python script (not in-app), using our 511 token. Bundled/synced into app, not fetched live from device.
- **Live train position/delay + service alerts**: fetched directly from device via 511.org's real-time transit API (SIRI `StopMonitoring`/`VehicleMonitoring`, GTFS-Realtime `servicealerts`) — see `CT/Realtime/`. Always `agency=CT`, `format=json`. Responses arrive UTF-8 with a leading BOM; strip it before `JSONDecoder` (see `FiveElevenRealtimeClient.decode`, mirrors `scripts/five_eleven.py`'s `parse_json`). Note `VehicleMonitoring` wraps its payload in a `Siri` envelope, `StopMonitoring` does not — confirmed against live responses, don't assume a shared envelope shape.
- **Service alerts, second source**: `GET https://www.caltrain.com/gtfs/api/v1/servicealerts/Caltrain` — Caltrain's own PADS (Passenger Alert Display System) feed, the same one caltrain.com/alerts renders. Undocumented, unauthenticated, not part of 511's Open Data program — found by reading caltrain.com's minified JS (`populatePADSServiceAlerts`), so it could change or break without notice. Exists because 511's `servicealerts` feed only relays a subset of what PADS has (confirmed live: PADS carried alerts 511 didn't). `RealtimeService.alerts()` fetches both and merges, deduping exact header+description matches; throws only if both sources fail. See `CT/Realtime/PADSAlertDTO.swift` for the payload shape, which differs from 511's (bare JSON array, and the real message is usually in `DescriptionText` with `HeaderText` left blank).
- **Limitation**: 511 real-time is a live snapshot only, not a history API — once a trip's service day has genuinely ended it may return no data at all. "Was this past train delayed" only works while 511 still has it; there's no local capture-over-time yet, so don't try to fake historical data when 511 returns nothing — show an honest "unavailable" state instead. Same volatility applies to alerts on both sources: an alert present one minute can be gone the next, independent of the other source.
- Runtime API token lives in `CT/App/Secrets.swift` (gitignored; `Secrets.swift.example` committed as the template) — same pattern as the import script's `.env`. Not needed for the PADS alerts endpoint above, which takes no key.
- Base endpoint: `https://api.511.org`. Every request needs `api_key` param. Errors: 401 = bad key, 500 = server error.
- Spec: `docs/511_SF_Bay_open_data_specification-Overview_2026.pdf`.

## 511 import tooling (`scripts/` or `tools/`, Python)
- Python script(s), run manually/on-demand — not part of app build or CI
- Token loaded from `.env` (`FIVE_ELEVEN_API_TOKEN=...`), via `python-dotenv` — `.env` gitignored, never committed; `.env.example` (blank value) committed instead
- Script hits 511 REST endpoints with `format=json`, parses JSON, writes into the app's SQLite DB (see Persistence) — no XML parsing needed
- Keep script deps minimal: `requests` (or stdlib `urllib`) + `python-dotenv`; a `requirements.txt` in the script's folder

## Stack
- SwiftUI, Swift 6 strict concurrency (`Sendable`, actors — no `@preconcurrency` escape hatches unless justified)
- Swift Testing (`@Test`) for CTTests, not XCTest, unless matching existing XCTest style in repo
- No third-party deps unless asked — prefer Foundation/SwiftUI/Swift Concurrency

## Persistence
- SQLite, raw `sqlite3` C API (`import SQLite3`), no wrapper lib (no GRDB/SwiftData)
- One local DB, single file, holds everything: GTFS timetables, holidays, stops/stations, AND user preferences (same store, not split)
- DB access wrapped behind an `actor` (single writer, serialized access) — never touch `sqlite3` handles off that actor
- Local import script writes timetable/holiday tables from 511 GTFS downloads; app only reads those tables (+ writes to its own prefs tables)
- Schema/migrations: plain versioned SQL files (`user_version` pragma), applied on launch

## Conventions
- `@Observable` model/view-model types hold state + logic, Views bind via `@State`/`@Environment`. No ViewModel-per-trivial-View — simple views can own `@State` directly
- GTFS data → local models via a parsing/import step, not raw GTFS types in views
- Async work via `async/await`, no completion handlers
- One type per file, file name == type name
- UI supports light and dark mode — use system colors/semantic colors (`Color(.systemBackground)`, `.primary`, asset catalog color sets with both appearances), no hardcoded hex colors that break in one theme

## Design source
UI design lives in Claude Design, not in this repo. To pull it in:
- Use the `claude_design` MCP (`https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`) to import: https://claude.ai/design/p/c0fdaf97-3c0d-4b9a-8870-47ee131ff752?file=Baby+Bullet.dc.html
- Focus file: `Baby Bullet.dc.html` (whole project is readable). It imports `ios-frame.jsx` and `support.js` — read those too.
- Implement: `Baby Bullet.dc.html`.

## Commands
- Build: `xcodebuild -project CT.xcodeproj -scheme CT build`
- Test: `xcodebuild -project CT.xcodeproj -scheme CT test`

## Non-goals (for now)
- Historical delay tracking for trips whose service day has already ended (would need local capture-over-time, not just live polling)

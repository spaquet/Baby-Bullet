# Baby Bullet (repo/Xcode project: CT)

iOS app, plan Caltrain rides. Swift 6, iOS 26+, SwiftUI, strict concurrency on.

## What it does
Riders plan Caltrain trips: timetables, station info, service status. No booking (Caltrain has no seat reservation).

## Data sources
- **Timetable + holidays**: 511.org Open Data API (GTFS), always `format=json` — never XML. Downloaded offline via local Python script (not in-app), using our 511 token. Bundled/synced into app, not fetched live from device.
- **Live status/alerts**: our own backend (future feature, not yet built). Do not call 511.org directly from app for status.
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

## Commands
- Build: `xcodebuild -project CT.xcodeproj -scheme CT build`
- Test: `xcodebuild -project CT.xcodeproj -scheme CT test`

## Non-goals (for now)
- Live GPS train tracking (unless 511 exposes it later)

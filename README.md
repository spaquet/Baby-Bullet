# Baby Bullet

iOS app (Swift 6, iOS 26+, SwiftUI) to help riders plan Caltrain trips: timetables, stations, service status.

## 511 Open Data

Timetable, holiday, and stop data comes from the [511.org Open Data](https://511.org/open-data) API.

**You need your own 511 Open Data token to run the import scripts.** Request one free at [511.org/open-data](https://511.org/open-data) — it's not included in this repo and must never be committed.

The API spec this project was built against is `docs/511_SF_Bay_open_data_specification-Overview_2026.pdf`. Before relying on it, check [511.org/open-data](https://511.org/open-data) for a newer version — the spec updates independently of this repo and may have moved on since 2026.

## Setup

1. Copy `.env.example` to `.env` and fill in your token:
   ```
   FIVE_ELEVEN_API_TOKEN=your_token_here
   ```
2. Install script dependencies:
   ```
   pip install -r scripts/requirements.txt
   ```
3. Open `CT.xcodeproj` in Xcode.

## Importing 511 data

Run scripts from `scripts/` on demand (not part of the app build or CI) to pull data down to `scripts/data/` as JSON:

| Script | Fetches |
|---|---|
| `gtfs_operators.py` | Operators with a GTFS dataset (filtered to Caltrain by default) |
| `gtfs_feed_download.py` | Full GTFS + GTFS+ dataset zip for an operator |
| `timetable.py LINE_ID` | Route timetable for a line |
| `stop_timetable.py STOP_ID` | Scheduled departures/arrivals at a stop |
| `holidays.py` | Service exceptions/holidays for an operator |
| `stops.py` | List of stops (id, name, location) |
| `stop_places.py` | Detailed physical stop places |

All default `--operator-id` to `CT` (Caltrain). See each script's docstring for full usage.

Downloaded data feeds the app's local SQLite store — see `CLAUDE.md` for architecture details.

## Development

See `CLAUDE.md` for stack conventions, persistence design, and build/test commands.

# Baby Bullet — Features

## Core

**Home / Routes tab** — *built*
Today's departures from the home (or, with location on, nearest) station: full remaining schedule from 40 minutes ago through end of service — not just a short "next few" list — opened pre-scrolled to the current time, with already-departed trains shown dimmed rather than dropped. Holiday-schedule banner when a GTFS `calendar_dates` exception applies to today.

**Trip planning** — *built*
Pick origin/destination station and a schedule (Weekday/Weekend/Holiday — Holiday only offered when today actually has a holiday exception), get matching Caltrain trips with departure/arrival time, duration, and stop count, computed from GTFS `stop_times`/`trips`/`calendar`.

**Station detail** — *built*
Per-station page: today's remaining departures (same "from 40 min ago, centered on now" list as Home), a wheelchair-accessibility note when a platform's real GTFS `wheelchair_boarding` value says it isn't accessible, and one-tap directions via Apple Maps.

**Stop-by-stop trip detail** — *built*
Tapping a departure or trip result shows every stop it makes (or, for a planned trip, every stop between the chosen origin and destination) with per-stop times, from GTFS `stop_times`.

**Settings** — *built*
Home station picker, location-services toggle, notifications toggle (no notifications sent yet — see below). All persisted in the app's own SQLite `preferences` table.

**Service alerts** — *placeholder*
Alerts tab exists but is intentionally empty until our own live-status backend ships (CLAUDE.md: alerts are never fetched directly from 511.org). No timetable-side holiday banner is faked either — it's real `calendar_dates` data, see Home above.

**Timetable display (full schedule browse)** — *not built*
Browsing a whole line's schedule independent of "today" / a specific trip search isn't implemented yet; Home and Station Detail only show the current service day.

**Live Activity for a planned trip** — *not built*
Dynamic Island + Lock Screen tracking of a chosen trip, degrading gracefully to a schedule-only countdown until our status backend exists.

## Suggested additions

**Notifications for a tracked trip**
Local/push notification ahead of departure ("Leave now to catch the 5:12"), and delay alerts once live status exists. The Settings toggle for this exists already; nothing triggers it yet.

**Favorites / recent trips**
Save common origin-destination pairs or stations for one-tap re-planning; store in the same SQLite prefs tables as other user settings.

**Bike car info**
GTFS `trips.txt`'s `bikes_allowed` is already imported (`Trip.bikesAllowed`) but not surfaced in any view yet — no per-car position data exists in the feed, only allowed/not-allowed per trip.

**Widgets & Shortcuts**
Home Screen/Lock Screen widget for a favorite station's next departures; App Intents/Siri Shortcut ("When's my next train?").

**Fare estimate**
Rough zone-based fare between two stations, computed from GTFS fare-zone data — informational only, no payment/booking (non-goal).

**Station amenities (parking, ticket machines, restrooms, Uber/Lyft deep link)**
Not in Caltrain's 511 GTFS/GTFS+ feed at all — checked the `stopplaces` endpoint too, which returns `"unknown"` for accessibility on nearly every platform, no better than GTFS's own field. Would need a different data source; not something to fake.

**Remote timetable updates (no app-store release needed for schedule changes)**
Spec'd, not built — see `docs/REMOTE_DATA_UPDATES.md`. App would periodically pull an updated `BabyBullet.sqlite` from a GitHub Release and hot-swap the timetable tables via the migration path `CTDatabase` already uses for bundled-DB upgrades, leaving `preferences` untouched. Schema changes still require an app update; this only covers data (new season's GTFS) refreshes.

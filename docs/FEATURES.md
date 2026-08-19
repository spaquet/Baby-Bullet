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

**Live train tracking** — *built*
Each stop in the stop-by-stop sheet shows a live status pill — on time / delayed / early, or "Live data unavailable" — fetched directly from 511.org's real-time `StopMonitoring` API per stop, matched to the trip by GTFS trip ID. Works for upcoming and recently-departed trains alike, as long as 511 still has current data for that service day; 511's real-time feed has no history, so a train whose day has fully ended may show as unavailable rather than a fabricated status.

**Settings** — *built*
Home and optional Work station pickers, location-services toggle, notifications toggle (no notifications sent yet — see below). All persisted in the app's own SQLite `preferences` table.

**Service alerts** — *built*
Alerts tab fetches Caltrain's active service alerts live from 511.org's real-time GTFS-Realtime `servicealerts` feed (JSON) — header/description text per alert, pull-to-refresh, distinct "no alerts" vs "couldn't reach 511" states. No timetable-side holiday banner is faked either — it's real `calendar_dates` data, see Home above.

**Widgets** — *built*
Home Screen and Lock Screen widget for the next two departures. With a Work Station configured, it shows Home → Work trains and has an in-widget control to reverse to Work → Home.

**Live Activity for a planned trip** — *not built*
Dynamic Island + Lock Screen tracking of a chosen trip, backed by the same live 511 data as the stop-by-stop sheet's delay pill.

## Suggested additions

**Notifications for a tracked trip**
Local/push notification ahead of departure ("Leave now to catch the 5:12"), and delay alerts once live status exists. The Settings toggle for this exists already; nothing triggers it yet.

**Shortcuts**
App Intents/Siri Shortcut ("When's my next train?").

**Remote timetable updates (no app-store release needed for schedule changes)**
Spec'd, not built — see `docs/REMOTE_DATA_UPDATES.md`. App would periodically pull an updated `BabyBullet.sqlite` from a GitHub Release and hot-swap the timetable tables via the migration path `CTDatabase` already uses for bundled-DB upgrades, leaving `preferences` untouched. Schema changes still require an app update; this only covers data (new season's GTFS) refreshes.

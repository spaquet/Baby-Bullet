# Baby Bullet — Features

## Core

**Trip planning**
Pick origin/destination station + time, get matching Caltrain departures (Local/Limited/Express), with transfer/direction info from GTFS.

**Timetable display**
Browse full schedule per line/direction/day-type (weekday, Saturday, Sunday, holiday). Works offline — timetables are bundled/synced from 511 GTFS, not fetched live.

**Live Activity for a planned trip**
Once a trip is selected, a Live Activity (Dynamic Island + Lock Screen) tracks it: next stop, time to departure/arrival, delay/status once our backend status feed exists. Degrades gracefully to schedule-only countdown until then.

**Nearby stations (user location)**
Use device location to rank stations by distance and show the next few scheduled departures at the closest one(s). Location access optional — app fully usable without it via manual station search.

**Station info + directions**
Per-station page: location/map pin, platform/accessibility notes (from GTFS+), and one-tap directions via Apple Maps, plus an Uber/Lyft deep link to the station.

## Suggested additions

**Service alerts & holiday awareness**
Surface 511 holiday/service-exception data directly on the relevant date's timetable ("Reduced holiday schedule today") and, once the backend status feed ships, live disruption alerts.

**Favorites / recent trips**
Save common origin-destination pairs or stations for one-tap re-planning; store in the same SQLite prefs tables as other user settings.

**Notifications for a tracked trip**
Local/push notification ahead of departure ("Leave now to catch the 5:12"), and delay alerts once live status exists.

**Bike car info**
Caltrain trains have designated bike cars; surface bike capacity/car position per trip where GTFS+ data supports it — relevant enough to riders to call out separately from generic timetable data.

**Station parking info**
Static parking availability/type per station (permit, daily, none) — low-effort, high-value addition alongside directions.

**Widgets & Shortcuts**
Home Screen/Lock Screen widget for a favorite station's next departures; App Intents/Siri Shortcut ("When's my next train?").

**Accessibility**
Full VoiceOver/Dynamic Type support; wheelchair-accessibility flags per station where GTFS+ provides them.

**Fare estimate**
Rough zone-based fare between two stations, computed from GTFS fare zone data — informational only, no payment/booking (non-goal).

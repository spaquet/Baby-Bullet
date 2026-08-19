# Remote timetable updates

Goal: refresh GTFS timetable/holiday data (stations, routes, calendars,
trips, stop_times, etc.) without an App Store release, by publishing an
updated `BabyBullet.sqlite` to a GitHub Release and having the app pull it
down periodically. Schema changes still require an app update — this only
covers *data* refreshes against the current schema.

Not built yet. This document specs it; see `docs/FEATURES.md` for build
status of everything else.

## Why this works with the current design

`CTDatabase.open()` (`CT/Persistence/CTDatabase.swift`) already has the
exact mechanism needed, just pointed at the bundled DB:

1. On first launch, copies `BabyBullet.sqlite` from the bundle into
   Application Support.
2. On later launches, compares `PRAGMA user_version` of the bundled DB vs.
   the on-disk one; if the bundle is newer, `migrateTimetableTables`
   `ATTACH`es the bundled DB and replaces just the timetable tables
   (`stations`, `platforms`, `routes`, `directions`, `calendars`,
   `calendar_dates`, `trips`, `stop_times`), leaving `preferences` alone.

Remote updates reuse step 2 verbatim, with a downloaded file standing in
for the bundled one as the migration source. No schema or table changes
needed.

## Version model

Two independent version numbers, both already implicit in the schema:

- **Schema version** (`user_version`) — bumps only when `build_db.py`'s
  `SCHEMA` changes (new/changed tables or columns). Requires an app update,
  since the Swift query layer depends on the shape. Remote updates must
  **never** apply if the manifest's schema version doesn't match what the
  running app expects.
- **Data version** — a plain incrementing integer for "which GTFS import is
  this," independent of schema. This is what triggers a remote fetch.

Add a `data_version` column to the existing `preferences` row (single-row
table already used for user prefs — see CLAUDE.md's Persistence section)
rather than a new table:

```sql
ALTER TABLE preferences ADD COLUMN data_version INTEGER NOT NULL DEFAULT 1;
```

`build_db.py` sets both `PRAGMA user_version` (schema) and seeds
`preferences.data_version` (data) when it writes a fresh bundled DB.

## Release manifest

Publish a small JSON manifest alongside each DB asset in the GitHub
Release, e.g. `latest.json`:

```json
{
  "schema_version": 1,
  "data_version": 7,
  "sqlite_url": "https://github.com/<org>/CT/releases/download/data-v7/BabyBullet.sqlite",
  "sha256": "…",
  "published_at": "2026-08-19T00:00:00Z"
}
```

Fetched via the raw asset URL (`https://github.com/<org>/CT/releases/latest/download/latest.json`
or a versioned tag) — a plain GET, no GitHub API auth needed, no rate-limit
concerns for a single small file per app-launch-that-checks.

## Swift: `RemoteDataUpdater`

New actor, `CT/Persistence/RemoteDataUpdater.swift`, sitting next to
`CTDatabase` and calling into it — not part of `CTDatabase` itself, since
networking is a distinct concern from storage:

```swift
actor RemoteDataUpdater {
    static let shared = RemoteDataUpdater()

    private static let manifestURL = URL(string: "https://github.com/<org>/CT/releases/latest/download/latest.json")!
    private static let checkInterval: TimeInterval = 86400 // 1 day

    /// Call once at launch, after CTDatabase.open(). Fire-and-forget from
    /// the caller's perspective — failures are silent, bundled/cached data
    /// is always a valid fallback.
    func checkForUpdateIfDue() async {
        guard shouldCheck() else { return }
        do {
            let manifest = try await fetchManifest()
            guard manifest.schemaVersion == CTDatabase.expectedSchemaVersion else { return }
            let currentDataVersion = try await CTDatabase.shared.dataVersion()
            guard manifest.dataVersion > currentDataVersion else {
                recordCheckTimestamp()
                return
            }
            let tempURL = try await download(manifest)
            try verify(tempURL, sha256: manifest.sha256)
            try await CTDatabase.shared.applyRemoteTimetable(from: tempURL, dataVersion: manifest.dataVersion)
            try? FileManager.default.removeItem(at: tempURL)
            recordCheckTimestamp()
        } catch {
            // Network/parse/verify failure: keep existing data, try again next interval.
        }
    }
}
```

Responsibilities split:

- `RemoteDataUpdater` — network fetch, manifest parsing, checksum
  verification, throttling (`UserDefaults` timestamp, not the SQLite
  prefs table — this is app-local operational state, not a user
  preference).
- `CTDatabase` — gets one new method, `applyRemoteTimetable(from:dataVersion:)`,
  a thin wrapper around the existing `migrateTimetableTables` static func
  (already generalized over "source DB URL" — just needs the `data_version`
  write added alongside the existing `PRAGMA user_version` write) plus a
  `dataVersion()` reader. Runs on the actor, so it serializes correctly
  against any in-flight reads exactly like the bundled-DB migration path
  already does.

Download to a temp file first (`FileManager.default.temporaryDirectory`),
verify SHA-256 before touching the live DB, then hand the verified temp
path to `CTDatabase` — never open/attach a partially-downloaded or
unverified file.

Call site: `CT/App/AppModel.swift`, right after `db.open()`, as a
detached, non-blocking `Task` — app launch must never wait on network.

```swift
try await db.open()
Task { await RemoteDataUpdater.shared.checkForUpdateIfDue() }
```

## Failure handling

- No network / fetch fails → silently keep current data, retry at next
  interval. Never block or show an error for this — timetable data being a
  version behind is not a broken app.
- Checksum mismatch → discard temp file, don't apply, log locally, retry
  next interval.
- `schema_version` mismatch → skip entirely (app is out of date for this
  data; nothing to do until the user updates). This is the one case worth
  a lightweight signal — e.g. a `@AppStorage` flag Settings can read to
  show "an update is available on the App Store," if that's ever wanted.
  Not required for v1.

## Publishing flow (`scripts/`)

Extend `build_db.py`'s existing usage flow with a release step. New script
`scripts/publish_release.py`:

1. Run existing `gtfs_feed_download.py` → unzip → `build_db.py` as today,
   producing `CT/Resources/BabyBullet.sqlite`.
2. Compute new `data_version` (increment from the last published
   `latest.json`, fetched from the current GitHub release).
3. Compute `sha256` of the built DB.
4. `gh release create data-v<N> CT/Resources/BabyBullet.sqlite --title "..."`,
   or `gh release upload` to a rolling `latest` release tag.
5. Generate and upload `latest.json` with the new `data_version`/`sha256`/URL.

Same dependency profile as the rest of `scripts/` (`requests`,
`python-dotenv`) plus the `gh` CLI, which is already assumed available for
this kind of maintenance task — no new Python package needed, `gh` handles
the GitHub API/auth.

This is a manual/on-demand script, run by whoever updates the schedule —
same tier as `build_db.py` today, not part of app build or CI (per
CLAUDE.md's "511 import tooling" section).

## Testing

- Unit test `RemoteDataUpdater`'s manifest parsing and version-comparison
  logic against fixed JSON fixtures — no live network in `CTTests`.
- Manual test: point `manifestURL` at a local `latest.json` (e.g. served
  via `python -m http.server` in `scripts/data/`) pointing to a modified
  DB with a bumped `data_version`, confirm the app picks it up and
  `preferences` (home station, etc.) survive the swap.
- Confirm behavior with airplane mode on (silent no-op, bundled/cached data
  still serves the app).

## Non-goals

- No delta/diff downloads — full DB replacement only; the file is small
  (single line, ~1 season of GTFS) and this keeps the update path simple.
- No user-facing "checking for updates" UI/spinner — this is a silent
  background refresh.
- No schema migrations delivered this way — those still ship via app
  update, per CLAUDE.md's migrations note.

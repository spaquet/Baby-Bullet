#!/usr/bin/env python3
"""Build the app's bundled SQLite database from a downloaded GTFS feed.

Reads the unzipped GTFS files (run gtfs_feed_download.py first, then unzip
scripts/data/gtfs_<operator_id>.zip into scripts/data/gtfs_extract/) and
writes CT/Resources/BabyBullet.sqlite — the read-only timetable/station data
the app bundles and reads at runtime (see CLAUDE.md's Persistence section).
The app's own prefs tables are created empty here too, since it's one
single-file store; the app only ever writes to those.

Only real GTFS fields are imported — no placeholder/mock data. Station
amenities (parking, ticket machines, restrooms) aren't present in Caltrain's
GTFS/GTFS+ feed, so they're intentionally left out rather than faked; the
per-platform `wheelchair_boarding` field (real GTFS data) is imported and
used for accessibility notes instead.

Usage:
  python gtfs_feed_download.py
  cd data && mkdir -p gtfs_extract && cd gtfs_extract && unzip -o ../gtfs_CT.zip
  cd ../.. && python build_db.py
"""

from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
GTFS_DIR = SCRIPTS_DIR / "data" / "gtfs_extract"
DB_PATH = SCRIPTS_DIR.parent / "CT" / "Resources" / "BabyBullet.sqlite"

SCHEMA = """
CREATE TABLE stations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  zone_id TEXT
);

CREATE TABLE platforms (
  id TEXT PRIMARY KEY,
  station_id TEXT NOT NULL REFERENCES stations(id),
  name TEXT NOT NULL,
  lat REAL,
  lon REAL,
  wheelchair_boarding INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_platforms_station ON platforms(station_id);

CREATE TABLE routes (
  id TEXT PRIMARY KEY,
  short_name TEXT NOT NULL,
  long_name TEXT,
  color TEXT,
  text_color TEXT
);

CREATE TABLE directions (
  route_id TEXT NOT NULL,
  direction_id INTEGER NOT NULL,
  label TEXT NOT NULL,
  PRIMARY KEY (route_id, direction_id)
);

CREATE TABLE calendars (
  service_id TEXT PRIMARY KEY,
  monday INTEGER NOT NULL, tuesday INTEGER NOT NULL, wednesday INTEGER NOT NULL,
  thursday INTEGER NOT NULL, friday INTEGER NOT NULL, saturday INTEGER NOT NULL, sunday INTEGER NOT NULL,
  start_date TEXT NOT NULL, end_date TEXT NOT NULL, description TEXT
);

CREATE TABLE calendar_dates (
  service_id TEXT NOT NULL,
  date TEXT NOT NULL,
  exception_type INTEGER NOT NULL
);
CREATE INDEX idx_calendar_dates_date ON calendar_dates(date);

CREATE TABLE trips (
  id TEXT PRIMARY KEY,
  route_id TEXT NOT NULL,
  service_id TEXT NOT NULL,
  headsign TEXT,
  direction_id INTEGER NOT NULL,
  short_name TEXT,
  bikes_allowed INTEGER NOT NULL DEFAULT 0,
  wheelchair_accessible INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_trips_service ON trips(service_id);
CREATE INDEX idx_trips_route ON trips(route_id);

CREATE TABLE stop_times (
  trip_id TEXT NOT NULL,
  stop_id TEXT NOT NULL,
  arrival_time TEXT NOT NULL,
  departure_time TEXT NOT NULL,
  stop_sequence INTEGER NOT NULL,
  stop_headsign TEXT,
  pickup_type INTEGER NOT NULL DEFAULT 0,
  drop_off_type INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id);

CREATE TABLE preferences (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  home_station_id TEXT,
  location_enabled INTEGER NOT NULL DEFAULT 0,
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  onboarding_complete INTEGER NOT NULL DEFAULT 0
);
INSERT INTO preferences (id) VALUES (1);
"""


def read_csv(name: str) -> list[dict]:
    with open(GTFS_DIR / name, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def main() -> None:
    if not GTFS_DIR.exists():
        raise SystemExit(
            f"{GTFS_DIR} not found. Run gtfs_feed_download.py and unzip its "
            "output into scripts/data/gtfs_extract/ first."
        )

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    DB_PATH.unlink(missing_ok=True)

    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)

    stops = read_csv("stops.txt")
    stations = [s for s in stops if s["location_type"] == "1"]
    platforms = [s for s in stops if s["location_type"] == "0"]

    conn.executemany(
        "INSERT INTO stations (id, name, lat, lon, zone_id) VALUES (?, ?, ?, ?, ?)",
        [(s["stop_id"], s["stop_name"], float(s["stop_lat"]), float(s["stop_lon"]), s["zone_id"] or None) for s in stations],
    )
    conn.executemany(
        "INSERT INTO platforms (id, station_id, name, lat, lon, wheelchair_boarding) VALUES (?, ?, ?, ?, ?, ?)",
        [
            (p["stop_id"], p["parent_station"], p["stop_name"], float(p["stop_lat"]), float(p["stop_lon"]), int(p["wheelchair_boarding"] or 0))
            for p in platforms
            if p["parent_station"]
        ],
    )

    routes = read_csv("routes.txt")
    conn.executemany(
        "INSERT INTO routes (id, short_name, long_name, color, text_color) VALUES (?, ?, ?, ?, ?)",
        [(r["route_id"], r["route_short_name"], r["route_long_name"] or None, r["route_color"] or None, r["route_text_color"] or None) for r in routes],
    )

    directions = read_csv("directions.txt")
    conn.executemany(
        "INSERT INTO directions (route_id, direction_id, label) VALUES (?, ?, ?)",
        [(d["route_id"], int(d["direction_id"]), d["direction"]) for d in directions],
    )

    calendar_desc = {c["service_id"]: c["service_description"] for c in read_csv("calendar_attributes.txt")}
    calendars = read_csv("calendar.txt")
    conn.executemany(
        "INSERT INTO calendars (service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date, description) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                c["service_id"], int(c["monday"]), int(c["tuesday"]), int(c["wednesday"]), int(c["thursday"]),
                int(c["friday"]), int(c["saturday"]), int(c["sunday"]), c["start_date"], c["end_date"],
                calendar_desc.get(c["service_id"]),
            )
            for c in calendars
        ],
    )

    calendar_dates = read_csv("calendar_dates.txt")
    conn.executemany(
        "INSERT INTO calendar_dates (service_id, date, exception_type) VALUES (?, ?, ?)",
        [(c["service_id"], c["date"], int(c["exception_type"])) for c in calendar_dates],
    )

    trips = read_csv("trips.txt")
    conn.executemany(
        "INSERT INTO trips (id, route_id, service_id, headsign, direction_id, short_name, bikes_allowed, wheelchair_accessible) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                t["trip_id"], t["route_id"], t["service_id"], t["trip_headsign"] or None, int(t["direction_id"]), t["trip_short_name"] or None,
                int(t["bikes_allowed"] or 0), int(t["wheelchair_accessible"] or 0),
            )
            for t in trips
        ],
    )

    stop_times = read_csv("stop_times.txt")
    conn.executemany(
        "INSERT INTO stop_times (trip_id, stop_id, arrival_time, departure_time, stop_sequence, stop_headsign, pickup_type, drop_off_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                st["trip_id"], st["stop_id"], st["arrival_time"], st["departure_time"], int(st["stop_sequence"]), st["stop_headsign"] or None,
                int(st["pickup_type"] or 0), int(st["drop_off_type"] or 0),
            )
            for st in stop_times
        ],
    )

    conn.execute("PRAGMA user_version = 1")
    conn.commit()
    conn.close()

    print(f"Wrote {DB_PATH} ({len(stations)} stations, {len(trips)} trips, {len(stop_times)} stop_times)")


if __name__ == "__main__":
    main()

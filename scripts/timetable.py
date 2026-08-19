#!/usr/bin/env python3
"""Fetch the full timetable for one route/line.

Calls: GET https://api.511.org/transit/timetable
       ?api_key=...&operator_id=...&line_id=...&format=json

Returns all timetables for the given route, plus supporting elements
the timetable references: the route's ordered list of timepoints,
direction, and day type (service type, e.g. weekday/Saturday/Sunday).

LINE_ID is a 511 GTFS route_id — get valid values from the `routes.txt`
inside the zip from gtfs_feed_download.py.

Output: scripts/data/timetable_<operator_id>_<line_id>.json.

Usage:
  python timetable.py <line_id>                  # e.g. python timetable.py Local
  python timetable.py <line_id> --operator-id CT  # operator_id defaults to CT anyway
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("line_id")
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    resp = get("timetable", {"operator_id": args.operator_id, "line_id": args.line_id})
    data = parse_json(resp)

    out_path = save_json(data, f"timetable_{args.operator_id}_{args.line_id}.json")
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()

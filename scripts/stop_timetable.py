#!/usr/bin/env python3
"""Fetch scheduled departures/arrivals at a single stop (SIRI Stop Timetable).

Calls: GET https://api.511.org/transit/stoptimetable
       ?api_key=...&operatorref=...&monitoringref=...&format=json

Returns all scheduled departures and arrivals at one stop within a
given timeframe (511-defined window, not caller-configurable via a
date param on this endpoint).

STOP_ID is a 511 stop id — get valid values by running stops.py first
and reading its output (511 calls this param `monitoringref`; operator
is `operatorref`).

Output: scripts/data/stop_timetable_<operator_id>_<stop_id>.json.

Usage:
  python stop_timetable.py <stop_id>
  python stop_timetable.py <stop_id> --operator-id CT
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stop_id")
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    resp = get(
        "stoptimetable",
        {"operatorref": args.operator_id, "monitoringref": args.stop_id},
    )
    data = parse_json(resp)

    out_path = save_json(data, f"stop_timetable_{args.operator_id}_{args.stop_id}.json")
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()

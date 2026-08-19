#!/usr/bin/env python3
"""Fetch the list of stops (boarding/alighting points) for an operator.

Calls: GET https://api.511.org/transit/stops?api_key=...&operator_id=...&format=json

Returns each stop's id, name, and lat/lon — the basic list riders pick
from (station selectors, "nearest station", etc.). For richer physical
detail per stop (platforms, accessibility, etc.) see stop_places.py.
Stop ids from this output feed into stop_timetable.py's STOP_ID arg.

Output: scripts/data/stops_<operator_id>.json.

Usage:
  python stops.py                  # Caltrain (operator_id=CT)
  python stops.py --operator-id CT # explicit, same result
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    resp = get("stops", {"operator_id": args.operator_id})
    data = parse_json(resp)

    out_path = save_json(data, f"stops_{args.operator_id}.json")
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()

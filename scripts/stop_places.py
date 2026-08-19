#!/usr/bin/env python3
"""Fetch the list of physical stop places for an operator.

Calls: GET https://api.511.org/transit/stopplaces?api_key=...&operator_id=...&format=json

More detailed than stops.py — covers the physical infrastructure at
each location (e.g. multiple platforms/quays under one station), not
just a name + coordinate.

Output: scripts/data/stop_places_<operator_id>.json.

Usage:
  python stop_places.py                  # Caltrain (operator_id=CT)
  python stop_places.py --operator-id CT # explicit, same result
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    resp = get("stopplaces", {"operator_id": args.operator_id})
    data = parse_json(resp)

    out_path = save_json(data, f"stop_places_{args.operator_id}.json")
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()

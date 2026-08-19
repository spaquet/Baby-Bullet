#!/usr/bin/env python3
"""Fetch the list of service exceptions (typically holidays) for an operator.

Calls: GET https://api.511.org/transit/holidays?api_key=...&operator_id=...&format=json

These are the dates Caltrain runs a modified (usually reduced/Sunday-
type) schedule — needed so the app doesn't show a normal weekday
timetable on, say, Thanksgiving.

Output: scripts/data/holidays_<operator_id>.json.

Usage:
  python holidays.py                  # Caltrain (operator_id=CT)
  python holidays.py --operator-id CT # explicit, same result
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    resp = get("holidays", {"operator_id": args.operator_id})
    data = parse_json(resp)

    out_path = save_json(data, f"holidays_{args.operator_id}.json")
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()

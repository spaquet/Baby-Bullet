#!/usr/bin/env python3
"""List transit operators that have a GTFS dataset available for download.

Calls: GET https://api.511.org/transit/gtfsoperators?api_key=...&format=json

By default only prints the Caltrain row (operator id "CT"); pass --all to
see every Bay Area operator (useful to confirm Caltrain's id hasn't
changed, or to add another operator later).

Output: full response saved to scripts/data/gtfs_operators.json.

Usage:
  python gtfs_operators.py            # print Caltrain's operator entry
  python gtfs_operators.py --all      # print every operator
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, parse_json, save_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="print every operator, not just Caltrain")
    args = parser.parse_args()

    resp = get("gtfsoperators")
    operators = parse_json(resp)

    out_path = save_json(operators, "gtfs_operators.json")
    print(f"Saved {out_path}")

    rows = operators if args.all else [
        o for o in operators if o.get("Id") == CALTRAIN_OPERATOR_ID
    ]
    for o in rows:
        print(o)


if __name__ == "__main__":
    main()

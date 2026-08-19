#!/usr/bin/env python3
"""Download the full GTFS (+ GTFS+) dataset zip for an operator.

Calls: GET https://api.511.org/transit/datafeeds?api_key=...&operator_id=...

Response is a zip file (not JSON) containing standard GTFS files
(routes.txt, stops.txt, trips.txt, stop_times.txt, calendar.txt, ...)
plus 511's GTFS+ extension files (direction names, fare zone names,
etc. not covered by plain GTFS). Unzip and load into the app's SQLite
DB per CLAUDE.md's Persistence section.

Output: scripts/data/gtfs_<operator_id>.zip (overwritten each run).

Usage:
  python gtfs_feed_download.py                  # Caltrain (operator_id=CT)
  python gtfs_feed_download.py --operator-id CT  # explicit, same result
"""

import argparse

from five_eleven import CALTRAIN_OPERATOR_ID, get, save_bytes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operator-id", default=CALTRAIN_OPERATOR_ID)
    args = parser.parse_args()

    # Bulk GTFS download is a zip file, not JSON.
    resp = get("datafeeds", {"operator_id": args.operator_id}, json_format=False)

    out_path = save_bytes(resp.content, f"gtfs_{args.operator_id}.zip")
    print(f"Saved {out_path} ({len(resp.content)} bytes)")


if __name__ == "__main__":
    main()

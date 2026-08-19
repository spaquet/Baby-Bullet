"""Shared client for the 511.org Open Data transit APIs.

Not runnable directly — imported by the other scripts in this folder
(gtfs_operators.py, gtfs_feed_download.py, timetable.py, stop_timetable.py,
holidays.py, stops.py, stop_places.py).

What it does:
  - Loads FIVE_ELEVEN_API_TOKEN from ../.env (via python-dotenv). Exits
    with a clear message if the token is missing.
  - get(path, params, json_format=True): GETs
    https://api.511.org/transit/{path} with api_key (and format=json
    unless json_format=False, used for the binary GTFS zip download).
    Exits on 401 (bad token); raises on other HTTP errors.
  - parse_json(resp): decodes a 511 JSON response — 511 serves JSON as
    text/plain with a UTF-8 BOM, so plain resp.json() can fail; use this.
  - save_json(data, filename) / save_bytes(content, filename): write
    output into scripts/data/ (created if missing, gitignored) and
    return the path written.

Constants:
  BASE_URL              https://api.511.org/transit
  CALTRAIN_OPERATOR_ID  "CT" — 511's operator_id for Caltrain, used as
                         the default --operator-id in every script here.

Setup (once): copy ../.env.example to ../.env and fill in your 511.org
token, then `pip install -r requirements.txt`.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv
import os

BASE_URL = "https://api.511.org/transit"
CALTRAIN_OPERATOR_ID = "CT"

SCRIPTS_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPTS_DIR / "data"


def _load_token() -> str:
    load_dotenv(SCRIPTS_DIR.parent / ".env")
    token = os.environ.get("FIVE_ELEVEN_API_TOKEN")
    if not token:
        sys.exit(
            "FIVE_ELEVEN_API_TOKEN not set. Copy .env.example to .env "
            "and fill in your 511.org token."
        )
    return token


def get(path: str, params: dict | None = None, *, json_format: bool = True) -> requests.Response:
    """GET a 511 transit endpoint. Raises on HTTP error (401 = bad key)."""
    query = {"api_key": _load_token(), **(params or {})}
    if json_format:
        query["format"] = "json"
    resp = requests.get(f"{BASE_URL}/{path}", params=query, timeout=30)
    if resp.status_code == 401:
        sys.exit("511 API returned 401 Unauthorized — check FIVE_ELEVEN_API_TOKEN in .env")
    resp.raise_for_status()
    return resp


def parse_json(resp: requests.Response):
    """511 JSON responses are served as text/plain with a UTF-8 BOM."""
    return json.loads(resp.content.decode("utf-8-sig"))


def save_json(data, filename: str) -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    out_path = DATA_DIR / filename
    out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return out_path


def save_bytes(content: bytes, filename: str) -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    out_path = DATA_DIR / filename
    out_path.write_bytes(content)
    return out_path

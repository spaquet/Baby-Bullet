#!/usr/bin/env python3
"""Publish a fresh GTFS import as a remote data update.

Builds CT/Resources/BabyBullet.sqlite from the currently-downloaded/unzipped
GTFS feed (run gtfs_feed_download.py + build_db.py first, or pass
--skip-build to reuse an already-built file), then publishes it to a GitHub
Release as a remote data update the app can pick up without an App Store
release. See docs/REMOTE_DATA_UPDATES.md for the full design.

Manual/on-demand script, run by whoever updates the schedule — not part of
app build or CI (same tier as build_db.py, per CLAUDE.md's "511 import
tooling" section). Requires the `gh` CLI, authenticated against the repo.

Usage:
  python build_db.py                 # produces CT/Resources/BabyBullet.sqlite
  python publish_release.py          # publishes it as the next data version
  python publish_release.py --skip-build --data-version 12   # explicit version
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
DB_PATH = SCRIPTS_DIR.parent / "CT" / "Resources" / "BabyBullet.sqlite"
MANIFEST_PATH = SCRIPTS_DIR / "data" / "latest.json"
REPO = "spaquet/Baby-Bullet"
RELEASE_TAG = "latest"
MANIFEST_URL = f"https://github.com/{REPO}/releases/latest/download/latest.json"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, text=True, **kwargs)


def schema_version(db_path: Path) -> int:
    conn = sqlite3.connect(db_path)
    try:
        return conn.execute("PRAGMA user_version;").fetchone()[0]
    finally:
        conn.close()


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def current_data_version() -> int:
    """Reads data_version from the currently-published latest.json, if any."""
    try:
        result = run(
            ["gh", "release", "view", RELEASE_TAG, "--repo", REPO, "--json", "assets"],
            capture_output=True,
        )
    except subprocess.CalledProcessError:
        return 0  # no release published yet

    assets = json.loads(result.stdout).get("assets", [])
    if not any(a["name"] == "latest.json" for a in assets):
        return 0

    fetch = run(["curl", "-fsSL", MANIFEST_URL], capture_output=True)
    return json.loads(fetch.stdout).get("data_version", 0)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skip-build", action="store_true", help="reuse the existing CT/Resources/BabyBullet.sqlite instead of rebuilding")
    parser.add_argument("--data-version", type=int, help="explicit data_version; default is current published version + 1")
    args = parser.parse_args()

    if not args.skip_build:
        run([sys.executable, str(SCRIPTS_DIR / "build_db.py")])

    if not DB_PATH.exists():
        raise SystemExit(f"{DB_PATH} not found. Run build_db.py first (or omit --skip-build).")

    version = args.data_version if args.data_version is not None else current_data_version() + 1
    checksum = sha256_of(DB_PATH)
    manifest = {
        "schema_version": schema_version(DB_PATH),
        "data_version": version,
        "sqlite_url": f"https://github.com/{REPO}/releases/download/{RELEASE_TAG}/BabyBullet.sqlite",
        "sha256": checksum,
        "published_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")

    release_exists = subprocess.run(
        ["gh", "release", "view", RELEASE_TAG, "--repo", REPO], capture_output=True
    ).returncode == 0
    if not release_exists:
        run([
            "gh", "release", "create", RELEASE_TAG, "--repo", REPO,
            "--title", "Latest data", "--notes", "Rolling release for remote data updates.",
        ])

    run(["gh", "release", "upload", RELEASE_TAG, str(DB_PATH), "--repo", REPO, "--clobber"])
    run(["gh", "release", "upload", RELEASE_TAG, str(MANIFEST_PATH), "--repo", REPO, "--clobber"])

    print(f"Published data_version {version} (schema_version {manifest['schema_version']}, sha256 {checksum[:12]}...)")


if __name__ == "__main__":
    main()

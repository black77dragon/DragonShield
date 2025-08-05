#!/usr/bin/env python3
"""Replace database contents with data from a legacy database file.

The script removes any existing database at the target path and copies all
structures and data from the legacy database using SQLite's online backup API.

Example:
    python3 load_legacy_database.py /path/to/dragonshield.sqlite legacy.sqlite
"""

import argparse
import sqlite3
from pathlib import Path
from typing import Dict


def _row_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [r[0] for r in cur.fetchall()]
    counts: Dict[str, int] = {}
    for tbl in tables:
        cur = conn.execute(f'SELECT COUNT(*) FROM "{tbl}";')
        counts[tbl] = cur.fetchone()[0]
    return counts


def load_legacy(target_db: Path, legacy_db: Path) -> Dict[str, int]:
    """Replace ``target_db`` with the contents of ``legacy_db``.

    Returns a mapping of table names to row counts after the transfer.
    """
    target_db.unlink(missing_ok=True)
    with sqlite3.connect(legacy_db) as src, sqlite3.connect(target_db) as dst:
        src.backup(dst)
        if dst.execute("PRAGMA integrity_check;").fetchone()[0] != "ok":
            target_db.unlink(missing_ok=True)
            raise RuntimeError("Integrity check failed")
        counts = _row_counts(dst)
    return counts


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Replace database with data from a legacy version"
    )
    parser.add_argument("target", type=Path, help="Path to dragonshield.sqlite")
    parser.add_argument(
        "legacy", type=Path, help="Path to legacy dragonshield.sqlite"
    )
    args = parser.parse_args(argv)

    counts = load_legacy(args.target, args.legacy)
    print("Transfer Summary")
    print(f"{'Table':20}Rows")
    for tbl, cnt in counts.items():
        print(f"{tbl:20}{cnt}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

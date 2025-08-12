#!/usr/bin/env python3
"""Backup and restore DragonShield database using SQLite's online backup API."""

import argparse
import json
import os
import shutil
import sqlite3
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple


def _row_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    cur = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table';"
    )
    tables = [r[0] for r in cur.fetchall()]
    counts = {}
    for tbl in tables:
        cur = conn.execute(f'SELECT COUNT(*) FROM "{tbl}";')
        counts[tbl] = cur.fetchone()[0]
    return counts


def backup_database(db_path: Path, dest_dir: Path, env: str) -> Tuple[Path, Dict[str, int]]:
    dest_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = dest_dir / f"{env}_backup_{ts}.sqlite"
    manifest_path = backup_path.with_suffix(".manifest.json")

    schema_dir = Path(__file__).resolve().parents[1] / "database"
    schema_files = {
        "schema_sql": schema_dir / "schema.sql",
        "schema_txt": schema_dir / "schema.txt",
    }

    with sqlite3.connect(db_path) as src, sqlite3.connect(backup_path) as dst:
        src.backup(dst)
        if dst.execute("PRAGMA integrity_check;").fetchone()[0] != "ok":
            backup_path.unlink(missing_ok=True)
            raise RuntimeError("Integrity check failed")
        counts = _row_counts(dst)
        ver_row = dst.execute(
            "SELECT value FROM Configuration WHERE key='db_version'"
        ).fetchone()
        db_version = ver_row[0] if ver_row else "unknown"

    schema_hashes: Dict[str, str] = {}
    for label, path in schema_files.items():
        if path.exists():
            data = path.read_bytes()
            schema_hashes[label] = hashlib.sha256(data).hexdigest()

    manifest = {
        "db_version": db_version,
        "row_counts": counts,
        "schema_hashes": schema_hashes,
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    return backup_path, counts


def restore_database(db_path: Path, backup_file: Path) -> Dict[str, Tuple[int, int]]:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    old_path = db_path.with_name(db_path.name + f".old.{ts}")

    with sqlite3.connect(db_path) as conn:
        pre_counts = _row_counts(conn)

    manifest_path = backup_file.with_suffix(".manifest.json")
    os.replace(db_path, old_path)
    try:
        shutil.copy2(backup_file, db_path)
        with sqlite3.connect(db_path) as conn:
            post_counts = _row_counts(conn)
            new_ver = conn.execute(
                "SELECT value FROM Configuration WHERE key='db_version'"
            ).fetchone()
            restored_version = new_ver[0] if new_ver else "unknown"
    except Exception:
        if old_path.exists():
            os.replace(old_path, db_path)
        raise

    if manifest_path.exists():
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        if manifest.get("db_version") != restored_version:
            print(
                "Warning: restored db_version" , restored_version,
                "differs from backup", manifest.get("db_version")
            )

    summary: Dict[str, Tuple[int, int]] = {}
    for tbl in sorted(set(pre_counts) | set(post_counts)):
        pre = pre_counts.get(tbl, 0)
        post = post_counts.get(tbl, 0)
        summary[tbl] = (pre, post)

    return summary


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Backup or restore dragonshield.sqlite")
    sub = parser.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("backup", help="Create a backup")
    b.add_argument("db", type=Path, help="Path to dragonshield.sqlite")
    b.add_argument("dest", type=Path, help="Directory for backup file")

    r = sub.add_parser("restore", help="Restore from a backup")
    r.add_argument("db", type=Path, help="Path to dragonshield.sqlite")
    r.add_argument("backup", type=Path, help="Backup file to restore")

    args = parser.parse_args(argv)

    if args.cmd == "backup":
        env = input("Environment label (prod/test): ").strip() or "prod"
        backup_path, counts = backup_database(args.db, args.dest, env)
        print("Backup Summary")
        print(f"{'Table':20}Rows")
        for tbl, cnt in counts.items():
            print(f"{tbl:20}{cnt}")
        print(f"Backup created at {backup_path}")
        return 0
    else:
        summary = restore_database(args.db, args.backup)
        print("Restore Summary")
        print(f"{'Table':20}{'Pre-Restore':12}{'Post-Restore':14}Delta")
        for tbl, (pre, post) in summary.items():
            delta = post - pre
            sign = '+' if delta >= 0 else ''
            print(f"{tbl:20}{pre:<12}{post:<14}{sign}{delta}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

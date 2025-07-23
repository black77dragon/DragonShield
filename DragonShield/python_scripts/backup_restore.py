#!/usr/bin/env python3
"""Backup and restore DragonShield SQLite database using SQLite's backup API."""

import argparse
import json
import os
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path

DEFAULT_DB_PATH = Path(__file__).resolve().parents[1] / "dragonshield.sqlite"


def user_tables(conn: sqlite3.Connection) -> list[str]:
    query = (
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    )
    return [row[0] for row in conn.execute(query)]


def table_counts(conn: sqlite3.Connection) -> dict[str, int]:
    counts = {}
    for table in user_tables(conn):
        counts[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    return counts


def integrity_ok(conn: sqlite3.Connection) -> bool:
    row = conn.execute("PRAGMA integrity_check").fetchone()
    return row is not None and row[0] == "ok"


def backup_database(db_path: Path, dest_dir: Path, env: str) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = dest_dir / f"{env}_backup_{timestamp}.sqlite"
    dest_dir.mkdir(parents=True, exist_ok=True)

    src = sqlite3.connect(db_path)
    dest = sqlite3.connect(backup_path)
    src.backup(dest)
    dest.commit()

    if not integrity_ok(dest):
        dest.close()
        src.close()
        backup_path.unlink(missing_ok=True)
        raise RuntimeError("Backup integrity check failed")

    counts = table_counts(dest)
    dest.close()
    src.close()

    manifest_path = backup_path.with_suffix(".manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({"environment": env, "timestamp": timestamp, "counts": counts}, f, indent=2)

    print("Backup Summary")
    print("Table               Rows")
    for table, cnt in counts.items():
        print(f"{table:20} {cnt}")

    return backup_path


def restore_database(backup_path: Path, db_path: Path) -> None:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    pre_conn = sqlite3.connect(db_path)
    pre_counts = table_counts(pre_conn)
    pre_conn.close()

    old_path = db_path.with_name(db_path.name + f".old.{timestamp}")
    os.replace(db_path, old_path)

    shutil.copy2(backup_path, db_path)

    post_conn = sqlite3.connect(db_path)
    if not integrity_ok(post_conn):
        post_conn.close()
        os.replace(old_path, db_path)
        raise RuntimeError("Restored database failed integrity check")

    post_counts = table_counts(post_conn)
    post_conn.close()

    print("Restore Summary")
    print("Table               Pre-Restore  Post-Restore  Delta")
    for table in sorted(set(pre_counts) | set(post_counts)):
        pre = pre_counts.get(table, 0)
        post = post_counts.get(table, 0)
        delta = post - pre
        print(f"{table:20} {pre:12} {post:13} {delta:+d}")

    manifest_path = backup_path.with_suffix(".restore.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({"timestamp": timestamp, "pre": pre_counts, "post": post_counts}, f, indent=2)

    old_path.unlink(missing_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Backup or restore DragonShield database")
    sub = parser.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("backup")
    b.add_argument("--db", default=str(DEFAULT_DB_PATH), help="Path to live database")
    b.add_argument("--dest", default=".", help="Directory to store backup")
    b.add_argument("--env", help="Environment label, e.g. prod or test")

    r = sub.add_parser("restore")
    r.add_argument("backup_file", help="Backup file to restore")
    r.add_argument("--db", default=str(DEFAULT_DB_PATH), help="Path to live database")

    args = parser.parse_args(argv)

    if args.cmd == "backup":
        env = args.env or input("Environment label (e.g. prod or test): ").strip() or "env"
        backup_database(Path(args.db), Path(args.dest), env)
        return 0
    else:
        restore_database(Path(args.backup_file), Path(args.db))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

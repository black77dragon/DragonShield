#!/usr/bin/env python3
"""Backup and restore DragonShield SQLite database with validation manifest."""
# python_scripts/db_backup_restore.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial implementation with manifest-based validation workflow.

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path


def list_tables(conn: sqlite3.Connection) -> list[str]:
    cursor = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
    )
    return [row[0] for row in cursor.fetchall()]


def table_metrics(conn: sqlite3.Connection, table: str) -> tuple[int, str]:
    cursor = conn.execute(f"SELECT * FROM {table} ORDER BY rowid")
    rows = cursor.fetchall()
    md5 = hashlib.md5()
    for row in rows:
        md5.update("|".join(str(v) for v in row).encode("utf-8"))
    return len(rows), md5.hexdigest()


def generate_manifest(conn: sqlite3.Connection) -> dict:
    manifest: dict[str, dict[str, object]] = {}
    for table in list_tables(conn):
        count, checksum = table_metrics(conn, table)
        manifest[table] = {"count": count, "checksum": checksum}
    return manifest


def write_manifest(manifest: dict, path: Path) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)


def load_manifest(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _normalize(path: Path) -> Path:
    """Expand user and resolve a path."""
    return path.expanduser().resolve()


def _ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def backup_database(db_path: Path, out_path: Path) -> Path:
    db_path = _normalize(db_path)
    out_path = _normalize(out_path)
    _ensure_parent(out_path)
    conn = sqlite3.connect(str(db_path))
    manifest = generate_manifest(conn)
    conn.close()
    shutil.copy2(db_path, out_path)
    manifest_path = out_path.with_suffix(out_path.suffix + ".manifest.json")
    write_manifest(manifest, manifest_path)
    print(f"✅ Backup created at {out_path}")
    return manifest_path


def compare_manifest(conn: sqlite3.Connection, manifest: dict) -> list[str]:
    failures = []
    for table, expected in manifest.items():
        count, checksum = table_metrics(conn, table)
        if count != expected["count"] or checksum != expected["checksum"]:
            failures.append(table)
    return failures


def restore_database(backup_file: Path, db_path: Path) -> int:
    backup_file = _normalize(backup_file)
    db_path = _normalize(db_path)
    _ensure_parent(db_path)

    manifest_file = backup_file.with_suffix(backup_file.suffix + ".manifest.json")
    if not manifest_file.exists():
        print("❌ Manifest file missing")
        return 1
    manifest = load_manifest(manifest_file)

    if db_path.exists():
        conn = sqlite3.connect(str(db_path))
        pre_fail = compare_manifest(conn, manifest)
        conn.close()
        if pre_fail:
            print("❌ Pre-restore validation failed:")
            for t in pre_fail:
                print(f"  {t} mismatch")
            return 1
        ts = datetime.now().strftime("%Y%m%d%H%M%S")
        backup_old = db_path.with_suffix(f".old.{ts}")
        shutil.move(str(db_path), str(backup_old))
    else:
        backup_old = None

    shutil.copy2(backup_file, db_path)

    conn = sqlite3.connect(str(db_path))
    post_fail = compare_manifest(conn, manifest)
    conn.close()

    if post_fail:
        print("❌ Post-restore validation failed:")
        for t in post_fail:
            print(f"  {t} mismatch")
        if backup_old and backup_old.exists():
            shutil.move(str(backup_old), str(db_path))
        return 1

    if backup_old and backup_old.exists():
        os.remove(backup_old)
    print("✅ Restore completed: all tables match")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Backup and restore DragonShield database")
    sub = parser.add_subparsers(dest="cmd")

    b = sub.add_parser("backup", help="Create backup")
    b.add_argument("db", type=Path, help="Path to SQLite database")
    b.add_argument("out", type=Path, help="Destination backup file")

    r = sub.add_parser("restore", help="Restore from backup")
    r.add_argument("db", type=Path, help="Target SQLite database file")
    r.add_argument("backup", type=Path, help="Backup file to restore from")

    args = parser.parse_args(argv)

    if args.cmd == "backup":
        backup_database(args.db, args.out)
        return 0
    elif args.cmd == "restore":
        return restore_database(args.backup, args.db)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

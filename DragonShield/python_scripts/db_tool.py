#!/usr/bin/env python3
"""Command line helper to build and deploy the DragonShield SQLite database.

This tool executes the schema.sql script to create all tables and then runs
schema.txt to populate them with initial data.  The resulting database file is
copied to the destination directory, which defaults to the production
container path used by the macOS app.
"""
# python_scripts/db_tool.py
# MARK: - Version 1.2
# MARK: - History
# - 1.1 -> 1.2: Added module description and validation of input files.
# - 1.0 -> 1.1: Updated default target directory to production container path.
# - 1.0: Initial creation. Build database from schema and seed data and deploy to target directory.

import argparse
import os
import shutil
from pathlib import Path
import sqlite3

DEFAULT_TARGET_DIR = (
    "/Users/renekeller/Library/Containers/"
    "com.rene.DragonShield/Data/Library/Application Support/DragonShield"
)

import deploy_db


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build and deploy Dragon Shield database")
    parser.add_argument(
        '--target-dir',
        default=DEFAULT_TARGET_DIR,
        help='Destination directory for dragonshield.sqlite'
    )
    parser.add_argument('--schema', default=str(Path(__file__).resolve().parents[1] / 'database' / 'schema.sql'),
                        help='Path to schema.sql')
    parser.add_argument('--seed', default=str(Path(__file__).resolve().parents[1] / 'database' / 'schema.txt'),
                        help='Path to schema.txt')
    args = parser.parse_args(argv)

    project_root = Path(__file__).resolve().parents[1]
    source_path = project_root / 'dragonshield.sqlite'

    if not Path(args.schema).exists():
        raise FileNotFoundError(f"Schema file not found: {args.schema}")
    if not Path(args.seed).exists():
        raise FileNotFoundError(f"Seed file not found: {args.seed}")

    version = deploy_db.parse_version(args.schema)
    table_count = deploy_db.build_database(args.schema, args.seed, str(source_path), version)

    conn = sqlite3.connect(source_path)
    try:
        seed_rows = conn.execute("SELECT count(*) FROM Currencies").fetchone()[0]
    finally:
        conn.close()

    dest_dir = Path(args.target_dir).expanduser()
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = dest_dir / 'dragonshield.sqlite'
    shutil.copy2(source_path, dest_path)

    print(
        f"✅ Built database v{version} with {table_count} tables "
        f"and {seed_rows} seed rows; deployed to {dest_path}"
    )


if __name__ == '__main__':
    main()

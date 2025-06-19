#!/usr/bin/env python3
# python_scripts/deploy_db.py
# MARK: - Version 1.2
# MARK: - History
# - 1.1 -> 1.2: Display detailed progress and final summary information.
# - 1.0 -> 1.1: Builds DB from schema, stores version, and deploys to app support.

import os
import shutil
import sqlite3
import re

def parse_version(sql_path: str) -> str:
    with open(sql_path, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.search(r'Version\s+([\d.]+)', line)
            if m:
                return m.group(1)
    return 'unknown'

def build_database(schema_sql: str, seed_sql: str, out_path: str, version: str) -> int:
    """Builds the SQLite DB from SQL scripts and returns number of user tables."""
    if os.path.exists(out_path):
        os.remove(out_path)
    print(f"🛠  Building database at {out_path} …")
    conn = sqlite3.connect(out_path)
    with open(schema_sql, 'r', encoding='utf-8') as f:
        conn.executescript(f.read())
    with open(seed_sql, 'r', encoding='utf-8') as f:
        conn.executescript(f.read())
    conn.execute(
        "INSERT OR REPLACE INTO Configuration (key, value, data_type, description) VALUES (?, ?, 'string', 'Database schema version');",
        ('db_version', version)
    )
    conn.commit()
    tables = conn.execute(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    ).fetchone()[0]
    conn.close()
    return tables

def main() -> None:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, '..'))
    source_path = os.path.join(project_root, 'dragonshield.sqlite')

    schema_sql = os.path.join(project_root, 'database', 'schema.sql')
    seed_sql = os.path.join(project_root, 'database', 'schema.txt')

    version = parse_version(schema_sql)
    confirm = input(f"Build database version {version}? [y/N]: ")
    if confirm.lower() != 'y':
        print('Aborted.')
        return

    table_count = build_database(schema_sql, seed_sql, source_path, version)
    size = os.path.getsize(source_path)
    print(f"✅ Created database at {source_path} (v{version}, {table_count} tables, {size} bytes)")

    dest_dir = os.path.expanduser(os.path.join('~', 'Library', 'Application Support', 'DragonShield'))
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, 'dragonshield.sqlite')
    shutil.copy2(source_path, dest_path)
    print(f"🚚 Deployed database to {dest_path}")

    print("\n===== Deployment Summary =====")
    print(f"Version: {version}")
    print(f"Source:  {source_path}")
    print(f"Target:  {dest_path}")
    print(f"Size:    {size} bytes")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# python_scripts/db_tool.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial creation. Build database from schema and seed data and deploy to target directory.

import argparse
import os
import shutil
from pathlib import Path

import deploy_db


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build and deploy Dragon Shield database")
    parser.add_argument('--target-dir', default=os.path.expanduser(os.path.join('~', 'Library', 'Application Support', 'DragonShield')),
                        help='Destination directory for dragonshield.sqlite')
    parser.add_argument('--schema', default=str(Path(__file__).resolve().parents[1] / 'database' / 'schema.sql'),
                        help='Path to schema.sql')
    parser.add_argument('--seed', default=str(Path(__file__).resolve().parents[1] / 'database' / 'schema.txt'),
                        help='Path to schema.txt')
    args = parser.parse_args(argv)

    project_root = Path(__file__).resolve().parents[1]
    source_path = project_root / 'dragonshield.sqlite'

    version = deploy_db.parse_version(args.schema)
    table_count = deploy_db.build_database(args.schema, args.seed, str(source_path), version)

    dest_dir = Path(args.target_dir).expanduser()
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = dest_dir / 'dragonshield.sqlite'
    shutil.copy2(source_path, dest_path)

    print(f"✅ Built database v{version} with {table_count} tables and deployed to {dest_path}")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Command line helper to build and deploy the DragonShield SQLite database.

This tool guides the user through three phases:

1. **Create an empty database** from ``schema.sql``.
2. **Load test seed data** from ``schema.txt``.
3. **Deploy** the resulting database to the production container path.

Each phase can be confirmed or skipped interactively. Status information is
logged using Python's ``logging`` module with a JSON formatter.
"""
# python_scripts/db_tool.py
# MARK: - Version 1.3
# MARK: - History
# - 1.2 -> 1.3: Added interactive phased workflow and structured logging.
# - 1.1 -> 1.2: Added module description and validation of input files.
# - 1.0 -> 1.1: Updated default target directory to production container path.
# - 1.0: Initial creation. Build database from schema and seed data and deploy to target directory.

import argparse
import json
import logging
import os
import shutil
import subprocess
from pathlib import Path
import sqlite3
import sys

DEFAULT_TARGET_DIR = (
    "/Users/renekeller/Library/Containers/"
    "com.rene.DragonShield/Data/Library/Application Support/DragonShield"
)

REFERENCE_TABLES = [
    "Configuration",
    "Currencies",
    "ExchangeRates",
    "FxRateUpdates",
    "AssetClasses",
    "AssetSubClasses",
    "TransactionTypes",
    "AccountTypes",
    "Institutions",
    "Instruments",
    "Accounts",
]

def default_ref_filename(mode: str, version: str) -> str:
    from datetime import datetime
    ts = datetime.now().strftime("%Y%m%d")
    return f"DragonShield_Reference_{mode}_v{version}_{ts}.sql"

import deploy_db


def _setup_logger() -> logging.Logger:
    logger = logging.getLogger("db_tool")
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger


def _confirm(prompt: str) -> bool:
    return input(f"{prompt} [y/N]: ").strip().lower() == "y"


def create_empty_db(schema_sql: str, out_path: str) -> int:
    if os.path.exists(out_path):
        os.remove(out_path)
    conn = sqlite3.connect(out_path)
    with open(schema_sql, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.commit()
    tables = conn.execute(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    ).fetchone()[0]
    conn.close()
    return tables


def load_seed_data(seed_sql: str, db_path: str, version: str) -> int:
    conn = sqlite3.connect(db_path)
    with open(seed_sql, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.execute(
        "INSERT OR REPLACE INTO Configuration (key, value, data_type, description) VALUES (?, ?, 'string', 'Database schema version');",
        ("db_version", version),
    )
    conn.commit()
    rows = conn.execute("SELECT count(*) FROM Currencies").fetchone()[0]
    conn.close()
    return rows


def backup_reference_data(db_path: str, out_path: str) -> None:
    cmd = ["/usr/bin/sqlite3", db_path, ".dump", *REFERENCE_TABLES]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(result.stdout)


def stop_apps() -> None:
    """Quit DragonShield and Xcode using osascript if available."""
    for app in ("DragonShield", "Xcode"):
        subprocess.run(
            ["osascript", "-e", f'tell application "{app}" to quit'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Build and deploy Dragon Shield database")
    parser.add_argument(
        "--target-dir",
        default=DEFAULT_TARGET_DIR,
        help="Destination directory for dragonshield.sqlite",
    )
    parser.add_argument(
        "--schema",
        default=str(Path(__file__).resolve().parents[1] / "database" / "schema.sql"),
        help="Path to schema.sql",
    )
    parser.add_argument(
        "--seed",
        default=str(Path(__file__).resolve().parents[1] / "database" / "schema.txt"),
        help="Path to schema.txt",
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument("--all", action="store_true", help="Run all steps")
    group.add_argument("--create-db", action="store_true", help="Create database only")
    group.add_argument(
        "--populate-test",
        action="store_true",
        help="Create database and load test data",
    )
    group.add_argument("--deploy-only", action="store_true", help="Deploy existing database only")

    parser.add_argument("-r", "--backup-ref", action="store_true", help="Backup reference tables and exit")

    args = parser.parse_args(argv)

    logger = _setup_logger()
    stop_apps()

    project_root = Path(__file__).resolve().parents[1]
    source_path = project_root / "dragonshield.sqlite"

    if not Path(args.schema).exists():
        raise FileNotFoundError(f"Schema file not found: {args.schema}")
    if not Path(args.seed).exists():
        raise FileNotFoundError(f"Seed file not found: {args.seed}")

    version = deploy_db.parse_version(args.schema)
    logger.info(json.dumps({"event": "start", "version": version}))

    if args.backup_ref:
        dest_dir = Path(args.target_dir).expanduser()
        os.makedirs(dest_dir, exist_ok=True)
        db_path = dest_dir / "dragonshield.sqlite"
        mode = "PROD"
        if not db_path.exists():
            db_path = dest_dir / "dragonshield_test.sqlite"
            mode = "TEST"
        out_path = dest_dir / default_ref_filename(mode, version)
        try:
            backup_reference_data(str(db_path), str(out_path))
        except Exception as exc:
            logger.error(json.dumps({"error": str(exc)}))
            return 1
        print(str(out_path))
        return 0

    # Determine execution mode
    interactive = False
    if not any([args.all, args.create_db, args.populate_test, args.deploy_only]):
        if sys.stdin.isatty():
            interactive = True
        else:
            args.all = True

    success = True

    try:
        if interactive:
            if _confirm("Phase 1: create a new empty database"):
                logger.info(json.dumps({"phase": 1, "status": "start"}))
                table_count = create_empty_db(args.schema, str(source_path))
                logger.info(json.dumps({"phase": 1, "status": "done", "tables": table_count}))
            else:
                logger.info(json.dumps({"phase": 1, "status": "skipped"}))

            if _confirm("Phase 2: load fresh set of test data"):
                logger.info(json.dumps({"phase": 2, "status": "start"}))
                seed_rows = load_seed_data(args.seed, str(source_path), version)
                logger.info(json.dumps({"phase": 2, "status": "done", "rows": seed_rows}))
            else:
                logger.info(json.dumps({"phase": 2, "status": "skipped"}))

            if _confirm("Phase 3: deploy the database to the Production Location"):
                logger.info(json.dumps({"phase": 3, "status": "start"}))
                dest_dir = Path(args.target_dir).expanduser()
                os.makedirs(dest_dir, exist_ok=True)
                for item in dest_dir.iterdir():
                    if item.is_file():
                        item.unlink()
                dest_path = dest_dir / "dragonshield.sqlite"
                shutil.copy2(source_path, dest_path)
                logger.info(json.dumps({"phase": 3, "status": "done", "dest": str(dest_path)}))
            else:
                logger.info(json.dumps({"phase": 3, "status": "skipped"}))
        else:
            # Non-interactive execution based on flags
            if args.all or args.create_db or args.populate_test:
                logger.info(json.dumps({"phase": 1, "status": "start"}))
                table_count = create_empty_db(args.schema, str(source_path))
                logger.info(json.dumps({"phase": 1, "status": "done", "tables": table_count}))

            if args.all or args.populate_test:
                logger.info(json.dumps({"phase": 2, "status": "start"}))
                seed_rows = load_seed_data(args.seed, str(source_path), version)
                logger.info(json.dumps({"phase": 2, "status": "done", "rows": seed_rows}))

            if args.all or args.deploy_only or args.populate_test:
                logger.info(json.dumps({"phase": 3, "status": "start"}))
                dest_dir = Path(args.target_dir).expanduser()
                os.makedirs(dest_dir, exist_ok=True)
                for item in dest_dir.iterdir():
                    if item.is_file():
                        item.unlink()
                dest_path = dest_dir / "dragonshield.sqlite"
                shutil.copy2(source_path, dest_path)
                logger.info(json.dumps({"phase": 3, "status": "done", "dest": str(dest_path)}))
    except Exception as exc:  # pragma: no cover - unforeseen errors
        logger.error(json.dumps({"error": str(exc)}))
        success = False

    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())

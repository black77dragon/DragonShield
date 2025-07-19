#!/usr/bin/env python3
"""Generate a full Instruments report in XLSX format."""
# python_scripts/generate_instrument_report.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial implementation that builds an in-memory DB from schema files
#   and exports the Instruments table to XLSX.

import sqlite3
from pathlib import Path
import argparse
import pandas as pd


def build_temp_db(schema_sql: Path, seed_sql: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    with open(schema_sql, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    with open(seed_sql, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    return conn


def generate_report(output_path: Path) -> None:
    script_dir = Path(__file__).resolve().parents[1]
    schema_sql = script_dir / "database" / "schema.sql"
    seed_sql = script_dir / "database" / "schema.txt"

    conn = build_temp_db(schema_sql, seed_sql)
    df = pd.read_sql_query("SELECT * FROM Instruments", conn)
    df.to_excel(output_path, index=False)
    conn.close()
    print(f"✅ Created instrument report at {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a full Instruments report in XLSX format"
    )
    parser.add_argument(
        "output",
        nargs="?",
        default="instrument_report.xlsx",
        help="Path to output XLSX file"
    )
    args = parser.parse_args()
    generate_report(Path(args.output))

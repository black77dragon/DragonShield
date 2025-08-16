#!/usr/bin/env python3
"""Generate a full Instruments report in XLSX format."""
# python_scripts/generate_instrument_report.py
# MARK: - Version 1.1
# MARK: - History
# - 1.1: Resolve path lookup and seed parsing without sqlite dependency.
# - 1.0: Initial implementation building an in-memory DB from schema files and exporting via pandas.

import argparse
import csv
import sys
from pathlib import Path

# Ensure we import the real pandas package even if a local stub exists
script_dir = Path(__file__).resolve().parent
if str(script_dir) in sys.path:
    sys.path.remove(str(script_dir))
import pandas as pd  # type: ignore
sys.path.insert(0, str(script_dir))

COLUMNS = [
    "instrument_id",
    "isin",
    "valor_nr",
    "ticker_symbol",
    "instrument_name",
    "sub_class_id",
    "currency",
    "country_code",
    "exchange_code",
    "sector",
    "include_in_portfolio",
    "is_active",
    "notes",
    "created_at",
    "updated_at",
]

def load_instruments(seed_sql: Path) -> pd.DataFrame:
    rows = []
    with open(seed_sql, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("INSERT INTO Instruments"):
                values_str = line.split("VALUES", 1)[1].strip().lstrip("(").rstrip(");")
                reader = csv.reader([values_str], skipinitialspace=True, quotechar="'")
                row = next(reader)
                rows.append(row[:len(COLUMNS)])
    return pd.DataFrame(rows, columns=COLUMNS)

def generate_report(output_path: Path) -> None:
    project_root = Path(__file__).resolve().parents[1]
    seed_sql = project_root / "db" / "schema.txt"
    df = load_instruments(seed_sql)
    df.to_excel(output_path, index=False)
    print(f"✅ Created instrument report at {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a full Instruments report in XLSX format"
    )
    parser.add_argument(
        "output",
        nargs="?",
        default="instrument_report.xlsx",
        help="Path to output XLSX file",
    )
    args = parser.parse_args()
    generate_report(Path(args.output))

#!/usr/bin/env python3
"""Reset database contents and import data from a legacy database file.

The target database keeps its current schema. All rows are deleted from
every table and then re-populated with the data taken from a legacy
database. New tables that did not exist in the legacy file remain and
are populated by running the migration logic for the former
``TargetAllocation`` table.
"""
import argparse
import sqlite3
from pathlib import Path
from typing import Dict, Iterable

def _row_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table';")
    counts = {}
    for (tbl,) in cur.fetchall():
        cur2 = conn.execute(f'SELECT COUNT(*) FROM "{tbl}";')
        counts[tbl] = cur2.fetchone()[0]
    return counts

def _table_names(conn: sqlite3.Connection, schema: str = "main") -> Iterable[str]:
    cur = conn.execute(
        f"SELECT name FROM {schema}.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    )
    return [name for (name,) in cur.fetchall()]


def load_legacy_database(target: Path, legacy: Path) -> Dict[str, int]:
    """Load data from ``legacy`` into ``target`` preserving the target schema."""
    with sqlite3.connect(target) as conn:
        conn.execute("PRAGMA foreign_keys=OFF")
        conn.execute("ATTACH DATABASE ? AS legacy", (str(legacy),))

        # Remove existing rows from all tables in the target database
        main_tables = _table_names(conn)
        for tbl in main_tables:
            conn.execute(f'DELETE FROM "{tbl}";')
            conn.execute("DELETE FROM sqlite_sequence WHERE name=?", (tbl,))

        # Copy tables from legacy database
        legacy_tables = _table_names(conn, "legacy")
        for tbl in legacy_tables:
            if tbl in main_tables:
                # Align columns between schemas. Use only columns that exist in
                # both tables to avoid mismatches when schemas differ.
                main_cols = [row[1] for row in conn.execute(f'PRAGMA main.table_info("{tbl}")')]
                legacy_cols = [row[1] for row in conn.execute(f'PRAGMA legacy.table_info("{tbl}")')]
                common = [col for col in legacy_cols if col in main_cols]
                if not common:
                    continue
                col_csv = ", ".join(f'"{c}"' for c in common)
                conn.execute(
                    f'INSERT INTO "{tbl}" ({col_csv}) SELECT {col_csv} FROM legacy."{tbl}";'
                )
            else:
                create_sql = conn.execute(
                    "SELECT sql FROM legacy.sqlite_master WHERE type='table' AND name=?", (tbl,)
                ).fetchone()[0]
                conn.execute(create_sql)
                conn.execute(f'INSERT INTO "{tbl}" SELECT * FROM legacy."{tbl}";')

        # Backfill ClassTargets and SubClassTargets from TargetAllocation data
        if "TargetAllocation" in legacy_tables:
            conn.executescript(
                """
                INSERT INTO ClassTargets (asset_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
                SELECT asset_class_id,
                       CASE WHEN target_kind IS NOT NULL THEN target_kind
                            WHEN target_percent IS NOT NULL THEN 'percent'
                            ELSE 'amount' END,
                       COALESCE(target_percent,0),
                       COALESCE(target_amount_chf,0),
                       COALESCE(tolerance_percent,0),
                       COALESCE(created_at,CURRENT_TIMESTAMP),
                       COALESCE(updated_at,CURRENT_TIMESTAMP)
                FROM TargetAllocation
                WHERE sub_class_id IS NULL;

                INSERT INTO TargetChangeLog (target_type, target_id, field_name, old_value, new_value, changed_by)
                SELECT 'class', id, 'migration', NULL, 'backfill', 'script'
                FROM ClassTargets;

                INSERT INTO SubClassTargets (class_target_id, asset_sub_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
                SELECT ct.id, ta.sub_class_id,
                       CASE WHEN ta.target_kind IS NOT NULL THEN ta.target_kind
                            WHEN ta.target_percent IS NOT NULL THEN 'percent'
                            ELSE 'amount' END,
                       COALESCE(ta.target_percent,0),
                       COALESCE(ta.target_amount_chf,0),
                       COALESCE(ta.tolerance_percent,0),
                       COALESCE(ta.created_at,CURRENT_TIMESTAMP),
                       COALESCE(ta.updated_at,CURRENT_TIMESTAMP)
                FROM TargetAllocation ta
                JOIN ClassTargets ct ON ct.asset_class_id = ta.asset_class_id
                WHERE ta.sub_class_id IS NOT NULL;

                INSERT INTO TargetChangeLog (target_type, target_id, field_name, old_value, new_value, changed_by)
                SELECT 'subclass', id, 'migration', NULL, 'backfill', 'script'
                FROM SubClassTargets;

                DROP TABLE TargetAllocation;
                """
            )

        # Ensure the database version matches the current schema
        conn.execute("UPDATE Configuration SET value=? WHERE key='db_version'", ("4.20",))
        conn.commit()
        conn.execute("DETACH DATABASE legacy")
        check = conn.execute("PRAGMA integrity_check;").fetchone()[0]
        if check != "ok":
            raise RuntimeError("Integrity check failed after import")
        counts = _row_counts(conn)
    return counts

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Empty a database and load data from a legacy version"
    )
    parser.add_argument("target", type=Path, help="Path to dragonshield.sqlite to overwrite")
    parser.add_argument("legacy", type=Path, help="Path to legacy dragonshield.sqlite")
    args = parser.parse_args(argv)

    counts = load_legacy_database(args.target, args.legacy)
    print("Import Summary")
    print(f"{'Table':20}Rows")
    for tbl, cnt in counts.items():
        print(f"{tbl:20}{cnt}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

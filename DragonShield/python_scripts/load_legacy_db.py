#!/usr/bin/env python3
"""Load data from a legacy database into a fresh schema without dropping tables."""

import argparse
import sqlite3
from pathlib import Path
from typing import Dict


def _row_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    cur = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    )
    counts: Dict[str, int] = {}
    for (tbl,) in cur.fetchall():
        cur2 = conn.execute(f'SELECT COUNT(*) FROM "{tbl}";')
        counts[tbl] = cur2.fetchone()[0]
    return counts


def load_legacy_database(target: Path, legacy: Path) -> Dict[str, int]:
    """Copy data from ``legacy`` into ``target`` while preserving the target schema."""
    with sqlite3.connect(target) as conn:
        conn.execute("PRAGMA foreign_keys=OFF;")
        conn.execute("ATTACH DATABASE ? AS legacy", (str(legacy),))

        # Remove existing rows from all tables except Configuration
        tables = [
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
            )
        ]
        for tbl in tables:
            if tbl == "Configuration":
                continue
            conn.execute(f'DELETE FROM "{tbl}";')

        # Copy tables that exist unchanged in the legacy database
        skip_new = {"ClassTargets", "SubClassTargets", "TargetChangeLog"}
        for tbl in tables:
            if tbl == "Configuration" or tbl in skip_new:
                continue
            legacy_has = conn.execute(
                "SELECT name FROM legacy.sqlite_master WHERE type='table' AND name=?;",
                (tbl,),
            ).fetchone()
            if legacy_has:
                conn.execute(f'INSERT INTO "{tbl}" SELECT * FROM legacy."{tbl}";')

        # Populate new hierarchical target tables from legacy TargetAllocation
        conn.executescript(
            """
            INSERT INTO ClassTargets (
                asset_class_id, target_kind, target_percent, target_amount_chf,
                tolerance_percent, created_at, updated_at
            )
            SELECT
                asset_class_id,
                CASE
                    WHEN target_kind IS NOT NULL THEN target_kind
                    WHEN target_percent IS NOT NULL THEN 'percent'
                    ELSE 'amount'
                END,
                COALESCE(target_percent,0),
                COALESCE(target_amount_chf,0),
                COALESCE(tolerance_percent,0),
                COALESCE(created_at,CURRENT_TIMESTAMP),
                COALESCE(updated_at,CURRENT_TIMESTAMP)
            FROM legacy.TargetAllocation
            WHERE sub_class_id IS NULL;

            INSERT INTO SubClassTargets (
                class_target_id, asset_sub_class_id, target_kind, target_percent,
                target_amount_chf, tolerance_percent, created_at, updated_at
            )
            SELECT
                ct.id,
                ta.sub_class_id,
                CASE
                    WHEN ta.target_kind IS NOT NULL THEN ta.target_kind
                    WHEN ta.target_percent IS NOT NULL THEN 'percent'
                    ELSE 'amount'
                END,
                COALESCE(ta.target_percent,0),
                COALESCE(ta.target_amount_chf,0),
                COALESCE(ta.tolerance_percent,0),
                COALESCE(ta.created_at,CURRENT_TIMESTAMP),
                COALESCE(ta.updated_at,CURRENT_TIMESTAMP)
            FROM legacy.TargetAllocation ta
            JOIN ClassTargets ct ON ct.asset_class_id = ta.asset_class_id
            WHERE ta.sub_class_id IS NOT NULL;

            INSERT INTO TargetChangeLog (
                target_type, target_id, field_name, old_value, new_value, changed_by
            )
            SELECT 'class', id, 'migration', NULL, 'backfill', 'script' FROM ClassTargets;
            INSERT INTO TargetChangeLog (
                target_type, target_id, field_name, old_value, new_value, changed_by
            )
            SELECT 'subclass', id, 'migration', NULL, 'backfill', 'script'
            FROM SubClassTargets;
            """
        )

        conn.execute("PRAGMA foreign_keys=ON;")
        conn.commit()
        counts = _row_counts(conn)
        conn.execute("DETACH DATABASE legacy")
    return counts


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Empty a database and load data from a legacy version",
    )
    parser.add_argument(
        "target", type=Path, help="Path to dragonshield.sqlite to populate"
    )
    parser.add_argument(
        "legacy", type=Path, help="Path to legacy dragonshield.sqlite"
    )
    args = parser.parse_args(argv)

    counts = load_legacy_database(args.target, args.legacy)
    print("Import Summary")
    print(f"{'Table':20}Rows")
    for tbl, cnt in counts.items():
        print(f"{tbl:20}{cnt}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

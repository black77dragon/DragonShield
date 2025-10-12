import sqlite3
from pathlib import Path

SCHEMA = Path(__file__).resolve().parents[1] / 'DragonShield' / 'database' / 'schema.sql'


def load_db():
    conn = sqlite3.connect(':memory:')
    with open(SCHEMA, 'r', encoding='utf-8') as f:
        conn.executescript(f.read())
    # seed minimal asset classes/subclasses for FK references
    conn.execute("INSERT INTO AssetClasses (class_code, class_name) VALUES ('A','A')")
    conn.execute("INSERT INTO AssetClasses (class_code, class_name) VALUES ('B','B')")
    conn.execute("INSERT INTO AssetSubClasses (class_id, sub_class_code, sub_class_name) VALUES (1,'S1','S1')")
    conn.execute("INSERT INTO AssetSubClasses (class_id, sub_class_code, sub_class_name) VALUES (1,'S2','S2')")
    return conn


def test_parent_sum_trigger():
    conn = load_db()
    # Insert class targets totaling 90%
    conn.execute("INSERT INTO ClassTargets (asset_class_id, target_kind, target_percent, tolerance_percent) VALUES (1,'percent',60,5)")
    conn.execute("INSERT INTO ClassTargets (asset_class_id, target_kind, target_percent, tolerance_percent) VALUES (2,'percent',30,5)")
    row = conn.execute("SELECT new_value FROM TargetChangeLog WHERE field_name='parent_sum_percent'").fetchone()
    assert row is not None
    conn.close()


def test_child_sum_trigger():
    conn = load_db()
    # Parent class target 100%
    conn.execute("INSERT INTO ClassTargets (asset_class_id, target_kind, target_percent, tolerance_percent) VALUES (1,'percent',100,5)")
    # Sub targets totaling 70%
    conn.execute("INSERT INTO SubClassTargets (class_target_id, asset_sub_class_id, target_kind, target_percent, tolerance_percent) VALUES (1,1,'percent',40,5)")
    conn.execute("INSERT INTO SubClassTargets (class_target_id, asset_sub_class_id, target_kind, target_percent, tolerance_percent) VALUES (1,2,'percent',30,5)")
    row = conn.execute("SELECT new_value FROM TargetChangeLog WHERE field_name='child_sum_percent'").fetchone()
    assert row is not None
    conn.close()

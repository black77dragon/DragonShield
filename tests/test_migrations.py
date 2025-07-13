import sqlite3
import os
from pathlib import Path

# Set up path to migrations directory
MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / 'migrations'

# Helper to read SQL file
def read_sql(filename):
    with open(MIGRATIONS_DIR / filename, 'r', encoding='utf-8') as f:
        return f.read()


def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        """
        CREATE TABLE Accounts (
            account_id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_number TEXT UNIQUE,
            account_name TEXT NOT NULL,
            institution_id INTEGER NOT NULL,
            account_type_id INTEGER NOT NULL,
            currency_code TEXT NOT NULL,
            is_active BOOLEAN DEFAULT 1,
            include_in_portfolio BOOLEAN DEFAULT 1,
            opening_date DATE,
            closing_date DATE,
            notes TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE PositionReports (
            position_id INTEGER PRIMARY KEY AUTOINCREMENT,
            import_session_id INTEGER,
            account_id INTEGER NOT NULL,
            institution_id INTEGER NOT NULL,
            instrument_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            purchase_price REAL,
            current_price REAL,
            notes TEXT,
            report_date DATE NOT NULL,
            uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    return conn


def test_apply_migrations_and_insert_dates():
    conn = setup_db()

    # Apply first migration
    conn.executescript(read_sql('001_add_instrument_updated_at.sql'))
    cols = [row[1] for row in conn.execute("PRAGMA table_info(PositionReports)")]
    assert 'instrument_updated_at' in cols

    # Insert row with instrument_updated_at
    conn.execute(
        "INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, report_date, instrument_updated_at) VALUES (1, 1, 1, 10, '2025-01-01', '2025-06-01')"
    )
    val = conn.execute(
        "SELECT instrument_updated_at FROM PositionReports"
    ).fetchone()[0]
    assert val == '2025-06-01'

    # Apply second migration
    conn.executescript(read_sql('002_add_earliest_instrument_last_updated_at.sql'))
    cols = [row[1] for row in conn.execute("PRAGMA table_info(Accounts)")]
    assert 'earliest_instrument_last_updated_at' in cols

    conn.execute(
        "INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code, earliest_instrument_last_updated_at) VALUES ('a', 1, 1, 'CHF', '2025-06-01')"
    )
    val = conn.execute(
        "SELECT earliest_instrument_last_updated_at FROM Accounts"
    ).fetchone()[0]
    assert val == '2025-06-01'

    conn.close()

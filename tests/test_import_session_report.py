import sys
import sqlite3
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import import_session_report as report


def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        """
        CREATE TABLE ImportSessions (
            import_session_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_name TEXT,
            processing_notes TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE Instruments (
            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
            instrument_name TEXT,
            currency TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE ExchangeRates (
            currency_code TEXT,
            rate_date TEXT,
            rate_to_chf REAL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE PositionReports (
            position_id INTEGER PRIMARY KEY AUTOINCREMENT,
            import_session_id INTEGER,
            account_id INTEGER,
            institution_id INTEGER,
            instrument_id INTEGER,
            quantity REAL,
            current_price REAL,
            report_date TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE ImportSessionValues (
            value_id INTEGER PRIMARY KEY AUTOINCREMENT,
            import_session_id INTEGER,
            instrument_name TEXT,
            currency TEXT,
            value_original REAL,
            value_chf REAL
        )
        """
    )
    return conn


def test_summary_and_save():
    conn = setup_db()
    conn.execute("INSERT INTO ImportSessions (session_name) VALUES ('test')")
    conn.execute("INSERT INTO Instruments (instrument_name, currency) VALUES ('A', 'USD')")
    conn.execute("INSERT INTO Instruments (instrument_name, currency) VALUES ('B', 'CHF')")
    conn.execute("INSERT INTO ExchangeRates VALUES ('USD','2025-01-01',0.9)")
    conn.execute(
        "INSERT INTO PositionReports (import_session_id, account_id, institution_id, instrument_id, quantity, current_price, report_date) VALUES (1,1,1,1,10,5,'2025-01-01')"
    )
    conn.execute(
        "INSERT INTO PositionReports (import_session_id, account_id, institution_id, instrument_id, quantity, current_price, report_date) VALUES (1,1,1,2,20,2,'2025-01-01')"
    )
    conn.commit()

    positions = report.fetch_positions(conn, 1)
    summary = report.summarize_positions(conn, positions)
    assert round(summary['total_chf'], 2) == 85.0
    assert summary['breakdown']['USD'] == 45.0
    assert summary['breakdown']['CHF'] == 40.0

    report.save_total(conn, 1, summary['total_chf'])
    report.save_items(conn, 1, summary['positions'])
    note = conn.execute('SELECT processing_notes FROM ImportSessions WHERE import_session_id=1').fetchone()[0]
    assert 'total_value_chf=85.00' == note
    count = conn.execute('SELECT COUNT(*) FROM ImportSessionValues').fetchone()[0]
    assert count == 2
    conn.close()

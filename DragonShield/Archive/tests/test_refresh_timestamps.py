import sqlite3


def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        """
        CREATE TABLE Accounts (
            account_id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_name TEXT,
            institution_id INTEGER,
            account_type_id INTEGER,
            currency_code TEXT,
            earliest_instrument_last_updated_at DATE
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE PositionReports (
            position_id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER,
            institution_id INTEGER,
            instrument_id INTEGER,
            quantity REAL,
            instrument_updated_at DATE,
            report_date DATE
        )
        """
    )
    return conn


def refresh(conn):
    conn.execute(
        """
        UPDATE Accounts
           SET earliest_instrument_last_updated_at = (
                SELECT MIN(instrument_updated_at)
                  FROM PositionReports pr
                 WHERE pr.account_id = Accounts.account_id
           );
        """
    )


def test_refresh_min_date():
    conn = setup_db()
    conn.execute("INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code) VALUES ('A',1,1,'CHF')")
    acc_id = conn.execute("SELECT account_id FROM Accounts WHERE account_name='A'").fetchone()[0]
    conn.execute("INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, instrument_updated_at, report_date) VALUES (?,1,1,10,'2025-05-01','2025-01-01')", (acc_id,))
    conn.execute("INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, instrument_updated_at, report_date) VALUES (?,1,1,20,'2025-04-15','2025-01-02')", (acc_id,))
    refresh(conn)
    val = conn.execute("SELECT earliest_instrument_last_updated_at FROM Accounts WHERE account_id=?", (acc_id,)).fetchone()[0]
    assert val == '2025-04-15'
    conn.close()


def test_refresh_null_when_no_reports():
    conn = setup_db()
    conn.execute("INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code) VALUES ('A',1,1,'CHF')")
    refresh(conn)
    val = conn.execute("SELECT earliest_instrument_last_updated_at FROM Accounts").fetchone()[0]
    assert val is None
    conn.close()

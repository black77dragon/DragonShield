import sqlite3


def setup_db():
    conn = sqlite3.connect(":memory:")
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
    conn.executescript(
        """
        CREATE TRIGGER tr_touch_account_last_updated
        AFTER INSERT ON PositionReports
        WHEN NEW.account_id IS NOT NULL
        BEGIN
            UPDATE Accounts
            SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
            WHERE account_id = NEW.account_id;
        END;

        CREATE TRIGGER tr_touch_account_last_updated_update
        AFTER UPDATE ON PositionReports
        WHEN NEW.account_id IS NOT NULL
        BEGIN
            UPDATE Accounts
            SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
            WHERE account_id = NEW.account_id;
        END;
        """
    )
    return conn


def test_trigger_updates_timestamp_on_insert():
    conn = setup_db()
    conn.execute(
        "INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code, earliest_instrument_last_updated_at) VALUES ('A',1,1,'CHF','2000-01-01 00:00:00')"
    )
    acc_id = conn.execute("SELECT account_id FROM Accounts WHERE account_name='A'").fetchone()[0]
    conn.execute(
        "INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, instrument_updated_at, report_date) VALUES (?,1,1,10,'2025-05-01','2025-01-01')",
        (acc_id,),
    )
    val = conn.execute(
        "SELECT earliest_instrument_last_updated_at FROM Accounts WHERE account_id=?",
        (acc_id,),
    ).fetchone()[0]
    assert val != "2000-01-01 00:00:00"
    conn.close()


def test_trigger_updates_timestamp_on_update():
    conn = setup_db()
    conn.execute(
        "INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code) VALUES ('A',1,1,'CHF')"
    )
    acc_id = conn.execute("SELECT account_id FROM Accounts WHERE account_name='A'").fetchone()[0]
    pos_id = conn.execute(
        "INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, instrument_updated_at, report_date) VALUES (?,1,1,10,'2025-05-01','2025-01-01')",
        (acc_id,),
    ).lastrowid
    conn.execute(
        "UPDATE Accounts SET earliest_instrument_last_updated_at='2000-01-01 00:00:00' WHERE account_id=?",
        (acc_id,),
    )
    conn.execute(
        "UPDATE PositionReports SET quantity=20 WHERE position_id=?",
        (pos_id,),
    )
    val = conn.execute(
        "SELECT earliest_instrument_last_updated_at FROM Accounts WHERE account_id=?",
        (acc_id,),
    ).fetchone()[0]
    assert val != "2000-01-01 00:00:00"
    conn.close()

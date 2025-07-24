import sqlite3
import time


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
            earliest_instrument_last_updated_at DATETIME
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


def test_insert_updates_timestamp():
    conn = setup_db()
    conn.execute(
        "INSERT INTO Accounts (account_name, institution_id, account_type_id, currency_code) VALUES ('A',1,1,'CHF')"
    )
    acc_id = conn.execute(
        "SELECT account_id FROM Accounts WHERE account_name='A'"
    ).fetchone()[0]
    conn.execute(
        "INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, report_date) VALUES (?,1,1,10,'2025-01-01')",
        (acc_id,),
    )
    val1 = conn.execute(
        "SELECT earliest_instrument_last_updated_at FROM Accounts WHERE account_id=?",
        (acc_id,),
    ).fetchone()[0]
    assert val1 is not None
    time.sleep(1)
    conn.execute(
        "INSERT INTO PositionReports (account_id, institution_id, instrument_id, quantity, report_date) VALUES (?,1,1,11,'2025-01-02')",
        (acc_id,),
    )
    val2 = conn.execute(
        "SELECT earliest_instrument_last_updated_at FROM Accounts WHERE account_id=?",
        (acc_id,),
    ).fetchone()[0]
    assert val2 > val1
    conn.close()

import sqlite3

# query replicating DatabaseManager.deletePositionReports(institutionId:)
DELETE_QUERY = """
    DELETE FROM PositionReports
          WHERE institution_id = ?
             OR account_id IN (
                    SELECT account_id FROM Accounts
                     WHERE institution_id = ?
             );
"""

def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute("CREATE TABLE Institutions (institution_id INTEGER PRIMARY KEY, institution_name TEXT)")
    conn.execute("CREATE TABLE Accounts (account_id INTEGER PRIMARY KEY, account_number TEXT, institution_id INTEGER)")
    conn.execute("""
        CREATE TABLE PositionReports (
            position_id INTEGER PRIMARY KEY,
            account_id INTEGER NOT NULL,
            institution_id INTEGER NOT NULL,
            instrument_id INTEGER,
            quantity REAL,
            report_date TEXT
        )
    """)
    # Insert institutions
    conn.execute("INSERT INTO Institutions VALUES (1, 'ZKB')")
    conn.execute("INSERT INTO Institutions VALUES (2, 'OtherBank')")
    # Insert accounts
    conn.execute("INSERT INTO Accounts VALUES (1, 'ZKB-ACC', 1)")
    conn.execute("INSERT INTO Accounts VALUES (2, 'OTHER-ACC', 2)")
    # Insert position reports - some with correct institution_id, some with wrong
    conn.execute("INSERT INTO PositionReports VALUES (1, 1, 1, 1, 10, '2024-01-01')")
    conn.execute("INSERT INTO PositionReports VALUES (2, 1, 99, 1, 20, '2024-01-01')")
    conn.execute("INSERT INTO PositionReports VALUES (3, 2, 2, 1, 30, '2024-01-01')")
    return conn

def test_delete_by_institution():
    conn = setup_db()
    cur = conn.execute('SELECT count(*) FROM PositionReports')
    assert cur.fetchone()[0] == 3
    deleted = conn.execute(DELETE_QUERY, (1, 1)).rowcount
    assert deleted == 2
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert remaining == [(2,)]
    conn.close()


def test_delete_query_with_missing_param():
    conn = setup_db()
    cur = conn.execute('SELECT count(*) FROM PositionReports')
    assert cur.fetchone()[0] == 3
    # Simulate Swift bug where second bind parameter is left null
    deleted = conn.execute(DELETE_QUERY, (1, None)).rowcount
    # Only rows matching institution_id are removed
    assert deleted == 1
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert set(remaining) == {(1,), (2,)}
    conn.close()

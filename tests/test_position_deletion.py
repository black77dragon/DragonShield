import sqlite3

# build query replicating DatabaseManager.deletePositionReports(institutionIds:)
def build_delete_query(count):
    placeholders = ', '.join(['?'] * count)
    return f"""
        DELETE FROM PositionReports
              WHERE institution_id IN ({placeholders})
                 OR account_id IN (
                        SELECT account_id FROM Accounts
                         WHERE institution_id IN ({placeholders})
              );
    """

def build_delete_with_types_query(inst_count, type_count):
    inst_ph = ', '.join(['?'] * inst_count)
    type_ph = ', '.join(['?'] * type_count)
    return f"""
        DELETE FROM PositionReports
              WHERE (institution_id IN ({inst_ph})
                     OR account_id IN (
                            SELECT account_id FROM Accounts WHERE institution_id IN ({inst_ph})
                  ))
                AND account_id IN (
                        SELECT account_id FROM Accounts WHERE account_type_id IN ({type_ph})
                );
    """

def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute("CREATE TABLE Institutions (institution_id INTEGER PRIMARY KEY, institution_name TEXT)")
    conn.execute(
        "CREATE TABLE AccountTypes (account_type_id INTEGER PRIMARY KEY, type_code TEXT)"
    )
    conn.execute(
        "CREATE TABLE Accounts (account_id INTEGER PRIMARY KEY, account_number TEXT, institution_id INTEGER, account_type_id INTEGER)"
    )
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
    conn.execute("INSERT INTO Institutions VALUES (1, 'Credit-Suisse')")
    conn.execute("INSERT INTO Institutions VALUES (2, 'OtherBank')")
    conn.execute("INSERT INTO AccountTypes VALUES (1, 'BANK')")
    conn.execute("INSERT INTO AccountTypes VALUES (2, 'CUSTODY')")
    # Insert accounts
    conn.execute("INSERT INTO Accounts VALUES (1, 'Credit-Suisse-ACC', 1, 1)")
    conn.execute("INSERT INTO Accounts VALUES (2, 'OTHER-ACC', 2, 2)")
    # Insert position reports - some with correct institution_id, some with wrong
    conn.execute("INSERT INTO PositionReports VALUES (1, 1, 1, 1, 10, '2024-01-01')")
    conn.execute("INSERT INTO PositionReports VALUES (2, 1, 99, 1, 20, '2024-01-01')")
    conn.execute("INSERT INTO PositionReports VALUES (3, 2, 2, 1, 30, '2024-01-01')")
    return conn

def test_delete_by_institution():
    conn = setup_db()
    cur = conn.execute('SELECT count(*) FROM PositionReports')
    assert cur.fetchone()[0] == 3
    query = build_delete_query(1)
    deleted = conn.execute(query, (1, 1)).rowcount
    assert deleted == 2
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert remaining == [(2,)]
    conn.close()


def test_delete_query_with_missing_param():
    conn = setup_db()
    cur = conn.execute('SELECT count(*) FROM PositionReports')
    assert cur.fetchone()[0] == 3
    # Simulate Swift bug where second bind parameter is left null
    query = build_delete_query(1)
    deleted = conn.execute(query, (1, None)).rowcount
    # Only rows matching institution_id are removed
    assert deleted == 1
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert set(remaining) == {(1,), (2,)}
    conn.close()


def test_delete_multiple_ids():
    conn = setup_db()
    conn.execute("INSERT INTO Institutions VALUES (3, 'Credit-Suisse')")
    conn.execute("INSERT INTO Accounts VALUES (3, 'Credit-Suisse2', 3, 1)")
    conn.execute("INSERT INTO PositionReports VALUES (4, 3, 3, 1, 40, '2024-01-01')")
    query = build_delete_query(2)
    ids = (1, 3, 1, 3)
    deleted = conn.execute(query, ids).rowcount
    assert deleted == 3
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert remaining == [(2,)]
    conn.close()


def test_delete_by_institution_and_type():
    conn = setup_db()
    query = build_delete_with_types_query(1, 1)
    params = (1, 1, 1)
    deleted = conn.execute(query, params).rowcount
    assert deleted == 2
    remaining = conn.execute('SELECT account_id FROM PositionReports').fetchall()
    assert remaining == [(2,)]
    conn.close()


def test_find_institution_ids_by_bic_prefix():
    conn = sqlite3.connect(':memory:')
    conn.execute("CREATE TABLE Institutions (institution_id INTEGER PRIMARY KEY, institution_name TEXT, bic TEXT)")
    conn.execute("INSERT INTO Institutions VALUES (1, 'ZKB', 'ZKBKCHZZ80A')")
    conn.execute("INSERT INTO Institutions VALUES (2, 'Other', 'OTHERBIC')")
    rows = conn.execute("SELECT institution_id FROM Institutions WHERE bic LIKE ? COLLATE NOCASE", ('ZKBKCHZZ80A%',)).fetchall()
    ids = [r[0] for r in rows]
    assert ids == [1]
    conn.close()

import sqlite3
from pathlib import Path

DB_ROOT = Path(__file__).resolve().parents[1] / 'DragonShield' / 'database'
SCHEMA = DB_ROOT / 'schema.sql'
SEED = DB_ROOT / 'schema.txt'


def load_db():
    conn = sqlite3.connect(':memory:')
    conn.executescript(SCHEMA.read_text(encoding='utf-8'))
    conn.executescript(SEED.read_text(encoding='utf-8'))
    return conn


def test_fetch_transaction_types():
    conn = load_db()
    count = conn.execute('SELECT COUNT(*) FROM TransactionTypes').fetchone()[0]
    assert count == 10
    conn.close()


def test_fetch_instruments():
    conn = load_db()
    count = conn.execute('SELECT COUNT(*) FROM Instruments WHERE is_active = 1').fetchone()[0]
    assert count == 50
    conn.close()

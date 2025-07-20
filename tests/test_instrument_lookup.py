import sys
import types
import sqlite3
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

# stub openpyxl for import
openpyxl_stub = types.ModuleType('openpyxl')
cell_mod = types.ModuleType('cell')
class Cell: ...
class MergedCell: ...
cell_mod.Cell = Cell
cell_mod.MergedCell = MergedCell
openpyxl_stub.cell = cell_mod
sys.modules.setdefault('openpyxl', openpyxl_stub)
sys.modules.setdefault('openpyxl.cell', openpyxl_stub.cell)

import credit_suisse_parser as csp


def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        'CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, isin TEXT, valor_nr TEXT)'
    )
    conn.execute("INSERT INTO Instruments VALUES (1, 'US0000001', '1111')")
    conn.execute("INSERT INTO Instruments VALUES (2, 'CH1234567890', 'ABC678')")
    return conn


def test_lookup_by_valor():
    conn = setup_db()
    logs = []
    result = csp.lookup_instrument(conn, 'ABC 678', '', 'Test', logs)
    assert result == 2
    assert 'via valor' in logs[0]


def test_lookup_fallback_isin():
    conn = setup_db()
    logs = []
    result = csp.lookup_instrument(conn, '', 'US0000001', 'Foo', logs)
    assert result == 1
    assert 'via ISIN' in logs[0]


def test_lookup_unmatched():
    conn = setup_db()
    logs = []
    result = csp.lookup_instrument(conn, '9999', 'NOPE', 'Unknown', logs)
    assert result is None
    assert 'Unmatched instrument description' in logs[0]

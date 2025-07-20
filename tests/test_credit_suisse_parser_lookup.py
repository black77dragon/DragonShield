import sqlite3
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import types
openpyxl_stub = types.ModuleType('openpyxl')
cell_mod = types.ModuleType('cell')
class Cell: ...
class MergedCell: ...
cell_mod.Cell = Cell
cell_mod.MergedCell = MergedCell
openpyxl_stub.cell = cell_mod
sys.modules.setdefault('openpyxl', openpyxl_stub)
sys.modules.setdefault('openpyxl.cell', openpyxl_stub.cell)

from credit_suisse_parser import lookup_instrument


def setup_conn():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        """
        CREATE TABLE Instruments (
            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
            isin TEXT UNIQUE,
            valor_nr TEXT UNIQUE,
            instrument_name TEXT
        )
        """
    )
    conn.execute(
        "INSERT INTO Instruments (isin, valor_nr, instrument_name) VALUES ('CH000001', '123456', 'Test')"
    )
    return conn


def test_lookup_by_valor():
    conn = setup_conn()
    ins_id, name, method = lookup_instrument(conn, '123456', None)
    assert ins_id == 1
    assert method == 'Valor'
    conn.close()


def test_lookup_by_isin():
    conn = setup_conn()
    ins_id, name, method = lookup_instrument(conn, None, 'CH000001')
    assert ins_id == 1
    assert method == 'ISIN'
    conn.close()

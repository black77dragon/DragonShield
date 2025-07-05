# Version 1.0
# History
# - 1.0: Initial tests for import_tool helpers.

import os
import sys
import json
import sqlite3
from pathlib import Path
import types

import pytest

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))
openpyxl_stub = types.ModuleType('openpyxl')
cell_mod = types.ModuleType('cell')
class Cell: ...
class MergedCell: ...
cell_mod.Cell = Cell
cell_mod.MergedCell = MergedCell
openpyxl_stub.cell = cell_mod
sys.modules.setdefault('openpyxl', openpyxl_stub)
sys.modules.setdefault('openpyxl.cell', openpyxl_stub.cell)

import import_tool


def setup_db():
    conn = sqlite3.connect(':memory:')
    conn.execute(
        """
        CREATE TABLE ImportSessions (
            import_session_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_name TEXT,
            file_name TEXT,
            file_path TEXT,
            file_type TEXT,
            file_size INTEGER,
            file_hash TEXT,
            institution_id INTEGER,
            import_status TEXT,
            total_rows INTEGER,
            successful_rows INTEGER,
            failed_rows INTEGER,
            processing_notes TEXT,
            started_at TEXT,
            completed_at TEXT
        )
        """
    )
    return conn


def test_compute_metadata(tmp_path):
    f = tmp_path / 'sample.csv'
    content = b'hello world'
    f.write_bytes(content)

    ftype, size, h = import_tool.compute_metadata(str(f))

    assert ftype == 'CSV'
    assert size == len(content)
    import hashlib
    assert h == hashlib.sha256(content).hexdigest()


def test_insert_and_update_session():
    conn = setup_db()
    sess_id = import_tool.insert_session(
        conn,
        'Test Session',
        'file.csv',
        '/tmp/file.csv',
        'CSV',
        10,
        'hash',
        1,
    )
    row = conn.execute('SELECT session_name FROM ImportSessions WHERE import_session_id=?', (sess_id,)).fetchone()
    assert row[0] == 'Test Session'

    import_tool.update_session(conn, sess_id, 'COMPLETED', 5, 4, 1, 'done')
    row = conn.execute('SELECT import_status, total_rows, successful_rows, failed_rows, processing_notes FROM ImportSessions WHERE import_session_id=?', (sess_id,)).fetchone()
    assert row == ('COMPLETED', 5, 4, 1, 'done')


def test_parse_file(monkeypatch, tmp_path):
    sample = {'records': [1, 2], 'summary': {}}

    def fake_process_file(path):
        print(json.dumps(sample))

    monkeypatch.setattr(import_tool, 'zkb_parser', type('M', (), {'process_file': fake_process_file}))

    f = tmp_path / 'doc.csv'
    f.write_text('x')
    data = import_tool.parse_file(str(f))

    assert data == sample

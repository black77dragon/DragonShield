# Version 1.2
# History
# - 1.1 -> 1.2: Updated for interactive phased workflow.
# - 1.0 -> 1.1: Adjusted for production container path constant.
# - 1.0: Test db_tool build and copy logic.

import os
import sys
from pathlib import Path

import types
import importlib

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import db_tool


def test_db_tool_copies(monkeypatch, tmp_path):
    copied = {}

    def fake_copy(src, dst):
        copied['src'] = str(src)
        copied['dst'] = str(dst)

    def fake_makedirs(path, exist_ok=True):
        copied['dir'] = str(path)

    monkeypatch.setattr(db_tool.shutil, 'copy2', fake_copy)
    monkeypatch.setattr(db_tool.os, 'makedirs', fake_makedirs)
    monkeypatch.setattr(db_tool.deploy_db, 'parse_version', lambda p: 'test')
    monkeypatch.setattr(db_tool, 'create_empty_db', lambda *a, **k: 0)
    monkeypatch.setattr(db_tool, 'load_seed_data', lambda *a, **k: 0)
    stopped = []
    monkeypatch.setattr(db_tool, 'stop_apps', lambda: stopped.append(True))

    old_file = tmp_path / 'old.sqlite'
    old_file.write_text('old')

    result = db_tool.main(['--target-dir', str(tmp_path), '--all'])

    assert copied['src'].endswith('dragonshield.sqlite')
    assert copied['dst'] == os.path.join(str(tmp_path), 'dragonshield.sqlite')
    assert copied['dir'] == str(tmp_path)
    assert not old_file.exists()
    assert stopped == [True]
    assert result == 0


def test_backup_reference(monkeypatch, tmp_path):
    run_args = {}

    class Result:
        def __init__(self):
            self.returncode = 0
            self.stdout = 'SQL'

    def fake_run(cmd, capture_output=True, text=True):
        run_args['cmd'] = cmd
        return Result()

    monkeypatch.setattr(db_tool.subprocess, 'run', fake_run)
    monkeypatch.setattr(db_tool.deploy_db, 'parse_version', lambda p: '1.0')
    monkeypatch.setattr(db_tool, 'DEFAULT_TARGET_DIR', str(tmp_path))
    monkeypatch.setattr(db_tool, 'stop_apps', lambda: None)

    db_file = tmp_path / 'dragonshield.sqlite'
    db_file.write_text('data')

    result = db_tool.main(['--target-dir', str(tmp_path), '--backup-ref'])

    assert run_args['cmd'][0] == '/usr/bin/sqlite3'
    assert run_args['cmd'][1] == str(db_file)
    assert '.dump' in run_args['cmd']
    assert result == 0


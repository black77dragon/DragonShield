# Version 1.1
# History
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
    monkeypatch.setattr(db_tool.deploy_db, 'build_database', lambda *a, **k: 0)
    monkeypatch.setattr(db_tool.deploy_db, 'parse_version', lambda p: 'test')

    db_tool.main(['--target-dir', str(tmp_path)])

    assert copied['src'].endswith('dragonshield.sqlite')
    assert copied['dst'] == os.path.join(str(tmp_path), 'dragonshield.sqlite')
    assert copied['dir'] == str(tmp_path)

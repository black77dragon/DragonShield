# Version 1.1
# History
# - 1.0: Initial test for deploy_db main copy behavior.
# - 1.0 -> 1.1: Stub os.path.getsize to avoid missing file error.

import os
import sys
import types
import importlib
from pathlib import Path

import pytest

# Add python_scripts to path
SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import deploy_db


def test_main_copies_db(monkeypatch, tmp_path):
    copied = {}

    def fake_copy(src, dst):
        copied['src'] = src
        copied['dst'] = dst

    def fake_makedirs(path, exist_ok=True):
        copied['dir'] = path

    monkeypatch.setattr(deploy_db.shutil, 'copy2', fake_copy)
    monkeypatch.setattr(deploy_db.os, 'makedirs', fake_makedirs)
    monkeypatch.setattr(deploy_db.os.path, 'expanduser', lambda p: str(tmp_path))
    monkeypatch.setattr(deploy_db.os.path, 'getsize', lambda p: 0)
    monkeypatch.setattr(deploy_db, 'build_database', lambda *a, **k: 0)
    monkeypatch.setattr('builtins.input', lambda _: 'y')

    deploy_db.main()

    assert copied['src'].endswith('dragonshield.sqlite')
    assert copied['dst'] == os.path.join(str(tmp_path), 'dragonshield.sqlite')
    assert copied['dir'] == str(tmp_path)

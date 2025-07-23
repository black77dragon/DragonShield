import sqlite3
from pathlib import Path
import json
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import backup_restore


def create_sample_db(path: Path):
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, val TEXT)")
    conn.executemany("INSERT INTO test (val) VALUES (?)", [("a",), ("b",), ("c",)])
    conn.commit()
    conn.close()


def test_backup_and_restore(tmp_path):
    db_path = tmp_path / 'dragonshield.sqlite'
    create_sample_db(db_path)

    result = backup_restore.main(['backup', '--db', str(db_path), '--dest', str(tmp_path), '--env', 'unit'])
    assert result == 0
    backup_file = next(tmp_path.glob('unit_backup_*.sqlite'))
    manifest = json.loads((backup_file.with_suffix('.manifest.json')).read_text())
    assert manifest['counts']['test'] == 3

    # modify db
    conn = sqlite3.connect(db_path)
    conn.execute("INSERT INTO test (val) VALUES ('d')")
    conn.commit()
    conn.close()

    result = backup_restore.main(['restore', str(backup_file), '--db', str(db_path)])
    assert result == 0
    conn = sqlite3.connect(db_path)
    rows = conn.execute('SELECT COUNT(*) FROM test').fetchone()[0]
    conn.close()
    assert rows == 3

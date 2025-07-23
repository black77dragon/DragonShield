from pathlib import Path
import shutil
import sqlite3
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import db_backup_restore as br


def make_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.execute('CREATE TABLE test(id INTEGER PRIMARY KEY, val TEXT)')
    conn.executemany('INSERT INTO test(val) VALUES (?)', [('a',), ('b',)])
    conn.commit()
    conn.close()


def test_backup_and_restore(tmp_path: Path) -> None:
    db = tmp_path / 'db.sqlite'
    make_db(db)

    backup = tmp_path / 'backup.sqlite'
    manifest = br.backup_database(db, backup)
    assert backup.exists() and manifest.exists()

    # modify live db so pre-restore validation fails
    conn = sqlite3.connect(db)
    conn.execute('DELETE FROM test WHERE id=1')
    conn.commit()
    conn.close()

    assert br.restore_database(backup, db) == 1

    # reset db to match backup and restore successfully
    shutil.copy2(backup, db)
    assert br.restore_database(backup, db) == 0
    conn = sqlite3.connect(db)
    count = conn.execute('SELECT COUNT(*) FROM test').fetchone()[0]
    conn.close()
    assert count == 2

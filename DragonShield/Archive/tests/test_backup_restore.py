import sqlite3
from pathlib import Path

import pytest

from DragonShield.python_scripts.backup_restore import backup_database, restore_database


def setup_db(path: Path):
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, val TEXT)")
    conn.execute("INSERT INTO t1(val) VALUES ('a'),('b')")
    conn.execute("CREATE TABLE t2(id INTEGER)")
    conn.execute("INSERT INTO t2 VALUES (1),(2)")
    conn.commit()
    conn.close()


def test_backup_and_restore(tmp_path):
    db = tmp_path / "dragonshield.sqlite"
    setup_db(db)

    backup_dir = tmp_path / "backups"
    backup_file, counts = backup_database(db, backup_dir, "test")

    assert backup_file.exists()
    assert counts["t1"] == 2
    assert counts["t2"] == 2
    assert "sqlite_sequence" in counts

    # remove one row so restore has effect
    conn = sqlite3.connect(db)
    conn.execute("DELETE FROM t1 WHERE id=1")
    conn.execute("DELETE FROM t2 WHERE id=1")
    conn.commit()
    conn.close()

    summary = restore_database(db, backup_file)

    assert summary["t1"] == (1, 2)
    assert summary["t2"] == (1, 2)

    # check old file preserved
    old_files = list(tmp_path.glob("dragonshield.sqlite.old.*"))
    assert len(old_files) == 1

    # backup should still exist
    assert backup_file.exists()


def test_restore_rejects_corrupt_backup(tmp_path):
    db = tmp_path / "dragonshield.sqlite"
    setup_db(db)

    backup_dir = tmp_path / "backups"
    backup_file, _ = backup_database(db, backup_dir, "test")

    # modify current database so a restore would change it
    conn = sqlite3.connect(db)
    conn.execute("DELETE FROM t1 WHERE id=1")
    conn.commit()
    conn.close()

    # corrupt the backup file
    backup_file.write_bytes(b"not a sqlite database")

    with pytest.raises(RuntimeError):
        restore_database(db, backup_file)

    # no .old file should be created and DB should remain modified
    assert not list(tmp_path.glob("dragonshield.sqlite.old.*"))
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT COUNT(*) FROM t1").fetchone()[0] == 1
    conn.close()

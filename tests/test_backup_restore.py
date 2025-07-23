import sqlite3
from pathlib import Path


from DragonShield.python_scripts.backup_restore import backup_database, restore_database


def setup_db(path: Path):
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE t1(id INTEGER)")
    conn.execute("INSERT INTO t1 VALUES (1),(2)")
    conn.commit()
    conn.close()


def test_backup_and_restore(tmp_path):
    db = tmp_path / "dragonshield.sqlite"
    setup_db(db)

    backup_dir = tmp_path / "backups"
    backup_file, counts = backup_database(db, backup_dir, "test")

    assert backup_file.exists()
    assert counts == {"t1": 2}

    # remove one row so restore has effect
    conn = sqlite3.connect(db)
    conn.execute("DELETE FROM t1 WHERE id=1")
    conn.commit()
    conn.close()

    summary = restore_database(db, backup_file)

    assert summary["t1"] == (1, 2)

    # check old file preserved
    old_files = list(tmp_path.glob("dragonshield.sqlite.old.*"))
    assert len(old_files) == 1

    # backup should still exist
    assert backup_file.exists()


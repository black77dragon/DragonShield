# python_scripts/import_tool.py
# MARK: - Version 1.1 (2025-06-16)
# MARK: - History
# - 1.1: DB_PATH now uses the expanded user Library path.
# - 1.0: Initial creation for interactive statement parsing.

import os
import sqlite3
import hashlib
import json
import io
import contextlib
from typing import Any

import zkb_parser  # existing parser in the same folder

DB_PATH = os.path.expanduser(
    os.path.join('~', 'Library', 'Application Support', 'DragonShield', 'dragonshield.sqlite')
)


def choose_account(conn: sqlite3.Connection) -> int:
    rows = conn.execute("SELECT account_id, account_name FROM Accounts ORDER BY account_name").fetchall()
    if not rows:
        raise RuntimeError("No accounts found in database")
    print("Available accounts:")
    for acc_id, name in rows:
        print(f"{acc_id}: {name}")
    while True:
        try:
            choice = int(input("Select account id: "))
            if any(acc_id == choice for acc_id, _ in rows):
                return choice
            print("Invalid account id. Try again.")
        except ValueError:
            print("Please enter a valid number.")


def compute_metadata(path: str) -> tuple[str, int, str]:
    size = os.path.getsize(path)
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    ext = os.path.splitext(path)[1].lower()
    if ext in ('.xlsx', '.xls'):
        ftype = 'XLSX'
    elif ext == '.csv':
        ftype = 'CSV'
    elif ext == '.pdf':
        ftype = 'PDF'
    else:
        ftype = 'CSV'
    return ftype, size, h.hexdigest()


def insert_session(conn: sqlite3.Connection, name: str, fname: str, fpath: str,
                    ftype: str, size: int, fh: str, account_id: int) -> int:
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO ImportSessions
            (session_name, file_name, file_path, file_type, file_size, file_hash,
             account_id, import_status, started_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'PROCESSING', datetime('now'))
        """,
        (name, fname, fpath, ftype, size, fh, account_id),
    )
    conn.commit()
    return cur.lastrowid


def update_session(conn: sqlite3.Connection, sess_id: int, status: str,
                    total: int, success: int, failed: int, notes: str | None = None):
    conn.execute(
        """
        UPDATE ImportSessions
           SET import_status=?, total_rows=?, successful_rows=?,
               failed_rows=?, completed_at=datetime('now'), processing_notes=?
         WHERE import_session_id=?
        """,
        (status, total, success, failed, notes, sess_id),
    )
    conn.commit()


def parse_file(path: str) -> dict[str, Any]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        zkb_parser.process_file(path)
    return json.loads(buf.getvalue())


def preview_records(data: dict[str, Any], limit: int = 3):
    records = data.get("records", [])
    print(f"Parsed {len(records)} rows. Showing first {limit}:")
    for row in records[:limit]:
        print(json.dumps(row, indent=2, ensure_ascii=False))
    if err := data.get("summary", {}).get("error"):
        print("Error during parsing:", err)


def main():
    conn = sqlite3.connect(DB_PATH)
    try:
        account_id = choose_account(conn)
        file_path = input("Enter path to statement file: ").strip()
        if not os.path.isfile(file_path):
            print("File not found.")
            return
        file_type, size, file_hash = compute_metadata(file_path)

        dup = conn.execute(
            "SELECT import_session_id FROM ImportSessions WHERE file_hash=?",
            (file_hash,),
        ).fetchone()
        if dup:
            print("This file was already imported. Session id:", dup[0])
            return

        session_id = insert_session(
            conn,
            f"Import {os.path.basename(file_path)}",
            os.path.basename(file_path),
            os.path.abspath(file_path),
            file_type,
            size,
            file_hash,
            account_id,
        )
        print("Import session", session_id, "created. Parsing...")
        data = parse_file(file_path)
        preview_records(data)
        proceed = input("Commit import? [y/N]: ").strip().lower() == 'y'
        if proceed:
            update_session(
                conn,
                session_id,
                'COMPLETED',
                data.get('summary', {}).get('total_data_rows_attempted', 0),
                data.get('summary', {}).get('data_rows_successfully_parsed', 0),
                data.get('summary', {}).get('total_data_rows_attempted', 0)
                - data.get('summary', {}).get('data_rows_successfully_parsed', 0),
                None,
            )
            print("Import committed.")
        else:
            update_session(conn, session_id, 'CANCELLED', 0, 0, 0, 'User cancelled')
            print("Import cancelled.")
    finally:
        conn.close()


if __name__ == '__main__':
    main()

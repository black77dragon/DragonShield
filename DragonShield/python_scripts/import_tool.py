# python_scripts/import_tool.py

# MARK: - Version 1.3
# MARK: - History
# - 1.2 -> 1.3: Updated default database path to production container location.
# - 1.1 -> 1.2: Support importing multiple files in one run and print summary.
# - 1.0 -> 1.1: Replace builtin generics with typing equivalents for
#   compatibility with older Python versions.


import os
import sqlite3
import hashlib
import json
import io
import contextlib
from typing import Any, Dict, Tuple, Optional

import zkb_parser  # existing parser in the same folder

DB_PATH = os.path.join(
    "/Users/renekeller/Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield",
    "dragonshield.sqlite",
)


def choose_institution(conn: sqlite3.Connection) -> int:
    rows = conn.execute(
        "SELECT institution_id, institution_name FROM Institutions ORDER BY institution_name"
    ).fetchall()
    if not rows:
        raise RuntimeError("No institutions found in database")
    print("Available institutions:")
    for inst_id, name in rows:
        print(f"{inst_id}: {name}")
    while True:
        try:
            choice = int(input("Select institution id: "))
            if any(inst_id == choice for inst_id, _ in rows):
                return choice
            print("Invalid institution id. Try again.")
        except ValueError:
            print("Please enter a valid number.")


def compute_metadata(path: str) -> Tuple[str, int, str]:
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
                    ftype: str, size: int, fh: str, institution_id: int) -> int:
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO ImportSessions
            (session_name, file_name, file_path, file_type, file_size, file_hash,
             institution_id, import_status, started_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'PROCESSING', datetime('now'))
        """,
        (name, fname, fpath, ftype, size, fh, institution_id),
    )
    conn.commit()
    return cur.lastrowid


def update_session(conn: sqlite3.Connection, sess_id: int, status: str,
                    total: int, success: int, failed: int, duplicate: int,
                    notes: Optional[str] = None):
    conn.execute(
        """
        UPDATE ImportSessions
           SET import_status=?, total_rows=?, successful_rows=?,
               failed_rows=?, duplicate_rows=?, completed_at=datetime('now'), processing_notes=?
         WHERE import_session_id=?
        """,
        (status, total, success, failed, duplicate, notes, sess_id),
    )
    conn.commit()


def parse_file(path: str) -> Dict[str, Any]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        zkb_parser.process_file(path)
    return json.loads(buf.getvalue())


def preview_records(data: Dict[str, Any], limit: int = 3):
    records = data.get("records", [])
    print(f"Parsed {len(records)} rows. Showing first {limit}:")
    for row in records[:limit]:
        print(json.dumps(row, indent=2, ensure_ascii=False))
    if err := data.get("summary", {}).get("error"):
        print("Error during parsing:", err)


def process_file_path(conn: sqlite3.Connection, institution_id: int, file_path: str) -> Dict[str, Any]:
    if not os.path.isfile(file_path):
        print("File not found.")
        return {}

    file_type, size, file_hash = compute_metadata(file_path)

    session_id = insert_session(
        conn,
        f"Import {os.path.basename(file_path)}",
        os.path.basename(file_path),
        os.path.abspath(file_path),
        file_type,
        size,
        file_hash,
        institution_id,
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
            data.get('summary', {}).get('duplicate_rows', 0),
            None,
        )
        print("Import committed.")
    else:
        update_session(conn, session_id, 'CANCELLED', 0, 0, 0, 0, 'User cancelled')
        print("Import cancelled.")
    return data.get('summary', {})


def main():
    conn = sqlite3.connect(DB_PATH)
    summaries = []
    try:
        institution_id = choose_institution(conn)
        while True:
            file_path = input("Enter path to statement file: ").strip()
            if not file_path:
                break
            summary = process_file_path(conn, institution_id, file_path)
            if summary:
                summaries.append((file_path, summary))
            again = input("Import another file? [y/N]: ").strip().lower() == 'y'
            if not again:
                break
    finally:
        conn.close()

    if summaries:
        print("\n===== Import Summary =====")
        for path, summ in summaries:
            print(f"File: {os.path.basename(path)}")
            print(f"  Total rows: {summ.get('total_data_rows_attempted', 0)}")
            print(f"  Parsed successfully: {summ.get('data_rows_successfully_parsed', 0)}")
            print(f"  Cash records: {summ.get('cash_account_records', 0)}")
            print(f"  Security records: {summ.get('security_holding_records', 0)}")
    else:
        print("No files were imported.")


if __name__ == '__main__':
    main()

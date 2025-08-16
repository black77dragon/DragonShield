#!/usr/bin/env python3
"""Generate a full Instruments report in XLSX format."""
# python_scripts/generate_instrument_report.py
# MARK: - Version 1.1
# MARK: - History
# - 1.0: Initial implementation that builds an in-memory DB from schema files
#   and exports the Instruments table to XLSX.
# - 1.1: Remove pandas dependency and fix schema path lookup.

import sqlite3
from pathlib import Path
import argparse
from zipfile import ZipFile, ZIP_DEFLATED
from xml.sax.saxutils import escape


def build_temp_db(schema_sql: Path, seed_sql: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    with open(schema_sql, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    with open(seed_sql, "r", encoding="utf-8") as f:
        statements = f.read().split(";")
    for stmt in statements:
        if stmt.strip():
            try:
                conn.execute(stmt)
            except sqlite3.Error:
                # Ignore seed data mismatches to keep report generation resilient
                pass
    return conn


def excel_col(index: int) -> str:
    """Return Excel-style column name for 1-based index."""
    name = ""
    i = index
    while i > 0:
        i, rem = divmod(i - 1, 26)
        name = chr(65 + rem) + name
    return name


def write_simple_xlsx(path: Path, headers, rows) -> None:
    """Write data to a minimal XLSX file without external dependencies."""
    sheet = [
        "<?xml version='1.0' encoding='UTF-8'?>",
        "<worksheet xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><sheetData>",
    ]
    for r_idx, row in enumerate([headers] + list(rows), start=1):
        sheet.append(f"<row r='{r_idx}'>")
        for c_idx, value in enumerate(row, start=1):
            cell = f"<c r='{excel_col(c_idx)}{r_idx}' t='inlineStr'><is><t>{escape(str(value))}</t></is></c>"
            sheet.append(cell)
        sheet.append("</row>")
    sheet.append("</sheetData></worksheet>")
    sheet_xml = "".join(sheet)

    content_types = (
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types'>"
        "<Default Extension='rels' ContentType='application/vnd.openxmlformats-package.relationships+xml'/>"
        "<Default Extension='xml' ContentType='application/xml'/>"
        "<Override PartName='/xl/workbook.xml' ContentType='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'/>"
        "<Override PartName='/xl/worksheets/sheet1.xml' ContentType='application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml'/>"
        "</Types>"
    )

    rels = (
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>"
        "<Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='xl/workbook.xml'/>"
        "</Relationships>"
    )

    workbook = (
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<workbook xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'>"
        "<sheets><sheet name='Instruments' sheetId='1' r:id='rId1'/></sheets>"
        "</workbook>"
    )

    workbook_rels = (
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>"
        "<Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet' Target='worksheets/sheet1.xml'/>"
        "</Relationships>"
    )

    with ZipFile(path, "w", ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", rels)
        zf.writestr("xl/workbook.xml", workbook)
        zf.writestr("xl/_rels/workbook.xml.rels", workbook_rels)
        zf.writestr("xl/worksheets/sheet1.xml", sheet_xml)


def generate_report(output_path: Path) -> None:
    script_dir = Path(__file__).resolve().parents[1]
    db_dir = script_dir / "db"
    schema_sql = db_dir / "schema.sql"
    seed_sql = db_dir / "schema.txt"

    conn = build_temp_db(schema_sql, seed_sql)
    cur = conn.cursor()
    cur.execute("SELECT * FROM Instruments")
    rows = cur.fetchall()
    headers = [d[0] for d in cur.description]
    write_simple_xlsx(output_path, headers, rows)
    conn.close()
    print(f"✅ Created instrument report at {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a full Instruments report in XLSX format"
    )
    parser.add_argument(
        "output",
        nargs="?",
        default="instrument_report.xlsx",
        help="Path to output XLSX file"
    )
    args = parser.parse_args()
    generate_report(Path(args.output))

#!/usr/bin/env python3
"""Summarize values for an import session."""

import argparse
import sqlite3
from typing import Any, Dict, List

DB_PATH = (
    "/Users/renekeller/Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield"
    "/dragonshield.sqlite"
)


def get_fx_rate(conn: sqlite3.Connection, currency: str, date: str) -> float | None:
    cur = conn.execute(
        """SELECT rate_to_chf FROM ExchangeRates
           WHERE currency_code=? AND rate_date<=?
           ORDER BY rate_date DESC LIMIT 1""",
        (currency, date),
    )
    row = cur.fetchone()
    return row[0] if row else None


def fetch_positions(conn: sqlite3.Connection, session_id: int) -> List[Dict[str, Any]]:
    query = """
        SELECT i.instrument_name, i.currency, pr.quantity, pr.current_price, pr.report_date
          FROM PositionReports pr
          JOIN Instruments i ON pr.instrument_id = i.instrument_id
         WHERE pr.import_session_id = ?;
    """
    rows = conn.execute(query, (session_id,)).fetchall()
    result = []
    for name, currency, qty, price, date in rows:
        result.append(
            {
                "instrument": name,
                "currency": currency,
                "quantity": qty,
                "price": price,
                "date": date,
            }
        )
    return result


def summarize_positions(conn: sqlite3.Connection, positions: List[Dict[str, Any]]) -> Dict[str, Any]:
    totals: Dict[str, float] = {}
    items: List[Dict[str, Any]] = []
    total_chf = 0.0
    for p in positions:
        price = p.get("price")
        if price is None:
            continue
        qty = p.get("quantity", 0.0)
        value = qty * price
        currency = str(p.get("currency", "CHF")).upper()
        rate = 1.0
        if currency != "CHF":
            r = get_fx_rate(conn, currency, p.get("date"))
            if r is None:
                continue
            rate = r
        value_chf = value * rate
        items.append(
            {
                "instrument": p.get("instrument", ""),
                "currency": currency,
                "value_orig": value,
                "value_chf": value_chf,
            }
        )
        totals[currency] = totals.get(currency, 0.0) + value_chf
        total_chf += value_chf
    return {"total_chf": total_chf, "breakdown": totals, "positions": items}


def save_total(conn: sqlite3.Connection, session_id: int, total: float) -> None:
    note = f"total_value_chf={total:.2f}"
    conn.execute(
        "UPDATE ImportSessions SET processing_notes=? WHERE import_session_id=?",
        (note, session_id),
    )
    conn.commit()


def save_report(conn: sqlite3.Connection, session_id: int, items: List[Dict[str, Any]]) -> None:
    conn.execute(
        "DELETE FROM ImportSessionValueReports WHERE import_session_id=?",
        (session_id,)
    )
    conn.executemany(
        """
        INSERT INTO ImportSessionValueReports
            (import_session_id, instrument_name, currency, value_orig, value_chf)
        VALUES (?,?,?,?,?)
        """,
        [
            (
                session_id,
                item.get("instrument", ""),
                item.get("currency", "CHF"),
                item.get("value_orig", 0.0),
                item.get("value_chf", 0.0),
            )
            for item in items
        ],
    )
    conn.commit()


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Summarize import session values")
    parser.add_argument("session_id", type=int, help="Import session id")
    parser.add_argument("--db", default=DB_PATH, help="Path to database")
    args = parser.parse_args(argv)

    conn = sqlite3.connect(args.db)
    positions = fetch_positions(conn, args.session_id)
    summary = summarize_positions(conn, positions)
    save_total(conn, args.session_id, summary["total_chf"])
    save_report(conn, args.session_id, summary["positions"])

    print(f"Total value CHF: {summary['total_chf']:.2f}")
    print("Breakdown by currency:")
    for cur, val in summary["breakdown"].items():
        print(f"  {cur}: {val:.2f} CHF")
    print("Positions:")
    for item in summary["positions"]:
        print(
            f"  {item['instrument']}: {item['value_orig']:.2f} {item['currency']} -> {item['value_chf']:.2f} CHF"
        )
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

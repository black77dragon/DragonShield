import csv
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

ZKB_TO_SUBCLASS = {
    "Obligationen und Ähnliches": ("FI", "STOCK"),
    "Sonstige Anlagen": ("OTHER", "OTHER"),
    "Equities (EU)": ("EQT", "EGM"),
}

LOG_FILE = Path(__file__).resolve().parents[2] / "import.log"


def _setup_logger() -> logging.Logger:
    logger = logging.getLogger("zkb_parser")
    if not logger.handlers:
        handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
        formatter = logging.Formatter(
            "%(asctime)s %(levelname)s %(message)s", "%Y-%m-%dT%H:%M:%S"
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger

COL_CATEGORY = "Anlagekategorie"
COL_QUANTITY = "Anz./Nom."
COL_COST_PRICE = "Einstandskurs"
COL_MARKET_PRICE = "Marktkurs"
COL_CURRENCY = "Währung"
COL_NAME = "Bezeichnung"
COL_VALOR = "Valor/IBAN/MSCI ESG-Rating"


def _parse_decimal(text: str) -> Optional[float]:
    if text is None:
        return None
    clean = text.replace("'", "").replace(" ", "").strip()
    if not clean:
        return None
    clean = clean.replace(",", ".")
    try:
        return float(clean)
    except ValueError:
        return None


def parse_date_from_filename(filename: str) -> Optional[str]:
    m = re.search(r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2})\s+(\d{4})", filename, re.IGNORECASE)
    if not m:
        return None
    month_map = {name: i for i, name in enumerate(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}
    month = month_map[m.group(1)[:3].title()]
    return datetime(int(m.group(3)), month, int(m.group(2))).strftime("%Y-%m-%d")


def process_file(path: str) -> int:
    logger = _setup_logger()
    logger.info(f"Starting parse for {path}")

    data: Dict[str, Any] = {
        "records": [],
        "summary": {
            "processed_file": path,
            "total_data_rows_attempted": 0,
            "data_rows_successfully_parsed": 0,
        },
    }
    try:
        with open(path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            logger.info(f"CSV headers: {reader.fieldnames}")
            for idx, row in enumerate(reader, 1):
                data["summary"]["total_data_rows_attempted"] += 1
                logger.info(f"Row {idx} raw: {row}")

                cat = row.get(COL_CATEGORY, "").strip()
                quantity = _parse_decimal(row.get(COL_QUANTITY, ""))
                cost = _parse_decimal(row.get(COL_COST_PRICE, ""))
                price = _parse_decimal(row.get(COL_MARKET_PRICE, ""))
                currency = row.get(COL_CURRENCY, "").strip().upper() or None
                name = row.get(COL_NAME, "").strip()
                valor = row.get(COL_VALOR, "").strip()

                if not cat and not name:
                    logger.info(f"Row {idx} skipped: empty category and name")
                    continue

                record: Dict[str, Any] = {
                    "anlagekategorie": cat,
                    "quantity": quantity,
                    "purchase_price": cost,
                    "current_price": price,
                    "currency": currency,
                    "instrument_name": name,
                    "valor_nr": valor,
                }
                if cat in ZKB_TO_SUBCLASS:
                    ac, sub = ZKB_TO_SUBCLASS[cat]
                    record["asset_class_code"] = ac
                    record["asset_sub_class_code"] = sub
                data["records"].append(record)
                data["summary"]["data_rows_successfully_parsed"] += 1
                logger.info(f"Row {idx} parsed: {record}")
    except FileNotFoundError:
        data["summary"]["error"] = f"File not found at {path}"
        logger.error(data["summary"]["error"])
    except Exception as e:  # pragma: no cover - generic fallback
        data["summary"]["error"] = str(e)
        logger.error(f"Unexpected error: {e}")

    logger.info(f"Summary: {data['summary']}")

    print(json.dumps(data, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        process_file(sys.argv[1])
    else:
        print(json.dumps({"error": "Please provide CSV path"}))

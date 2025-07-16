import csv
import json
import re
import sys
from typing import Any, Dict, Optional


def parse_statement_date_from_filename(filename: str) -> Optional[str]:
    match_mon_dd_yyyy = re.search(
        r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s.-]+(\d{1,2})[\s.,-]+(\d{4})",
        filename,
        re.IGNORECASE,
    )
    if match_mon_dd_yyyy:
        month_str, day, year = match_mon_dd_yyyy.groups()
        month_map = {name: num for num, name in enumerate([
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}
        month = month_map.get(month_str[:3].capitalize())
        if month:
            return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"
    return None


def parse_number(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    cleaned = text.replace("'", "").replace(" ", "")
    cleaned = cleaned.replace(".", "").replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def process_file(filepath: str) -> int:
    parsed: Dict[str, Any] = {
        "institution_name": "ZKB",
        "parsed_statement_date": parse_statement_date_from_filename(filepath.split('/')[-1]),
        "summary": {
            "processed_file": filepath,
            "total_data_rows_attempted": 0,
            "data_rows_successfully_parsed": 0,
            "cash_account_records": 0,
            "security_holding_records": 0,
        },
        "records": [],
    }
    try:
        with open(filepath, newline='', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f, delimiter=';')
            for row in reader:
                parsed["summary"]["total_data_rows_attempted"] += 1
                category = (row.get("Anlagekategorie") or "").strip()
                quantity = parse_number(row.get("Anz./Nom."))
                price = parse_number(row.get("Kurs"))
                currency = (row.get("Währung") or "").strip()
                name = (row.get("Bezeichnung") or "").strip()
                isin_match = re.search(r"[A-Z]{2}[A-Z0-9]{10}", name)
                valor_match = re.search(r"\b\d{6,}\b", name)
                record: Dict[str, Any]
                if category == "Konten":
                    parsed["summary"]["cash_account_records"] += 1
                    record = {
                        "record_type": "cash_account",
                        "currency": currency,
                        "balance": quantity,
                    }
                else:
                    parsed["summary"]["security_holding_records"] += 1
                    record = {
                        "record_type": "security_holding",
                        "instrument_name_from_file": name,
                        "isin": isin_match.group(0) if isin_match else None,
                        "valor": valor_match.group(0) if valor_match else None,
                        "quantity_nominal": quantity,
                        "current_price": price,
                        "currency": currency,
                        "original_anlagekategorie": category,
                    }
                parsed["records"].append(record)
                parsed["summary"]["data_rows_successfully_parsed"] += 1
    except FileNotFoundError:
        parsed["summary"]["error"] = f"File not found at {filepath}"
        print(json.dumps(parsed, ensure_ascii=False))
        return 1
    except Exception as e:  # pragma: no cover - generic error path
        parsed["summary"]["error"] = f"An error occurred: {e}"
        print(json.dumps(parsed, ensure_ascii=False))
        return 3

    print(json.dumps(parsed, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI usage
    if len(sys.argv) > 1:
        sys.exit(process_file(sys.argv[1]))
    print(json.dumps({
        "error": "Please provide the CSV file path as an argument.",
        "usage": "python zkb_parser.py <path_to_file.csv>",
    }))
    sys.exit(1)

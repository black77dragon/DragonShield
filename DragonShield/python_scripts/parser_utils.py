# python_scripts/parser_utils.py

# MARK: - Version 1.0.0.0
# MARK: - History
# - 1.0.0.0: Initial set of parsing helper utilities extracted from zkb_parser.

from __future__ import annotations

import re
from datetime import datetime
from typing import Any, Dict, Tuple, Optional, Set

try:
    from openpyxl.cell import Cell, MergedCell
except Exception:  # openpyxl might not be installed in some test environments
    Cell = MergedCell = type("Dummy", (), {})


ANLAGEKATEGORIE_TO_GROUP_MAP: Dict[str, str] = {
    "Liquidität & ähnliche": "Cash & Money Market",
    "Festverzinsliche & ähnliche": "Bonds",
    "Aktien & ähnliche": "Equities",
    "AI, Rohstoffe & Immobilien": "Commodities",
}

ASSET_UNTERKATEGORIE_REFINEMENT_MAP: Dict[Tuple[str, str], str] = {
    ("Festverzinsliche & ähnliche", "Obligationenfonds / USD"): "ETFs",
    ("Liquidität & ähnliche", "Geldmarktfonds / CHF"): "Mutual Funds",
    ("Aktien & ähnliche", "Aktienfonds / USA"): "ETFs",
}


def _get_actual_cell_value(cell_content: Any) -> Any:
    """Return the underlying value for openpyxl cell objects."""
    if isinstance(cell_content, (Cell, MergedCell)):
        return cell_content.value
    return cell_content


def parse_statement_date_from_filename(filename: str) -> Optional[str]:
    match_dmY = re.search(r"(\d{1,2})[.-](\d{1,2})[.-](\d{4})", filename)
    if match_dmY:
        day, month, year = match_dmY.groups()
        try:
            return datetime(int(year), int(month), int(day)).strftime("%Y-%m-%d")
        except Exception:
            pass
    match_Ymd = re.search(r"(\d{4})[.-]?(\d{2})[.-]?(\d{2})", filename)
    if match_Ymd:
        year, month, day = match_Ymd.groups()
        if len(year) == 4 and len(month) == 2 and len(day) == 2:
            try:
                return datetime(int(year), int(month), int(day)).strftime("%Y-%m-%d")
            except Exception:
                pass
    match_mon_dd_yyyy = re.search(
        r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s.-]+(\d{1,2})[\s.,-]+(\d{4})",
        filename,
        re.IGNORECASE,
    )
    if match_mon_dd_yyyy:
        month_str, day, year = match_mon_dd_yyyy.groups()
        month_map = {name: num for num, name in enumerate(
            ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
            1,
        )}
        month = month_map.get(month_str[:3].capitalize())
        if month:
            try:
                return datetime(int(year), month, int(day)).strftime("%Y-%m-%d")
            except Exception:
                pass
    return None


def parse_date_from_excel_cell(cell_content: Any, input_format: Optional[str] = None) -> Optional[str]:
    val = _get_actual_cell_value(cell_content)
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.strftime("%Y-%m-%d")
    if isinstance(val, str):
        cell_str = val.strip()
        if not cell_str:
            return None
        if input_format:
            try:
                return datetime.strptime(cell_str, input_format).strftime("%Y-%m-%d")
            except ValueError:
                pass
        match_dmY_short_long = re.match(r"(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})", cell_str)
        if match_dmY_short_long:
            d, m, y_part = match_dmY_short_long.groups()
            year = int(y_part)
            if len(y_part) == 2:
                year += 2000
            try:
                return datetime(year, int(m), int(d)).strftime("%Y-%m-%d")
            except Exception:
                pass
        if len(cell_str) >= 10 and cell_str[4] == "-" and cell_str[7] == "-":
            try:
                return datetime.strptime(cell_str[:10], "%Y-%m-%d").strftime("%Y-%m-%d")
            except ValueError:
                pass
    return None


def parse_portfolio_nr_from_cell_value(cell_content: Any) -> Optional[str]:
    val = _get_actual_cell_value(cell_content)
    if not isinstance(val, str):
        return None
    line_content = val.strip()
    match_user_format = re.search(r"S \d{6}-\d{2}", line_content)
    if match_user_format:
        return match_user_format.group(0)
    match_generic = re.search(r"S\s*\d{6}-\d{2}", line_content)
    if match_generic:
        return match_generic.group(0)
    return None


def parse_number_from_cell_value(cell_content: Any) -> Optional[float]:
    val = _get_actual_cell_value(cell_content)
    if val is None:
        return None
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        value_str = val.strip()
        if not value_str:
            return None
        try:
            cleaned_str = value_str.replace("'", "")
            if "%" in cleaned_str:
                return float(cleaned_str.replace("%", "")) / 100.0
            return float(cleaned_str)
        except ValueError:
            return None
    return None


def get_mapped_instrument_group(
    anlagekategorie: str,
    asset_unterkategorie: str,
    unmapped_pairs: Set[Tuple[str, str]],
) -> str:
    norm_anlage = anlagekategorie.strip() if anlagekategorie else ""
    norm_unter = asset_unterkategorie.strip() if asset_unterkategorie else ""
    refined_group = ASSET_UNTERKATEGORIE_REFINEMENT_MAP.get((norm_anlage, norm_unter))
    if refined_group:
        return refined_group
    primary_group = ANLAGEKATEGORIE_TO_GROUP_MAP.get(norm_anlage)
    if primary_group:
        return primary_group
    if norm_anlage or norm_unter:
        unmapped_pairs.add((norm_anlage, norm_unter))
    return "UNMAPPED_CATEGORY"


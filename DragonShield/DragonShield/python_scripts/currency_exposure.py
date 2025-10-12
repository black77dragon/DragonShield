"""Utility to compute currency exposure of a portfolio."""

from typing import Iterable, Mapping, List, Dict


def currency_exposure(
    positions: Iterable[Mapping], rates: Mapping[str, float], top_n: int = 6
) -> List[Dict[str, float]]:
    """Return breakdown of position values by currency.

    Each position mapping must provide ``quantity``, ``current_price`` and
    ``currency`` keys. ``rates`` maps currency codes to ``rate_to_chf``.
    Raises ``KeyError`` if a non-CHF currency is missing from ``rates``.
    """
    totals: Dict[str, float] = {}
    total_chf = 0.0
    for pos in positions:
        qty = pos.get("quantity", 0)
        price = pos.get("current_price")
        if price is None:
            continue
        value = qty * price
        currency = str(pos.get("currency", "CHF")).upper()
        if currency != "CHF":
            if currency not in rates:
                raise KeyError(currency)
            value *= rates[currency]
        totals[currency] = totals.get(currency, 0.0) + value
        total_chf += value

    breakdown = [
        {
            "currency": code,
            "percentage": (val / total_chf * 100) if total_chf else 0.0,
            "value_chf": val,
        }
        for code, val in sorted(totals.items(), key=lambda x: x[1], reverse=True)
    ]

    if len(breakdown) > top_n:
        other = breakdown[top_n:]
        other_value = sum(item["value_chf"] for item in other)
        breakdown = breakdown[:top_n]
        breakdown.append(
            {
                "currency": "Other",
                "percentage": (other_value / total_chf * 100) if total_chf else 0.0,
                "value_chf": other_value,
            }
        )

    return breakdown


__all__ = ["currency_exposure"]

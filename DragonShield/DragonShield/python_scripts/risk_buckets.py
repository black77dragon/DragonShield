"""Utilities for computing risk concentration buckets."""

from typing import Iterable, Mapping, List, Dict


def top_risk_buckets(
    positions: Iterable[Mapping],
    rates: Mapping[str, float],
    dimension: str = "sector",
    top_n: int = 5,
) -> List[Dict[str, float]]:
    """Return top ``top_n`` groups by CHF value.

    Each position should provide ``quantity``, ``current_price`` and ``currency``
    plus fields corresponding to the grouping dimension such as ``sector``,
    ``issuer``, or ``country_code``. Rates map currency codes to ``rate_to_chf``.
    Unknown currencies are ignored.
    """

    totals: Dict[str, float] = {}
    portfolio_total = 0.0

    for pos in positions:
        price = pos.get("current_price")
        if price is None:
            continue
        qty = pos.get("quantity", 0)
        currency = str(pos.get("currency", "CHF")).upper()
        value = qty * price
        if currency != "CHF":
            rate = rates.get(currency)
            if rate is None:
                continue
            value *= rate
        portfolio_total += value
        label = str(pos.get(dimension)) if dimension != "currency" else currency
        if label == "None":
            label = "Unknown"
        totals[label] = totals.get(label, 0) + value

    if portfolio_total == 0:
        return []

    buckets = [
        {
            "label": label,
            "value_chf": value,
            "exposure_pct": value / portfolio_total,
            "is_overconcentrated": (value / portfolio_total) > 0.25,
        }
        for label, value in totals.items()
    ]

    buckets.sort(key=lambda b: b["value_chf"], reverse=True)
    return buckets[:top_n]


__all__ = ["top_risk_buckets"]

"""Utility to compute top positions by CHF value."""

from typing import Iterable, Mapping, List, Dict


def top_positions_by_chf(
    positions: Iterable[Mapping], rates: Mapping[str, float], top_n: int = 10
) -> List[Dict[str, float]]:
    """Return ``top_n`` positions sorted by value in CHF descending.

    Each position mapping must provide ``quantity``, ``current_price``, ``currency``
    and ``instrument`` keys. ``rates`` maps currency codes to ``rate_to_chf``. If
    a non-CHF currency is missing from ``rates`` the position is ignored.
    """

    results: List[Dict[str, float]] = []

    for pos in positions:
        qty = pos.get("quantity", 0)
        price = pos.get("current_price")
        if price is None:
            continue

        value = qty * price
        currency = str(pos.get("currency", "CHF")).upper()
        if currency != "CHF":
            rate = rates.get(currency)
            if rate is None:
                # Skip positions with unknown rate
                continue
            value *= rate

        results.append(
            {
                "instrument": pos.get("instrument", ""),
                "value_chf": value,
                "currency": currency,
            }
        )

    results.sort(key=lambda r: r["value_chf"], reverse=True)
    return results[:top_n]


__all__ = ["top_positions_by_chf"]


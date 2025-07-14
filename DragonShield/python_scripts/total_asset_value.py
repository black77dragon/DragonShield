"""Utility to calculate total asset value in CHF."""

from typing import Iterable, Mapping


def calculate_total_asset_value(positions: Iterable[Mapping], rates: Mapping[str, float]) -> float:
    """Compute sum of position market values converted to CHF.

    Each position mapping must contain ``quantity``, ``current_price`` and ``currency`` keys.
    ``rates`` maps a currency code to its rate_to_chf.
    ``current_price`` may be ``None`` which results in that position contributing 0.
    Raises ``KeyError`` if a non-CHF currency is missing from ``rates``.
    """
    total = 0.0
    for pos in positions:
        qty = pos.get("quantity", 0)
        price = pos.get("current_price")
        if price is None:
            continue
        value = qty * price
        currency = str(pos.get("currency", "CHF")).upper()
        if currency != "CHF":
            rate = rates[currency]
            value *= rate
        total += value
    return total

__all__ = ["calculate_total_asset_value"]

"""Utility functions for asset allocation deviation checks."""

from typing import Literal

Classification = Literal["on_track", "warning", "critical"]


def classify_deviation(deviation_pct: float, tolerance: float) -> Classification:
    """Return deviation classification string."""
    if abs(deviation_pct) > tolerance * 2:
        return "critical"
    if abs(deviation_pct) > tolerance:
        return "warning"
    return "on_track"


def out_of_range(deviation_pct: float, tolerance: float) -> bool:
    """Return True if deviation exceeds tolerance."""
    return abs(deviation_pct) > tolerance

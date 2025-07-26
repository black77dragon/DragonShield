"""Helper functions for allocation deviation logic."""

from typing import Literal

Status = Literal["on_target", "warning", "critical"]

def classify_deviation(deviation: float, tolerance: float) -> Status:
    """Return classification string for a deviation amount.

    Parameters
    ----------
    deviation: float
        Percent difference between actual and target.
    tolerance: float
        Allowed deviation before a warning.
    """
    if abs(deviation) <= tolerance:
        return "on_target"
    if abs(deviation) <= 2 * tolerance:
        return "warning"
    return "critical"

__all__ = ["classify_deviation"]

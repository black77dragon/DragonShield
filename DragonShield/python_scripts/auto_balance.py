"""Helpers for target auto-balance logic."""

from typing import List, Optional


def auto_balance(values: List[float], locked: Optional[List[bool]] = None,
                 target: float = 100.0, precision: float = 0.1) -> List[float]:
    """Distribute the remainder across unlocked values.

    Parameters
    ----------
    values : list of floats
        Current target values.
    locked : list of bools, optional
        True for rows that should not be modified.
    target : float
        Desired total of the values.
    precision : float
        Rounding increment for each value.

    Returns
    -------
    list of floats
        New values after auto-balancing.
    """
    if locked is None:
        locked = [False] * len(values)
    if len(locked) != len(values):
        raise ValueError("locked length must match values length")

    unlocked_indices = [i for i, l in enumerate(locked) if not l]
    if not unlocked_indices:
        return values

    remainder = target - sum(values)
    share = remainder / len(unlocked_indices)

    updated = values[:]
    for idx in unlocked_indices:
        updated[idx] += share
    updated = [round(v / precision) * precision for v in updated]

    diff = target - sum(updated)
    updated[unlocked_indices[-1]] += diff
    return updated

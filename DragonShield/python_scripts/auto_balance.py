from typing import List


def auto_balance(values: List[float], locked: List[bool], total: float = 100.0, precision: float = 0.1) -> List[float]:
    """Return new values auto-balanced to match total.

    Parameters
    ----------
    values : List[float]
        Current values of the child items.
    locked : List[bool]
        True for locked items that should not change.
    total : float, optional
        Desired total sum for all values, by default 100.0.
    precision : float, optional
        Rounding precision, by default 0.1.
    """
    if len(values) != len(locked):
        raise ValueError("values and locked must have same length")

    remainder = total - sum(values)
    unlocked_indices = [i for i, l in enumerate(locked) if not l]
    if not unlocked_indices:
        return values

    share = remainder / len(unlocked_indices)
    new_values = values.copy()
    for idx in unlocked_indices:
        new_values[idx] += share
        new_values[idx] = round(new_values[idx] / precision) * precision

    diff = total - sum(new_values)
    if unlocked_indices:
        last = unlocked_indices[-1]
        new_values[last] = round((new_values[last] + diff) / precision) * precision
    return new_values

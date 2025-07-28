from typing import List


def can_save(parent_value: float, children: List[float], kind: str) -> bool:
    """Validate totals for percent or CHF kind."""
    if kind == "percent":
        return abs(sum(children) - 100.0) < 0.1
    return abs(sum(children) - parent_value) < 1.0


def auto_balance(children: List[float], locked: List[bool], kind: str, parent_value: float) -> List[float]:
    """Distribute remaining value across unlocked children."""
    if len(children) != len(locked):
        raise ValueError("children and locked must be same length")

    if kind == "percent":
        remainder = 100.0 - sum(children)
    else:
        remainder = parent_value - sum(children)

    unlocked_indices = [i for i, l in enumerate(locked) if not l]
    if not unlocked_indices:
        return children

    share = remainder / len(unlocked_indices)
    for i in unlocked_indices:
        children[i] += share
        children[i] = round(children[i] * 10) / 10.0

    target_total = 100.0 if kind == "percent" else parent_value
    diff = target_total - sum(children)
    children[unlocked_indices[-1]] += diff
    children[unlocked_indices[-1]] = round(children[unlocked_indices[-1]] * 10) / 10.0
    return children

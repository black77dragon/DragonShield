"""Utility functions for asset allocation deviation checks.

This module started with simple helpers to classify percentage
deviations.  It now also exposes a small validation framework used to
determine the *validation status* of portfolio, asset-class and
sub‑asset-class targets.  The rules are derived from the specification
outlined in the repository instructions and are intentionally kept
framework agnostic so they can be reused from scripts or unit tests.

The validation follows a three colour scheme:

```
COMPLIANT (🟢)  -> deviation within tolerance
WARNING   (🟠)  -> deviation within twice the tolerance
ERROR     (🔴)  -> deviation above twice the tolerance or invalid input
```
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable, List, Literal


Classification = Literal["on_track", "warning", "critical"]


def classify_deviation(deviation_pct: float, tolerance: float) -> Classification:
    """Return deviation classification string.

    This helper is kept for backwards compatibility with existing
    scripts.  New code should prefer :func:`status_from_deviation`.
    """

    if abs(deviation_pct) > tolerance * 2:
        return "critical"
    if abs(deviation_pct) > tolerance:
        return "warning"
    return "on_track"


def out_of_range(deviation_pct: float, tolerance: float) -> bool:
    """Return ``True`` if deviation exceeds tolerance."""

    return abs(deviation_pct) > tolerance


class Status(Enum):
    """Validation status following traffic light semantics."""

    COMPLIANT = "compliant"
    WARNING = "warning"
    ERROR = "error"

    @property
    def icon(self) -> str:
        return {
            Status.COMPLIANT: "🟢",
            Status.WARNING: "🟠",
            Status.ERROR: "🔴",
        }[self]


def status_from_deviation(deviation: float, tolerance: float) -> Status:
    """Map a deviation against tolerance to a :class:`Status`."""

    if deviation > tolerance * 2:
        return Status.ERROR
    if deviation > tolerance:
        return Status.WARNING
    return Status.COMPLIANT


def worst_status(statuses: Iterable[Status]) -> Status:
    """Return the most severe status from ``statuses``."""

    statuses = list(statuses)
    if any(s is Status.ERROR for s in statuses):
        return Status.ERROR
    if any(s is Status.WARNING for s in statuses):
        return Status.WARNING
    return Status.COMPLIANT


@dataclass
class SubClassTarget:
    """Represents a sub‑asset‑class target."""

    target_percent: float
    target_amount_chf: float

    # tolerance is stored as percent of the parent
    tolerance_percent: float = 0.0
    validation_status: Status = field(default=Status.COMPLIANT, init=False)

    def validate(self) -> Status:
        """Run self‑validation checks and return resulting status."""

        if not (0 <= self.target_percent <= 100) or self.target_amount_chf < 0:
            self.validation_status = Status.ERROR
        else:
            self.validation_status = Status.COMPLIANT
        return self.validation_status


@dataclass
class ClassTarget:
    """Represents an asset‑class target with optional subclasses."""

    target_percent: float
    target_amount_chf: float
    tolerance_percent: float = 0.0
    subclasses: List[SubClassTarget] = field(default_factory=list)
    validation_status: Status = field(default=Status.COMPLIANT, init=False)

    def validate(self) -> Status:
        """Validate this class and all its subclasses."""

        # self-validation
        if not (0 <= self.target_percent <= 100) or self.target_amount_chf < 0:
            return Status.ERROR

        sub_statuses = [sub.validate() for sub in self.subclasses]
        child_worst = worst_status(sub_statuses)

        sum_sub_pc = sum(sub.target_percent for sub in self.subclasses)
        sum_sub_chf = sum(sub.target_amount_chf for sub in self.subclasses)
        dev_pc = abs(sum_sub_pc - 100)
        tol_pc = self.tolerance_percent
        dev_chf = abs(sum_sub_chf - self.target_amount_chf)
        tol_chf = self.target_amount_chf * (self.tolerance_percent / 100)

        agg_status = worst_status(
            [status_from_deviation(dev_pc, tol_pc), status_from_deviation(dev_chf, tol_chf)]
        )

        if child_worst is Status.ERROR:
            self.validation_status = Status.ERROR
        elif child_worst is Status.WARNING:
            self.validation_status = Status.WARNING
        else:
            self.validation_status = agg_status
        return self.validation_status


def validate_portfolio(
    classes: List[ClassTarget],
    portfolio_tol_pct: float,
    total_portfolio_value: float,
) -> Status:
    """Validate an entire portfolio and propagate statuses."""

    class_statuses = [cls.validate() for cls in classes]
    sum_pc = sum(c.target_percent for c in classes)
    dev_pc = abs(sum_pc - 100)

    sum_chf = sum(c.target_amount_chf for c in classes)
    tol_chf = total_portfolio_value * (portfolio_tol_pct / 100)
    dev_chf = abs(sum_chf - total_portfolio_value)

    portfolio_status = worst_status(
        [
            status_from_deviation(dev_pc, portfolio_tol_pct),
            status_from_deviation(dev_chf, tol_chf),
            *class_statuses,
        ]
    )
    return portfolio_status


__all__ = [
    "Classification",
    "Status",
    "SubClassTarget",
    "ClassTarget",
    "classify_deviation",
    "out_of_range",
    "status_from_deviation",
    "validate_portfolio",
    "worst_status",
]


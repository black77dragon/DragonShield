import pytest

from DragonShield.python_scripts.allocation_deviation import (
    ClassTarget,
    Status,
    SubClassTarget,
    status_from_deviation,
    validate_portfolio,
    worst_status,
)


def test_status_from_deviation_thresholds():
    assert status_from_deviation(0, 5) is Status.COMPLIANT
    assert status_from_deviation(5, 5) is Status.COMPLIANT
    assert status_from_deviation(7, 5) is Status.WARNING
    assert status_from_deviation(11, 5) is Status.ERROR


def test_class_and_portfolio_validation():
    # Class 1 with two compliant subclasses
    c1 = ClassTarget(
        target_percent=60,
        target_amount_chf=600,
        tolerance_percent=5,
        subclasses=[
            SubClassTarget(target_percent=40, target_amount_chf=400),
            SubClassTarget(target_percent=60, target_amount_chf=200),
        ],
    )

    # Class 2 with a problematic subclass (percent out of range)
    c2 = ClassTarget(
        target_percent=40,
        target_amount_chf=400,
        tolerance_percent=5,
        subclasses=[
            SubClassTarget(target_percent=120, target_amount_chf=400),
        ],
    )

    status = validate_portfolio([c1, c2], portfolio_tol_pct=5, total_portfolio_value=1000)
    assert status is Status.ERROR
    assert c1.validation_status is Status.COMPLIANT
    assert c2.validation_status is Status.ERROR
    assert c2.subclasses[0].validation_status is Status.ERROR


def test_worst_status():
    assert worst_status([Status.COMPLIANT, Status.WARNING]) is Status.WARNING
    assert worst_status([Status.COMPLIANT, Status.ERROR]) is Status.ERROR

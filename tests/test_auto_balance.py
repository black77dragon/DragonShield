from DragonShield.python_scripts.auto_balance import auto_balance


def test_auto_balance_basic():
    result = auto_balance([15.0, 5.0, 5.0])
    assert abs(sum(result) - 100.0) < 1e-6
    assert all(v >= 0 for v in result)


def test_auto_balance_locked():
    result = auto_balance([50.0, 20.0, 20.0], locked=[True, False, False])
    assert result[0] == 50.0
    assert abs(sum(result) - 100.0) < 1e-6

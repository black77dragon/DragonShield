from DragonShield.python_scripts.auto_balance import auto_balance


def test_auto_balance_percent():
    values = [40.0, 30.0, 20.0]
    locked = [False, False, False]
    result = auto_balance(values, locked, total=100.0, precision=0.1)
    assert round(sum(result), 1) == 100.0


def test_auto_balance_under_allocated():
    values = [30.0, 30.0, 30.0]
    locked = [False, False, False]
    result = auto_balance(values, locked, total=100.0, precision=0.1)
    assert round(sum(result), 1) == 100.0


def test_auto_balance_over_allocated():
    values = [50.0, 30.0, 30.0]
    locked = [False, False, False]
    result = auto_balance(values, locked, total=100.0, precision=0.1)
    assert round(sum(result), 1) == 100.0


def test_auto_balance_chf():
    values = [50000.0, 30000.0, 10000.0]
    locked = [False, True, False]
    result = auto_balance(values, locked, total=100000.0, precision=1.0)
    assert int(sum(result)) == 100000

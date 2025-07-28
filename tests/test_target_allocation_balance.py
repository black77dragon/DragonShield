from DragonShield.python_scripts.target_allocation_balance import can_save, auto_balance


def test_can_save_percent_success():
    assert can_save(0, [50.0, 50.0], "percent")


def test_can_save_percent_under():
    assert not can_save(0, [40.0, 50.0], "percent")


def test_can_save_percent_over():
    assert not can_save(0, [60.0, 50.0], "percent")


def test_auto_balance_chf():
    children = [300.0, 200.0]
    locked = [False, False]
    balanced = auto_balance(children, locked, "amount", 1000.0)
    assert round(sum(balanced)) == 1000

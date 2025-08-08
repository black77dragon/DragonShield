from DragonShield.python_scripts.allocation_deviation import classify_deviation, out_of_range


def test_classify_deviation():
    assert classify_deviation(0.0, 5) == "on_track"
    assert classify_deviation(5.1, 5) == "warning"
    assert classify_deviation(-11.0, 5) == "critical"


def test_out_of_range():
    assert not out_of_range(4.9, 5)
    assert out_of_range(5.0001, 5)

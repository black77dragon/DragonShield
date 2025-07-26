from DragonShield.python_scripts.deviation_utils import classify_deviation


def test_classify_deviation():
    assert classify_deviation(0.02, 0.05) == "on_target"
    assert classify_deviation(-0.06, 0.05) == "warning"
    assert classify_deviation(0.11, 0.05) == "critical"

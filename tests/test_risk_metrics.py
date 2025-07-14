from typing import List
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
import sys
sys.path.insert(0, str(SCRIPT_DIR))

import risk_metrics


def test_calculate_metrics():
    data: List[float] = [0.01, 0.02, -0.005, 0.015, 0.0]
    metrics = risk_metrics.calculate_metrics(data)
    assert isinstance(metrics['sharpe'], float)
    assert isinstance(metrics['sortino'], float)
    assert metrics['max_drawdown'] <= 0
    assert metrics['var'] <= 0
    assert 0 <= metrics['concentration'] <= 1

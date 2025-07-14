# risk_metrics.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial implementation of portfolio risk metrics calculations.

import argparse
import csv
import json
import math
from statistics import mean, pstdev
from typing import Dict, Iterable


def sharpe_ratio(returns: Iterable[float], risk_free_rate: float = 0.0) -> float:
    excess = [r - risk_free_rate / 252 for r in returns]
    std = pstdev(excess)
    if std == 0:
        return 0.0
    return mean(excess) / std * math.sqrt(252)


def sortino_ratio(returns: Iterable[float], risk_free_rate: float = 0.0) -> float:
    downside = [r for r in returns if r < 0]
    if not downside:
        return 0.0
    ds_std = pstdev(downside)
    if ds_std == 0:
        return 0.0
    excess = [r - risk_free_rate / 252 for r in returns]
    return mean(excess) / ds_std * math.sqrt(252)


def max_drawdown(returns: Iterable[float]) -> float:
    cumulative = []
    total = 1.0
    for r in returns:
        total *= 1 + r
        cumulative.append(total)
    peak = cumulative[0] if cumulative else 0
    min_dd = 0.0
    for value in cumulative:
        if value > peak:
            peak = value
        drawdown = (value - peak) / peak
        if drawdown < min_dd:
            min_dd = drawdown
    return min_dd


def value_at_risk(returns: Iterable[float], confidence: float = 0.95) -> float:
    sorted_returns = sorted(returns)
    index = int((1 - confidence) * (len(sorted_returns) - 1))
    return sorted_returns[index]


def risk_concentration(returns: Iterable[float], top_n: int = 5) -> float:
    abs_returns = [abs(r) for r in returns]
    total = sum(abs_returns)
    if total == 0:
        return 0.0
    top_sum = sum(sorted(abs_returns)[-top_n:])
    ratio = top_sum / total
    if ratio > 1:
        ratio = 1.0
    return ratio


def calculate_metrics(returns: Iterable[float], risk_free_rate: float = 0.0) -> Dict[str, float]:
    return {
        "sharpe": sharpe_ratio(returns, risk_free_rate),
        "sortino": sortino_ratio(returns, risk_free_rate),
        "max_drawdown": max_drawdown(returns),
        "var": value_at_risk(returns),
        "concentration": risk_concentration(returns),
    }


def load_returns(csv_path: str, days: int):
    with open(csv_path, newline="") as f:
        reader = csv.reader(f)
        data = [(row[0], float(row[1])) for row in reader]
    data.sort(key=lambda r: r[0])
    returns = [r[1] for r in data]
    if len(returns) > days:
        returns = returns[-days:]
    return returns


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Compute risk metrics")
    parser.add_argument("--csv", required=True, help="CSV file with date and return columns")
    parser.add_argument("--period", default="1Y", choices=["3M", "6M", "1Y", "3Y", "5Y"], help="Lookback period")
    parser.add_argument("--risk-free", type=float, default=0.0, help="Annual risk free rate")
    args = parser.parse_args(argv)

    period_map = {
        "3M": 63,
        "6M": 126,
        "1Y": 252,
        "3Y": 756,
        "5Y": 1260,
    }
    returns = load_returns(args.csv, period_map[args.period])
    metrics = calculate_metrics(returns, args.risk_free)
    print(json.dumps(metrics))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

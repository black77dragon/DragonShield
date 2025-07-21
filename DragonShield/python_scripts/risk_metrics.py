# risk_metrics.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial implementation of portfolio risk metrics calculations.

import argparse
import json
import pandas as pd
import math
from typing import Dict


def sharpe_ratio(returns: pd.Series, risk_free_rate: float = 0.0) -> float:
    excess = returns - risk_free_rate / 252
    if excess.std() == 0:
        return 0.0
    return (excess.mean() / excess.std()) * math.sqrt(252)


def sortino_ratio(returns: pd.Series, risk_free_rate: float = 0.0) -> float:
    downside = returns[returns < 0]
    if downside.std() == 0:
        return 0.0
    excess = returns - risk_free_rate / 252
    return (excess.mean() / downside.std()) * math.sqrt(252)


def max_drawdown(returns: pd.Series) -> float:
    cumulative = (1 + returns).cumprod()
    peak = cumulative.cummax()
    drawdown = (cumulative - peak) / peak
    return drawdown.min()


def value_at_risk(returns: pd.Series, confidence: float = 0.95) -> float:
    return returns.quantile(1 - confidence)


def calculate_metrics(returns: pd.Series, risk_free_rate: float = 0.0) -> Dict[str, float]:
    return {
        "sharpe": sharpe_ratio(returns, risk_free_rate),
        "sortino": sortino_ratio(returns, risk_free_rate),
        "max_drawdown": max_drawdown(returns),
        "var": value_at_risk(returns),
    }


def load_returns(csv_path: str, days: int) -> pd.Series:
    df = pd.read_csv(csv_path, parse_dates=[0])
    df = df.sort_values(df.columns[0])
    returns = df[df.columns[1]].astype(float)
    if len(returns) > days:
        returns = returns.iloc[-days:]
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

from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

from currency_exposure import currency_exposure


def test_grouping_and_conversion():
    positions = [
        {"quantity": 5, "current_price": 100.0, "currency": "USD"},
        {"quantity": 2, "current_price": 50.0, "currency": "CHF"},
        {"quantity": 1, "current_price": 200.0, "currency": "EUR"},
    ]
    rates = {"USD": 0.9, "EUR": 0.95}
    result = currency_exposure(positions, rates, top_n=6)
    by_currency = {r["currency"]: r for r in result}
    assert "USD" in by_currency and "EUR" in by_currency and "CHF" in by_currency
    usd_value = 5 * 100.0 * 0.9
    eur_value = 1 * 200.0 * 0.95
    chf_value = 2 * 50.0
    total = usd_value + eur_value + chf_value
    assert abs(by_currency["USD"]["value_chf"] - usd_value) < 1e-6
    assert abs(by_currency["EUR"]["value_chf"] - eur_value) < 1e-6
    assert abs(by_currency["CHF"]["value_chf"] - chf_value) < 1e-6
    percent_sum = sum(r["percentage"] for r in result)
    assert abs(percent_sum - 100.0) < 1e-6


def test_other_triggered_only_if_more_than_six():
    positions = []
    currencies = ["CHF", "USD", "EUR", "GBP", "JPY", "AUD", "CAD"]
    for idx, cur in enumerate(currencies):
        positions.append({"quantity": 1, "current_price": 10.0 + idx, "currency": cur})
    rates = {cur: 1.0 for cur in currencies if cur != "CHF"}
    result = currency_exposure(positions, rates, top_n=6)
    assert any(r["currency"] == "Other" for r in result)
    assert len(result) == 7  # 6 + Other

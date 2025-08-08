from DragonShield.python_scripts.total_asset_value import calculate_total_asset_value


def test_calculate_total_asset_value():
    positions = [
        {"quantity": 10, "current_price": 5.0, "currency": "CHF"},
        {"quantity": 2, "current_price": 100.0, "currency": "USD"},
        {"quantity": 3, "current_price": 200.0, "currency": "EUR"},
    ]
    rates = {"USD": 0.9, "EUR": 0.95}
    total = calculate_total_asset_value(positions, rates)
    expected = 10 * 5.0 + 2 * 100.0 * 0.9 + 3 * 200.0 * 0.95
    assert abs(total - expected) < 1e-6


def test_missing_rate_raises_key_error():
    positions = [{"quantity": 1, "current_price": 10.0, "currency": "GBP"}]
    rates = {}
    try:
        calculate_total_asset_value(positions, rates)
    except KeyError:
        return
    assert False, "Expected KeyError"

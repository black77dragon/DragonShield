from DragonShield.python_scripts.top_positions import top_positions_by_chf


def test_top_positions_sorted_and_converted():
    positions = [
        {"instrument": "A", "quantity": 5, "current_price": 100.0, "currency": "USD"},
        {"instrument": "B", "quantity": 10, "current_price": 50.0, "currency": "CHF"},
        {"instrument": "C", "quantity": 20, "current_price": 2.0, "currency": "EUR"},
    ]
    rates = {"USD": 0.9, "EUR": 0.95}
    top = top_positions_by_chf(positions, rates, top_n=3)
    values = [p["value_chf"] for p in top]
    assert values == sorted(values, reverse=True)
    assert top[0]["instrument"] == "B"
    assert abs(top[0]["value_chf"] - 10 * 50.0) < 1e-6
    assert top[0]["currency"] == "CHF"


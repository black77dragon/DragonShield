from DragonShield.python_scripts.risk_buckets import top_risk_buckets


def test_risk_buckets_grouping_and_highlight():
    positions = [
        {"quantity": 10, "current_price": 5.0, "currency": "CHF", "sector": "Tech", "issuer": "A"},
        {"quantity": 20, "current_price": 2.0, "currency": "USD", "sector": "Tech", "issuer": "A"},
        {"quantity": 5, "current_price": 100.0, "currency": "EUR", "sector": "Health", "issuer": "B"},
        {"quantity": 1, "current_price": 200.0, "currency": "USD", "sector": "Energy", "issuer": "C"},
    ]
    rates = {"USD": 0.9, "EUR": 0.95}

    buckets = top_risk_buckets(positions, rates, dimension="sector", top_n=2)
    assert buckets[0]["label"] == "Health"
    total = 10*5.0 + 20*2.0*0.9 + 5*100.0*0.95 + 1*200.0*0.9
    health_value = 5*100.0*0.95
    assert abs(buckets[0]["value_chf"] - health_value) < 1e-6
    assert abs(buckets[0]["exposure_pct"] - health_value/total) < 1e-6
    assert buckets[0]["is_overconcentrated"] is True


def test_risk_buckets_asset_class_dimension():
    positions = [
        {"quantity": 1, "current_price": 100.0, "currency": "CHF", "asset_class": "Equity"},
        {"quantity": 2, "current_price": 50.0, "currency": "CHF", "asset_class": "Bond"},
        {"quantity": 3, "current_price": 30.0, "currency": "CHF", "asset_class": "Equity"},
    ]
    rates = {}

    buckets = top_risk_buckets(positions, rates, dimension="asset_class", top_n=2)
    assert buckets[0]["label"] == "Equity"
    total = 1*100.0 + 2*50.0 + 3*30.0
    eq_value = 1*100.0 + 3*30.0
    assert abs(buckets[0]["value_chf"] - eq_value) < 1e-6
    assert abs(buckets[0]["exposure_pct"] - eq_value/total) < 1e-6

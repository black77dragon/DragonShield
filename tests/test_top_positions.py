import math


def compute_top_positions(positions, rates):
    result = []
    for p in positions:
        rate = rates.get(p['currency'], 1.0)
        value = p['quantity'] * p['price'] * rate
        result.append((p['name'], value, p['currency']))
    result.sort(key=lambda x: x[1], reverse=True)
    return result[:10]


def test_top_positions_sorting():
    positions = [
        {'name': 'A', 'quantity': 10, 'price': 100, 'currency': 'CHF'},
        {'name': 'B', 'quantity': 5, 'price': 50, 'currency': 'USD'},
        {'name': 'C', 'quantity': 20, 'price': 10, 'currency': 'EUR'},
    ]
    rates = {'USD': 0.9, 'EUR': 1.2, 'CHF': 1.0}
    top = compute_top_positions(positions, rates)
    assert math.isclose(top[0][1], 2400.0, rel_tol=1e-9)
    assert top[0][0] == 'C'
    assert top[1][0] == 'B'
    assert top[2][0] == 'A'

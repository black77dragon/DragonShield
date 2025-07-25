from DragonShield.python_scripts.instrument_filters import filter_instruments


SAMPLE_DATA = [
    {"name": "A", "type": "Equity ETF", "currency": "USD"},
    {"name": "B", "type": "Bond", "currency": "CHF"},
    {"name": "C", "type": "Equity ETF", "currency": "CHF"},
    {"name": "D", "type": "Equity ETF", "currency": "EUR"},
]


def test_or_logic_single_column():
    result = filter_instruments(SAMPLE_DATA, {"currency": {"USD", "CHF"}})
    names = {r["name"] for r in result}
    assert names == {"A", "B", "C"}


def test_and_logic_across_columns():
    filters = {"currency": {"USD", "CHF"}, "type": {"Equity ETF"}}
    result = filter_instruments(SAMPLE_DATA, filters)
    names = {r["name"] for r in result}
    assert names == {"A", "C"}


def test_no_results_placeholder():
    result = filter_instruments(SAMPLE_DATA, {"currency": {"JPY"}})
    assert result == []

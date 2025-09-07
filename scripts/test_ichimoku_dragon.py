import pandas as pd

from ichimoku_dragon import ichimoku, slope_score


def test_ichimoku_constant_series():
    data = pd.DataFrame({"High": [100] * 60, "Low": [100] * 60, "Close": [100] * 60})
    result = ichimoku(data)
    assert result["Tenkan"].dropna().iloc[-1] == 100
    assert result["Kijun"].dropna().iloc[-1] == 100


def test_slope_score():
    df = pd.DataFrame({
        "Tenkan": [1, 2, 3, 4],
        "Kijun": [1, 2, 3, 4],
    })
    score = slope_score(df, lookback=1)
    assert score == 2

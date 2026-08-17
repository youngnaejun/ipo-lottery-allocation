import pandas as pd
import pytest

from ipo_lottery.features import (
    add_lottery_features,
    expected_skewness_from_percentiles,
    industry_expected_skewness,
)


def test_expected_skewness_known_value():
    assert expected_skewness_from_percentiles(0, 2, 10) == pytest.approx(0.6)


def test_expected_skewness_rejects_zero_percentile_spread():
    with pytest.raises(ValueError, match="P99 equals P1"):
        expected_skewness_from_percentiles(1, 1, 1)


def test_lottery_threshold_is_inclusive(monkeypatch):
    ipos = pd.DataFrame(
        {
            "deal_id": [1, 2],
            "industry_ff30": [5, 6],
            "offer_date": ["2020-01-01", "2020-01-01"],
        }
    )
    fixed = pd.DataFrame(
        {
            "deal_id": [1, 2],
            "p01": [0, 0],
            "p50": [0, 0],
            "p99": [1, 1],
            "expected_skewness": [0.20, 0.199999],
        }
    )
    monkeypatch.setattr("ipo_lottery.features.ipo_expected_skewness", lambda *_: fixed)

    result = add_lottery_features(ipos, pd.DataFrame(), threshold=0.20)

    assert result["lottery_flag"].tolist() == [1, 0]


def test_symmetric_returns_have_zero_expected_skewness():
    returns = pd.DataFrame({"industry_ff30": [5] * 5, "log_return": [-2, -1, 0, 1, 2]})

    result = industry_expected_skewness(returns)

    assert result.loc[0, "expected_skewness"] == pytest.approx(0.0)

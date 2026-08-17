"""Lottery-preference feature construction."""

import numpy as np
import pandas as pd


def expected_skewness_from_percentiles(p01: float, p50: float, p99: float) -> float:
    """Compute the Green-Hwang expected-skewness proxy from three percentiles."""
    spread = p99 - p01
    if np.isclose(spread, 0.0):
        raise ValueError("Expected skewness is undefined when P99 equals P1")
    return float(((p99 - p50) - (p50 - p01)) / spread)


def industry_expected_skewness(returns: pd.DataFrame) -> pd.DataFrame:
    """Calculate expected skewness from pooled log returns by FF30 industry."""
    required = {"industry_ff30", "log_return"}
    if missing := required.difference(returns.columns):
        raise ValueError(f"Industry-return fields missing: {sorted(missing)}")
    if returns["log_return"].isna().any():
        raise ValueError("log_return contains missing values")

    quantiles = (
        returns.groupby("industry_ff30")["log_return"]
        .quantile([0.01, 0.50, 0.99])
        .unstack()
        .rename(columns={0.01: "p01", 0.50: "p50", 0.99: "p99"})
        .reset_index()
    )
    quantiles["expected_skewness"] = quantiles.apply(
        lambda row: expected_skewness_from_percentiles(row.p01, row.p50, row.p99), axis=1
    )
    return quantiles


def ipo_expected_skewness(ipos: pd.DataFrame, returns: pd.DataFrame) -> pd.DataFrame:
    """Estimate each IPO's skewness from its industry's prior three calendar months."""
    ipo_required = {"deal_id", "industry_ff30", "offer_date"}
    return_required = {"industry_ff30", "month", "log_return"}
    if missing := ipo_required.difference(ipos.columns):
        raise ValueError(f"IPO feature fields missing: {sorted(missing)}")
    if missing := return_required.difference(returns.columns):
        raise ValueError(f"Industry-return fields missing: {sorted(missing)}")

    market = returns.copy()
    market["month"] = pd.to_datetime(market["month"], errors="raise").dt.to_period("M")
    if market["log_return"].isna().any():
        raise ValueError("log_return contains missing values")

    records: list[dict[str, float | int]] = []
    for ipo in ipos[["deal_id", "industry_ff30", "offer_date"]].itertuples(index=False):
        offer_month = pd.Timestamp(ipo.offer_date).to_period("M")
        window = market.loc[
            market["industry_ff30"].eq(ipo.industry_ff30)
            & market["month"].ge(offer_month - 3)
            & market["month"].lt(offer_month),
            "log_return",
        ]
        if window.empty:
            continue
        p01, p50, p99 = window.quantile([0.01, 0.50, 0.99]).tolist()
        records.append(
            {
                "deal_id": ipo.deal_id,
                "p01": p01,
                "p50": p50,
                "p99": p99,
                "expected_skewness": expected_skewness_from_percentiles(p01, p50, p99),
            }
        )
    return pd.DataFrame.from_records(
        records, columns=["deal_id", "p01", "p50", "p99", "expected_skewness"]
    )


def add_lottery_features(
    ipos: pd.DataFrame, returns: pd.DataFrame, *, threshold: float = 0.20
) -> pd.DataFrame:
    """Attach industry expected skewness and an inclusive-threshold lottery flag."""
    features = ipo_expected_skewness(ipos, returns)
    result = ipos.merge(features, on="deal_id", how="left", validate="one_to_one")
    if result["expected_skewness"].isna().any():
        missing = sorted(result.loc[result["expected_skewness"].isna(), "deal_id"].unique())
        raise ValueError(f"No prior-three-month expected-skewness estimate for deals: {missing}")
    result["lottery_flag"] = result["expected_skewness"].ge(threshold).astype("int8")
    return result

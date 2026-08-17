"""Deterministic cleaning rules for the IPO deal universe."""

import pandas as pd

REQUIRED_COLUMNS = {
    "deal_id",
    "issuer_name",
    "offer_date",
    "cusip",
    "nation",
    "security_type",
    "offer_price",
    "shares_offered",
    "industry_ff30",
}


def clean_ipos(
    frame: pd.DataFrame,
    *,
    nations: tuple[str, ...] = ("US",),
    security_types: tuple[str, ...] = ("COMMON",),
    start_year: int = 1975,
    end_year: int = 2024,
) -> pd.DataFrame:
    """Validate, filter and deduplicate IPO records.

    Duplicate issuer-date records occur in SDC when a deal has multiple share
    classes. The stable rule retains the lowest deal identifier and records one
    row per issuer-date pair.
    """
    missing_columns = REQUIRED_COLUMNS.difference(frame.columns)
    if missing_columns:
        raise ValueError(f"Missing required columns: {sorted(missing_columns)}")

    result = frame.copy()
    required_values = sorted(REQUIRED_COLUMNS)
    if result[required_values].isna().any().any():
        bad = result.index[result[required_values].isna().any(axis=1)].tolist()
        raise ValueError(f"Missing values in required fields at rows: {bad}")

    result["offer_date"] = pd.to_datetime(result["offer_date"], errors="raise", format="mixed")
    result["offer_price"] = pd.to_numeric(result["offer_price"], errors="raise")
    result["shares_offered"] = pd.to_numeric(result["shares_offered"], errors="raise")
    result["industry_ff30"] = pd.to_numeric(result["industry_ff30"], errors="raise").astype(int)
    result["nation"] = result["nation"].str.upper().str.strip()
    result["security_type"] = result["security_type"].str.upper().str.strip()

    valid = (
        result["nation"].isin(nations)
        & result["security_type"].isin(security_types)
        & result["offer_price"].gt(0)
        & result["shares_offered"].gt(0)
        & result["offer_date"].dt.year.between(start_year, end_year)
    )
    result = result.loc[valid].sort_values("deal_id")
    result = result.drop_duplicates(["issuer_name", "offer_date"], keep="first")
    return result.sort_values(["offer_date", "deal_id"]).reset_index(drop=True)

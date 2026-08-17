"""Small public-data summaries used to verify the end-to-end pipeline."""

import pandas as pd


def summarise_allocation(ipos: pd.DataFrame) -> pd.DataFrame:
    """Summarise IPO counts and proceeds by lottery classification."""
    required = {"lottery_flag", "offer_price", "shares_offered"}
    if missing := required.difference(ipos.columns):
        raise ValueError(f"Analysis fields missing: {sorted(missing)}")
    data = ipos.assign(proceeds=ipos["offer_price"] * ipos["shares_offered"])
    return (
        data.groupby("lottery_flag", as_index=False)
        .agg(ipo_count=("deal_id", "size"), total_proceeds=("proceeds", "sum"))
        .sort_values("lottery_flag")
        .reset_index(drop=True)
    )


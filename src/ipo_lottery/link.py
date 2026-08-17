"""Auditable identifier resolution across IPO and market-data sources."""

import pandas as pd


def resolve_links(
    ipos: pd.DataFrame, candidates: pd.DataFrame
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Select the highest-scoring exact-CUSIP candidate and report unmatched IPOs."""
    ipo_required = {"deal_id", "cusip"}
    candidate_required = {"deal_id", "candidate_cusip", "permno", "link_score"}
    if missing := ipo_required.difference(ipos.columns):
        raise ValueError(f"IPO link fields missing: {sorted(missing)}")
    if missing := candidate_required.difference(candidates.columns):
        raise ValueError(f"Candidate link fields missing: {sorted(missing)}")

    merged = ipos[["deal_id", "cusip"]].merge(candidates, on="deal_id", how="left")
    exact = merged.loc[merged["cusip"] == merged["candidate_cusip"]].copy()
    exact["link_score"] = pd.to_numeric(exact["link_score"], errors="raise")
    exact = exact.sort_values(["deal_id", "link_score", "permno"], ascending=[True, False, True])
    selected = exact.drop_duplicates("deal_id", keep="first")

    linked = ipos.merge(selected[["deal_id", "permno", "link_score"]], on="deal_id", how="inner")
    unmatched = ipos.loc[~ipos["deal_id"].isin(linked["deal_id"])].copy()
    unmatched["unmatched_reason"] = "no exact CUSIP candidate"
    return linked.reset_index(drop=True), unmatched.reset_index(drop=True)


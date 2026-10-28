"""Build an auditable SDC industry-name -> SIC4 -> FF30 fallback crosswalk.

The existing CRSP SIC and pre-filing Compustat SICH remain the preferred
industry sources.  This script only builds a fallback for filings for which
those sources are unavailable, with separate conservative and extended
confidence thresholds.
"""

from __future__ import annotations

import hashlib
import re
import unicodedata
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(r"@RUN_ROOT@")  # run folder (filled in by workflow/tools/materialise.py)
INPUT = ROOT / "master" / "filing_completion_analysis.sas7bdat"
OFFICIAL = ROOT / "raw" / "reference" / "census_sic88_97.txt"
OUT = ROOT / "stata_output" / "additional_tests" / "completion_industry_crosswalk"
OUT.mkdir(parents=True, exist_ok=True)

CENSUS_URL = (
    "https://www2.census.gov/programs-surveys/cbp/technical-documentation/"
    "records-layouts/sic-code-descriptions/sic88_97.txt"
)


def normalize_title(value: str) -> str:
    text = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode()
    text = text.lower().replace("&", " and ")
    substitutions = {
        r"\bn\.?e\.?c\.?\b": " not elsewhere classified ",
        r"\bmisc\.?\b": " miscellaneous ",
        r"\bexc\.?\b": " except ",
        r"\bequip\.?\b": " equipment ",
        r"\bmfrs?\.?\b": " manufacturers ",
        r"\bsvc?s?\.?\b": " services ",
    }
    for pattern, replacement in substitutions.items():
        text = re.sub(pattern, replacement, text)
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


def ff30(sic: float | int | None) -> float:
    if sic is None or pd.isna(sic):
        return np.nan
    s = int(sic)
    if s <= 99:
        return np.nan
    between = lambda lo, hi: lo <= s <= hi
    if (between(100, 299) or between(700, 799) or between(910, 919)
            or between(2000, 2046) or s == 2048 or between(2050, 2063)
            or between(2064, 2068) or between(2070, 2079)
            or between(2086, 2087) or between(2090, 2092)
            or between(2095, 2099)):
        return 1
    if s in {2080, 2082, 2083, 2084, 2085}: return 2
    if between(2100, 2199): return 3
    if (between(920, 999) or between(3650, 3652) or s == 3732
            or between(3930, 3931) or between(3940, 3949)
            or between(7800, 7841) or between(7900, 7933)
            or between(7940, 7949) or s in {7980, 7990, 7999}): return 4
    if between(2700, 2799) or s == 3993: return 5
    if (s == 2047 or between(2391, 2392) or between(2510, 2519)
            or between(2590, 2599) or between(2840, 2844)
            or between(3160, 3172) or between(3190, 3199)
            or s in {3229, 3260, 3262, 3263, 3269, 3230, 3231}
            or between(3630, 3639) or between(3750, 3751)
            or s in {3800, 3860, 3861} or between(3870, 3873)
            or s in {3910, 3911, 3914, 3915} or between(3960, 3962)
            or s in {3991, 3995}): return 6
    if (between(2300, 2390) or between(3020, 3021)
            or between(3100, 3111) or between(3130, 3131)
            or between(3140, 3151) or between(3963, 3965)): return 7
    if (s in {2830, 2831, 2833, 2834, 2835, 2836, 3693}
            or between(3840, 3851) or between(8000, 8099)): return 8
    if between(2800, 2829) or between(2850, 2899): return 9
    if (between(2200, 2284) or between(2290, 2299)
            or between(2393, 2395) or between(2397, 2399)): return 10
    if (between(800, 899) or between(1500, 1549) or between(1600, 1799)
            or between(2400, 2439) or between(2450, 2459)
            or between(2490, 2499) or between(2660, 2661)
            or between(2950, 2952) or s == 3200 or between(3210, 3211)
            or between(3240, 3275) or between(3280, 3281)
            or between(3290, 3299) or between(3420, 3452)
            or between(3490, 3499) or s == 3996): return 11
    if between(3300, 3399): return 12
    if s == 3400 or s in {3443, 3444} or between(3460, 3479) or between(3510, 3599): return 13
    if (s == 3600 or between(3610, 3613) or between(3620, 3621)
            or between(3623, 3629) or between(3640, 3646)
            or between(3648, 3649) or s == 3660 or between(3690, 3692)
            or s == 3699): return 14
    if (s in {2296, 2396} or between(3010, 3011)
            or s in {3537, 3647, 3694} or between(3700, 3716)
            or between(3790, 3792) or s == 3799): return 15
    if (between(3720, 3721) or between(3723, 3725)
            or between(3728, 3731) or between(3740, 3743)): return 16
    if between(1000, 1119) or between(1400, 1499): return 17
    if between(1200, 1299): return 18
    if (between(1300, 1339) or between(1370, 1389)
            or between(2900, 2912) or between(2990, 2999)): return 19
    if between(4900, 4942): return 20
    if between(4800, 4899): return 21
    if (between(7020, 7021) or between(7030, 7033)
            or between(7200, 7299) or between(7300, 7399)
            or between(7500, 7549) or between(7600, 7641)
            or between(7690, 7699) or between(8100, 8499)
            or between(8600, 8748) or between(8800, 8999)): return 22
    if (between(3570, 3579) or s == 3622 or between(3661, 3669)
            or between(3670, 3695) or between(3810, 3812)
            or between(3820, 3827) or s == 3829
            or between(3830, 3839) or s == 7373): return 23
    if (between(2440, 2449) or between(2520, 2549)
            or between(2600, 2699) or between(2760, 2761)
            or between(3220, 3221) or between(3410, 3412)
            or between(3950, 3955)): return 24
    if (between(4000, 4013) or between(4040, 4049)
            or between(4100, 4199) or between(4200, 4231)
            or between(4240, 4249) or between(4400, 4789)): return 25
    if between(5000, 5199): return 26
    if between(5200, 5799) or between(5900, 5999): return 27
    if (between(5800, 5819) or between(5820, 5829)
            or between(5890, 5899) or between(7000, 7019)
            or between(7040, 7049) or s == 7213): return 28
    if between(6000, 6799): return 29
    if between(4950, 4961) or s in {4970, 4971, 4990, 4991}: return 30
    return np.nan


def load_official() -> pd.DataFrame:
    rows = []
    for line in OFFICIAL.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^(\d{4})\s{2,}(.+?)\s*$", line)
        if not match:
            continue
        code = int(match.group(1))
        title = match.group(2).strip()
        rows.append((code, title, normalize_title(title), ff30(code)))
    official = pd.DataFrame(rows, columns=["official_sic4", "official_title", "official_norm", "official_ff30"])
    official = official.drop_duplicates(["official_sic4", "official_title"])
    return official


def stable_holdout(value: str) -> bool:
    digest = hashlib.sha256(str(value).encode("utf-8")).hexdigest()
    return int(digest[:8], 16) % 5 == 0


def modal_stats(frame: pd.DataFrame, key: str, value: str, prefix: str) -> pd.DataFrame:
    grouped = frame.groupby([key, value]).size().rename("n").reset_index()
    if grouped.empty:
        return pd.DataFrame(columns=[key, f"{prefix}_modal", f"{prefix}_n", f"{prefix}_total", f"{prefix}_purity"])
    totals = grouped.groupby(key)["n"].sum().rename(f"{prefix}_total")
    modal = (
        grouped.sort_values([key, "n", value], ascending=[True, False, True])
        .drop_duplicates(key)
        .set_index(key)
        .rename(columns={value: f"{prefix}_modal", "n": f"{prefix}_n"})
        .join(totals)
        .reset_index()
    )
    modal[f"{prefix}_purity"] = modal[f"{prefix}_n"] / modal[f"{prefix}_total"]
    return modal


def best_official(component_norm: str, official: pd.DataFrame) -> tuple[int, str, float, float]:
    exact = official[official["official_norm"] == component_norm]
    if not exact.empty:
        row = exact.sort_values("official_sic4").iloc[0]
        return int(row.official_sic4), row.official_title, 1.0, row.official_ff30
    scores = official["official_norm"].map(lambda title: SequenceMatcher(None, component_norm, title).ratio())
    idx = scores.idxmax()
    row = official.loc[idx]
    return int(row.official_sic4), row.official_title, float(scores.loc[idx]), row.official_ff30


def build_component_crosswalk(data: pd.DataFrame, train: pd.DataFrame, official: pd.DataFrame) -> pd.DataFrame:
    exploded = data[["deal_key", "status_harmonised", "industry_text"]].copy()
    exploded["component_raw"] = exploded["industry_text"].str.split(";")
    exploded = exploded.explode("component_raw")
    exploded["component_raw"] = exploded["component_raw"].fillna("").str.strip()
    exploded = exploded[exploded["component_raw"].ne("")]
    exploded["component_norm"] = exploded["component_raw"].map(normalize_title)

    counts = exploded.groupby(["component_raw", "component_norm"]).agg(
        filing_n=("deal_key", "size"),
        completed_n=("status_harmonised", lambda x: int((x == "completed_live").sum())),
        withdrawn_n=("status_harmonised", lambda x: int((x == "withdrawn_cancelled").sum())),
        postponed_n=("status_harmonised", lambda x: int((x == "postponed").sum())),
    ).reset_index()

    primary_counts = data[data["first_norm"].ne("")].groupby("first_norm").agg(
        primary_filing_n=("deal_key", "size"),
        primary_completed_n=("status_harmonised", lambda x: int((x == "completed_live").sum())),
        primary_withdrawn_n=("status_harmonised", lambda x: int((x == "withdrawn_cancelled").sum())),
        primary_postponed_n=("status_harmonised", lambda x: int((x == "postponed").sum())),
    ).reset_index()
    counts = counts.merge(primary_counts, left_on="component_norm", right_on="first_norm", how="left").drop(columns=["first_norm"])
    for column in ["primary_filing_n", "primary_completed_n", "primary_withdrawn_n", "primary_postponed_n"]:
        counts[column] = counts[column].fillna(0).astype(int)

    train_first = train.copy()
    sic_stats = modal_stats(train_first, "first_norm", "siccd_int", "empirical_sic")
    ff_stats = modal_stats(train_first, "first_norm", "ff30_int", "empirical_ff30")
    counts = counts.merge(sic_stats, left_on="component_norm", right_on="first_norm", how="left").drop(columns=["first_norm"], errors="ignore")
    counts = counts.merge(ff_stats, left_on="component_norm", right_on="first_norm", how="left").drop(columns=["first_norm"], errors="ignore")

    official_matches = [best_official(value, official) for value in counts["component_norm"]]
    counts[["official_sic4", "official_title", "text_score", "official_ff30"]] = pd.DataFrame(official_matches, index=counts.index)
    counts["official_empirical_ff30_agree"] = np.where(
        counts["empirical_ff30_modal"].notna(),
        counts["official_ff30"] == counts["empirical_ff30_modal"],
        np.nan,
    )

    def recommend(row):
        emp_n = 0 if pd.isna(row.empirical_ff30_total) else row.empirical_ff30_total
        emp_p = 0 if pd.isna(row.empirical_ff30_purity) else row.empirical_ff30_purity
        agree = row.official_empirical_ff30_agree == 1
        if row.text_score == 1.0 and (emp_n < 3 or agree):
            return row.official_sic4, row.official_ff30, "official_exact", "high", ""
        if row.text_score >= 0.94 and (emp_n < 3 or agree):
            return row.official_sic4, row.official_ff30, "official_fuzzy", "high", ""
        if emp_n >= 5 and emp_p >= 0.80:
            return row.empirical_sic_modal, row.empirical_ff30_modal, "empirical_first_label", "high", "Official text match disagrees or is weak"
        if row.text_score >= 0.88 and agree:
            return row.official_sic4, row.official_ff30, "official_fuzzy", "medium", "Review wording difference"
        if emp_n >= 3 and emp_p >= 0.70:
            return row.empirical_sic_modal, row.empirical_ff30_modal, "empirical_first_label", "medium", "Moderate empirical agreement"
        return np.nan, np.nan, "unresolved", "review", "Manual review required"

    recs = [recommend(row) for row in counts.itertuples(index=False)]
    counts[["recommended_sic4", "recommended_ff30", "match_method", "confidence", "decision_note"]] = pd.DataFrame(recs, index=counts.index)
    counts["review_flag"] = (counts["confidence"] == "review").astype(int)
    counts["source_url"] = CENSUS_URL
    return counts.sort_values(
        ["review_flag", "primary_filing_n", "filing_n", "component_raw"],
        ascending=[True, False, False, True],
    )


def build_full_crosswalk(data: pd.DataFrame, train: pd.DataFrame, components: pd.DataFrame) -> pd.DataFrame:
    base = data.groupby(["industry_text", "industry_norm"]).agg(
        filing_n=("deal_key", "size"),
        completed_n=("status_harmonised", lambda x: int((x == "completed_live").sum())),
        withdrawn_n=("status_harmonised", lambda x: int((x == "withdrawn_cancelled").sum())),
        postponed_n=("status_harmonised", lambda x: int((x == "postponed").sum())),
    ).reset_index()
    sic_stats = modal_stats(train, "industry_norm", "siccd_int", "full_sic")
    ff_stats = modal_stats(train, "industry_norm", "ff30_int", "full_ff30")
    base = base.merge(sic_stats, on="industry_norm", how="left").merge(ff_stats, on="industry_norm", how="left")

    comp_lookup = components.drop_duplicates("component_norm").set_index("component_norm").to_dict("index")
    recommendations = []
    for row in base.itertuples(index=False):
        raw_components = [part.strip() for part in row.industry_text.split(";") if part.strip()]
        component_rows = [comp_lookup.get(normalize_title(part)) for part in raw_components]
        mapped = [r for r in component_rows if r and pd.notna(r["recommended_ff30"])]
        mapped_ffs = {int(r["recommended_ff30"]) for r in mapped}
        all_high = bool(mapped) and all(r["confidence"] == "high" for r in mapped)
        all_official_exact = (
            bool(mapped)
            and len(mapped) == len(raw_components)
            and all(r["match_method"] == "official_exact" for r in mapped)
        )
        full_n = 0 if pd.isna(row.full_ff30_total) else row.full_ff30_total
        full_p = 0 if pd.isna(row.full_ff30_purity) else row.full_ff30_purity
        if full_n >= 5 and full_p >= 0.90:
            recommendations.append((row.full_sic_modal, row.full_ff30_modal, "empirical_full_string", "high", len(raw_components), len(mapped), ""))
        elif full_n >= 3 and full_p >= 0.80:
            recommendations.append((row.full_sic_modal, row.full_ff30_modal, "empirical_full_string", "medium", len(raw_components), len(mapped), "Moderate full-string support"))
        elif mapped and len(mapped_ffs) == 1:
            method = "component_consensus_exact" if all_official_exact else "component_consensus"
            recommendations.append((mapped[0]["recommended_sic4"], next(iter(mapped_ffs)), method, "medium", len(raw_components), len(mapped), "Component-based robustness mapping"))
        elif full_n >= 2 and full_p >= 0.75:
            recommendations.append((row.full_sic_modal, row.full_ff30_modal, "empirical_full_string", "medium", len(raw_components), len(mapped), "Limited training support"))
        else:
            recommendations.append((np.nan, np.nan, "unresolved", "review", len(raw_components), len(mapped), "Conflicting or unresolved components"))
    base[["recommended_sic4", "recommended_ff30", "match_method", "confidence", "component_n", "mapped_component_n", "decision_note"]] = pd.DataFrame(recommendations, index=base.index)
    base["review_flag"] = (base["confidence"] == "review").astype(int)
    return base.sort_values(["review_flag", "filing_n", "industry_text"], ascending=[True, False, True])


def predict(data: pd.DataFrame, components: pd.DataFrame) -> pd.DataFrame:
    """Assign the primary industry from the first SDC SIC description.

    SDC defines the first item in the semicolon-delimited All SIC field as the
    issuer/borrower's primary SIC.  Later items describe secondary lines of
    business and therefore must not vote on the primary industry assignment.
    """
    confidence_rank = {"high": 0, "medium": 1, "review": 2}
    lookup_source = components.copy()
    lookup_source["confidence_rank"] = lookup_source["confidence"].map(confidence_rank).fillna(9)
    lookup_source = (
        lookup_source.sort_values(
            ["component_norm", "confidence_rank", "filing_n"],
            ascending=[True, True, False],
        )
        .drop_duplicates("component_norm")
    )
    lookup = lookup_source.set_index("component_norm")[["recommended_sic4", "recommended_ff30", "match_method", "confidence"]]
    result = data.merge(lookup, left_on="first_norm", right_index=True, how="left")
    result["fallback_ff30_conservative"] = np.where(result["confidence"] == "high", result["recommended_ff30"], np.nan)
    result["fallback_ff30_extended"] = np.where(result["confidence"].isin(["high", "medium"]), result["recommended_ff30"], np.nan)
    result["ff30_conservative"] = result["ff30"].where(result["ff30"].between(1, 29), result["fallback_ff30_conservative"])
    result["ff30_extended"] = result["ff30"].where(result["ff30"].between(1, 29), result["fallback_ff30_extended"])
    result["industry_source_conservative"] = np.where(
        result["ff30"].between(1, 29), result["sic_source"],
        np.where(result["fallback_ff30_conservative"].notna(), "SDC_PRIMARY_LABEL_CROSSWALK", "MISSING")
    )
    result["industry_source_extended"] = np.where(
        result["ff30"].between(1, 29), result["sic_source"],
        np.where(result["fallback_ff30_extended"].notna(), "SDC_PRIMARY_LABEL_CROSSWALK", "MISSING")
    )
    return result


def qa_table(predicted: pd.DataFrame, holdout: pd.DataFrame, holdout_pred: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for status, group in predicted.groupby("status_harmonised"):
        rows.append({
            "section": "status_coverage", "group": status,
            "n": len(group),
            "original_n": int(group["ff30"].between(1, 29).sum()),
            "original_rate": float(group["ff30"].between(1, 29).mean()),
            "conservative_n": int(group["ff30_conservative"].between(1, 29).sum()),
            "conservative_rate": float(group["ff30_conservative"].between(1, 29).mean()),
            "extended_n": int(group["ff30_extended"].between(1, 29).sum()),
            "extended_rate": float(group["ff30_extended"].between(1, 29).mean()),
        })
    truth = holdout.set_index("deal_key")["ff30_int"]
    hp = holdout_pred.set_index("deal_key")
    for spec, col in [("conservative", "fallback_ff30_conservative"), ("extended", "fallback_ff30_extended")]:
        common = hp[col].notna() & truth.reindex(hp.index).notna()
        rows.append({
            "section": "holdout_validation", "group": spec,
            "n": int(common.sum()),
            "original_n": np.nan, "original_rate": np.nan,
            "conservative_n": np.nan,
            "conservative_rate": float((hp.loc[common, col] == truth.reindex(hp.index)[common]).mean()) if common.any() else np.nan,
            "extended_n": np.nan,
            "extended_rate": float(common.mean()),
        })
    truth_aligned = truth.reindex(hp.index)
    for method, group in hp.groupby("match_method", dropna=False):
        common = group["fallback_ff30_extended"].notna() & truth_aligned.reindex(group.index).notna()
        rows.append({
            "section": "holdout_by_method", "group": str(method),
            "n": int(common.sum()),
            "original_n": np.nan, "original_rate": np.nan,
            "conservative_n": np.nan,
            "conservative_rate": float((group.loc[common, "fallback_ff30_extended"] == truth_aligned.reindex(group.index)[common]).mean()) if common.any() else np.nan,
            "extended_n": np.nan,
            "extended_rate": float(common.mean()) if len(group) else np.nan,
        })
    return pd.DataFrame(rows)


def main() -> None:
    data = pd.read_sas(INPUT, format="sas7bdat", encoding="utf-8")
    data["deal_key"] = data["deal_key"].astype(str)
    data["industry_text"] = data["SIC"].fillna("").astype(str).str.strip()
    data["industry_norm"] = data["industry_text"].map(normalize_title)
    data["first_raw"] = data["industry_text"].str.split(";").str[0].str.strip()
    data["first_norm"] = data["first_raw"].map(normalize_title)
    data["siccd_int"] = pd.to_numeric(data["siccd"], errors="coerce")
    data["ff30_int"] = pd.to_numeric(data["ff30"], errors="coerce")

    linked_completed = data[
        (data["status_harmonised"] == "completed_live")
        & data["ff30_int"].between(1, 29)
        & data["siccd_int"].notna()
        & data["industry_text"].ne("")
    ].copy()
    holdout_mask = linked_completed["deal_key"].map(stable_holdout)
    train = linked_completed[~holdout_mask].copy()
    holdout = linked_completed[holdout_mask].copy()
    official = load_official()

    components_train = build_component_crosswalk(data, train, official)
    full_train = build_full_crosswalk(data, train, components_train)
    holdout_pred = predict(holdout.drop(columns=["ff30"], errors="ignore").assign(ff30=np.nan), components_train)

    components = build_component_crosswalk(data, linked_completed, official)
    full = build_full_crosswalk(data, linked_completed, components)
    predicted = predict(data, components)
    qa = qa_table(predicted, holdout, holdout_pred)

    components.to_csv(OUT / "SDC_Industry_Component_Crosswalk.csv", index=False)
    full.to_csv(OUT / "SDC_Industry_FullString_Crosswalk.csv", index=False)
    qa.to_csv(OUT / "SDC_Industry_Crosswalk_QA.csv", index=False)
    deal_cols = [
        "deal_key", "status_harmonised", "industry_text", "industry_norm", "first_raw", "first_norm",
        "ff30", "siccd", "sic_source", "recommended_sic4", "recommended_ff30",
        "match_method", "confidence", "fallback_ff30_conservative",
        "fallback_ff30_extended", "ff30_conservative", "ff30_extended",
        "industry_source_conservative", "industry_source_extended",
    ]
    predicted[deal_cols].to_csv(OUT / "SDC_Industry_Deal_Mapping.csv", index=False)
    predicted[deal_cols].to_stata(OUT / "SDC_Industry_Deal_Mapping.dta", write_index=False, version=118)

    print(qa.to_string(index=False))
    print("component confidence", components["confidence"].value_counts().to_dict())
    print("full-string confidence", full["confidence"].value_counts().to_dict())


if __name__ == "__main__":
    main()

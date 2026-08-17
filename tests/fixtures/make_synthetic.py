"""Generate deterministic, clearly synthetic inputs matching the production schema."""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


def make_synthetic(seed: int = 20260816) -> dict[str, pd.DataFrame]:
    rng = np.random.default_rng(seed)
    ipos = pd.DataFrame(
        [
            [1001, "Synthetic Alpha", "2019-03-15", "111111AA", "US", "COMMON", 12, 1_000_000, 5],
            [1002, "Synthetic Beta", "2020-06-10", "222222AA", "US", "COMMON", 16, 800_000, 8],
            [1003, "Synthetic Gamma", "2021-09-20", "333333AA", "US", "COMMON", 10, 1_200_000, 5],
            [1004, "Synthetic Delta", "2022-02-11", "444444AA", "US", "COMMON", 20, 600_000, 8],
            [1005, "Synthetic Epsilon", "2023-05-08", "555555AA", "US", "COMMON", 14, 900_000, 5],
            [1006, "Synthetic Zeta", "2024-04-19", "666666AA", "US", "COMMON", 18, 700_000, 8],
            # Real-data edge case: duplicate issuer/date caused by multiple share classes.
            [1016, "Synthetic Zeta", "2024-04-19", "666666AB", "US", "COMMON", 18, 50_000, 8],
            [1007, "Synthetic Foreign", "2020-01-02", "777777AA", "CA", "COMMON", 11, 500_000, 5],
        ],
        columns=[
            "deal_id",
            "issuer_name",
            "offer_date",
            "cusip",
            "nation",
            "security_type",
            "offer_price",
            "shares_offered",
            "industry_ff30",
        ],
    )
    links = pd.DataFrame(
        [
            [1001, "111111AA", 50001, 100, "CUSIP"],
            [1001, "111111AA", 59999, 70, "CUSIP"],
            [1002, "222222AA", 50002, 100, "CUSIP"],
            [1003, "333333AA", 50003, 95, "CUSIP"],
            [1004, "444444ZZ", 50004, 80, "name"],
            [1005, "555555AA", 50005, 100, "CUSIP"],
            [1006, "666666AA", 50006, 100, "CUSIP"],
        ],
        columns=["deal_id", "candidate_cusip", "permno", "link_score", "link_source"],
    )

    months = pd.date_range("2018-12-01", "2024-03-01", freq="MS")
    records: list[dict[str, object]] = []
    for industry in (5, 8):
        base = rng.normal(0.01, 0.07, size=len(months))
        if industry == 8:
            base[-2:] = [0.35, 0.65]
        records.extend(
            {
                "industry_ff30": industry,
                "month": month.strftime("%Y-%m-%d"),
                "log_return": round(float(value), 6),
            }
            for month, value in zip(months, base, strict=True)
        )
    returns = pd.DataFrame(records)
    return {"ipos": ipos, "link_candidates": links, "industry_returns": returns}


def write_synthetic(output_dir: str | Path, seed: int = 20260816) -> None:
    destination = Path(output_dir)
    destination.mkdir(parents=True, exist_ok=True)
    for name, frame in make_synthetic(seed).items():
        frame.to_csv(destination / f"{name}.csv", index=False)
        print(f"wrote {len(frame):,} synthetic rows -> {destination / f'{name}.csv'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="data/synthetic")
    parser.add_argument("--seed", type=int, default=20260816)
    args = parser.parse_args()
    write_synthetic(args.output_dir, args.seed)


if __name__ == "__main__":
    main()

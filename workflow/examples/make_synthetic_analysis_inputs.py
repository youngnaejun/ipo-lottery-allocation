"""Generate synthetic table-input datasets for trying the analysis module (workflow/run_analysis.sh).

Usage: make_synthetic_analysis_inputs.py <out_dir> [--ipos 1500] [--start 1983] [--end 2024] [--seed 2026]

Writes ipo_returns.dta, revisions.dta, t4_panel.dta and t5_panel.dta with every column of
workflow/analysis/table_input_schema.json. All values are random draws: they contain no observed records and no
information from licensed data, and the resulting estimates have no economic meaning. Their only purpose is to
exercise the Stata, SAS, Word and structural-check steps.
"""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
SCHEMA = json.loads((HERE.parent / "analysis" / "table_input_schema.json").read_text(encoding="utf-8"))
BINARY = {"internet", "NASDAQ", "NYSE", "pure_primary", "VB", "TT_ave", "restored61", "rev_up", "sample_price",
          "sample_sr_full", "sample_proceeds", "sample_rpos", "all_empty", "completed_empty"}
RETURNS = {"r2_bhar_1y", "r2_bhar_3y", "r2_bhar_5y", "r3_bhar_1y", "r3_bhar_3y", "r3_bhar_5y"}


def column(name, n, rng):
    if name in BINARY:
        return rng.binomial(1, 0.4, n).astype(float)
    if name in RETURNS:
        r = np.expm1(rng.normal(0.0, 0.7, n))
        r[rng.random(n) < 0.01] = -1.0  # total losses keep the -100% convention visible
        return r
    if name.startswith("n_") or name.endswith(("_n", "_valid")) or name in {"t12", "age_ritter"}:
        return rng.poisson(3, n).astype(float)
    return rng.normal(0.0, 1.0, n)


def ipo_frame(spec, n, start, end, rng, first_id):
    d = pd.DataFrame({c["name"]: column(c["name"], n, rng) for c in spec["columns"]})
    d["analysis_id"] = np.arange(first_id, first_id + n)
    d["PERMNO"] = 10000 + np.arange(n)
    d["ipo_year"] = rng.integers(start, end + 1, n)
    d["yr"] = d.ipo_year
    d["ff30"] = rng.integers(1, 30, n)
    if "tercile" in d:
        d["tercile"] = np.floor(d.skew1.rank(method="average") * 3 / (d.skew1.count() + 1)) + 1
    d["r0"] = np.expm1(rng.normal(0.1, 0.4, n))
    if "price_adj_imp" in d:
        d["price_adj"] = np.abs(d.price_adj); d["price_adj_imp"] = d.price_adj
    if "rev_signed" in d:
        d["rev_up"] = (d.rev_signed > 0).astype(float)
        d["rpos"] = rng.random(n); d["range_width"] = rng.uniform(0.05, 0.3, n)
        for c in ["sample_price", "sample_sr_full", "sample_proceeds", "sample_rpos"]:
            d[c] = (rng.random(n) < 0.9).astype(float)
    return d


def panel_frame(spec, start, end, rng):
    grid = pd.MultiIndex.from_product([range(1, 30), range((start - 1960) * 4, (end - 1960) * 4 + 4)],
                                      names=["ff30", "time_id"]).to_frame(index=False)
    n = len(grid)
    d = pd.DataFrame({c["name"]: column(c["name"], n, rng) for c in spec["columns"]})
    d["ff30"] = grid.ff30.to_numpy(); d["time_id"] = grid.time_id.to_numpy()
    d["yr"] = d.time_id // 4 + 1960
    if "proceeds" in d:
        d["proceeds"] = rng.gamma(1.0, 50.0, n) * (rng.random(n) < 0.7)
        d["t11"] = np.log1p(d.proceeds)
    if "n_main" in d:
        d["n_main"] = rng.poisson(4, n).astype(float)
    return d


def main():
    a = argparse.ArgumentParser()
    a.add_argument("out_dir", type=Path)
    a.add_argument("--ipos", type=int, default=1500)
    a.add_argument("--start", type=int, default=1983)
    a.add_argument("--end", type=int, default=2024)
    a.add_argument("--seed", type=int, default=2026)
    args = a.parse_args()
    rng = np.random.default_rng(args.seed)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    frames = {
        "ipo_returns.dta": ipo_frame(SCHEMA["ipo_returns.dta"], args.ipos, args.start, args.end, rng, 1),
        "revisions.dta": ipo_frame(SCHEMA["revisions.dta"], int(args.ipos * 0.6), args.start, args.end, rng, 1),
        "t4_panel.dta": panel_frame(SCHEMA["t4_panel.dta"], args.start, args.end, rng),
        "t5_panel.dta": panel_frame(SCHEMA["t5_panel.dta"], args.start, args.end, rng),
    }
    for name, d in frames.items():
        d = d[[c["name"] for c in SCHEMA[name]["columns"]]]
        d.to_stata(args.out_dir / name, write_index=False, version=118)
        print(f"{name}: {len(d)} rows, {d.shape[1]} columns")


if __name__ == "__main__":
    main()

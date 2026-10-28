"""Export the four table-input (analysis) datasets to Stata .dta files, with a round-trip check.

Usage: export_stata_inputs.py <out_dir> <run_root>
  Reads the analysis datasets that run_all.sh built under <run_root>.

Outputs (one row per estimation unit):
  ipo_returns.dta   one row per IPO, boundary-corrected returns -> Tables 1, 2, 3, B1, B2
  revisions.dta     price-revision sample + recovered IPOs  -> Tables 6, 7, B3, B4
  t4_panel.dta      industry-quarter completed IPOs           -> Table 4, IA1, IA2
  t5_panel.dta      industry-quarter filings                  -> Table 5, IA3
The revision frame follows bridge/recovery/build_recovered_inputs.py (revisions()) and the paper's RT estimation
line for line; nothing is re-defined here.
"""
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

out, R = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
corrected = R / "ext/boundary/Expanded_analysis_boundary_corrected.pkl"
expanded_pkl = R / "ext/recovered61-complete/results/Expanded_analysis.pkl"
new61_csv = R / "ext/recovered61-complete/results/Recovered61_revision_variables.csv"
price_dta = R / "stata/price_revision_sample.dta"
share_dta = R / "stata/sharerevision_actual.dta"

FIRM = ['age_ritter', 'coskewness', 'internet', 'NASDAQ', 'NYSE']
DEAL = ['ln_amount_filed_adj1975', 'share_overhang', 'pure_primary', 'VB', 'uw_rank_ave']
IND = ['ind_ret', 'ind_mom', 'ind_vol', 'ind_turn']
manifest = {"run_root": str(R), "files": {}}


def write(df, name, keys):
    path = out / name
    df = df.copy()
    for c in df.columns:  # Stata has no bool dtype
        if df[c].dtype == bool:
            df[c] = df[c].astype("int8")
    df.to_stata(path, write_index=False, version=118)
    back = pd.read_stata(path, convert_categoricals=False, convert_dates=False)
    num = [c for c in df.columns if pd.api.types.is_numeric_dtype(df[c])]
    a = df[num].astype(float).to_numpy()
    b = back[num].astype(float).to_numpy()
    same_missing = bool((np.isnan(a) == np.isnan(b)).all())
    maxdiff = float(np.nanmax(np.abs(a - b))) if a.size else 0.0
    assert same_missing and maxdiff == 0.0, (name, same_missing, maxdiff)
    assert back[keys].duplicated().sum() == 0, (name, "duplicate keys")
    manifest["files"][name] = dict(rows=len(df), columns=len(df.columns), numeric_roundtrip_max_abs_diff=maxdiff,
                                   missing_pattern_identical=same_missing, keys=keys)


# 1. IPO-level returns (setup() of compare_recovered61 plus the Table 2 tercile rule).
d = pd.read_pickle(corrected)
d['analysis_id'] = pd.to_numeric(d.deal_num)
d['price_adj_imp'] = d.price_adj.fillna(0)
d['yr'] = d.ipo_year
d['tercile'] = np.floor(d.skew1.rank(method='average') * 3 / (d.skew1.count() + 1)) + 1
keep = (['analysis_id', 'PERMNO', 'ipo_year', 'yr', 'ff30', 'tercile', 'skew1', 'r0'] + FIRM +
        ['lnproceeds_adj1975', 'price_adj', 'price_adj_imp', 'share_overhang', 'pure_primary', 'VB', 'TT_ave',
         'lagmcsi', 'lagcummktret', 'ipo_vol'] + IND +
        [f'r{k}_bhar_{y}y' for k in (2, 3) for y in (1, 3, 5)])
write(d[keep], "ipo_returns.dta", ["analysis_id"])

# 2. Revisions: compare_recovered61.revisions() 'ex' frame, plus the RT1/RT2 outcomes.
expanded = pd.read_pickle(expanded_pkl)
a = pd.read_stata(price_dta, convert_categoricals=False)
share = pd.read_stata(share_dta, convert_categoricals=False)
a = a.merge(share[['analysis_id', 'tot_first', 'actual_base_total', 'sample_sr_full']], on='analysis_id', how='left',
            validate='one_to_one')
a['sample_price'] = a[['rev_signed', 'skew1', 'mkt_reg_ew', 'mkt_reg_ew_pos'] + FIRM + DEAL + ['lagmcsi', 'ipo_vol'] + IND +
                      ['ipo_year', 'ff30']].notna().all(axis=1)
a['share_revision_raw'] = (a.actual_base_total - a.tot_first) / a.tot_first.where(a.tot_first.gt(0))
a['proceeds_revision'] = (a.oprc * a.actual_base_total - a.initial_midpoint * a.tot_first) / (
    a.initial_midpoint * a.tot_first).where(a.initial_midpoint.gt(0) & a.tot_first.gt(0))
a['sample_proceeds'] = a.sample_sr_full.eq(1) & a.proceeds_revision.notna()
a['yr'] = a.ipo_year
a['ipo_vol'] = a.PERMNO.map(expanded.set_index('PERMNO').ipo_vol)
new = pd.read_csv(new61_csv)
new['yr'] = new.ipo_year
rv = pd.concat([a, new], ignore_index=True)
rv['restored61'] = rv.index >= len(a)
rv['rev_up'] = rv.rev_signed.gt(0).astype(float)
width = rv.file_price_high - rv.file_price_low
rv['rpos'] = (rv.oprc - rv.file_price_low) / width.where(width.gt(0))
rv['range_width'] = width / rv.initial_midpoint.where(width.gt(0) & rv.initial_midpoint.gt(0))
rv['sample_rpos'] = rv.sample_price.eq(1) & rv.r0.notna() & rv.rpos.notna()
for c in ['sample_price', 'sample_sr_full', 'sample_proceeds']:
    rv[c] = rv[c].astype(float).fillna(0).astype(bool)
keep = (['analysis_id', 'PERMNO', 'ipo_year', 'yr', 'ff30', 'restored61', 'skew1', 'r0', 'rev_signed', 'rev_up', 'rpos',
         'range_width', 'share_revision_raw', 'proceeds_revision', 'sample_price', 'sample_sr_full', 'sample_proceeds',
         'sample_rpos', 'mkt_reg_ew', 'mkt_reg_ew_pos', 'lagmcsi', 'lagcummktret', 'ipo_vol'] + FIRM + DEAL + IND)
write(rv[keep], "revisions.dta", ["analysis_id"])

# 3. Industry-quarter panels.
for src, dst in [("T4_input.dta", "t4_panel.dta"), ("T5_input.dta", "t5_panel.dta")]:
    p = pd.read_stata(R / "ext/ppml" / src, convert_categoricals=False)
    write(p, dst, ["ff30", "time_id"])

(out / "export_manifest.json").write_text(json.dumps(manifest, indent=1))
print(json.dumps(manifest, indent=1))

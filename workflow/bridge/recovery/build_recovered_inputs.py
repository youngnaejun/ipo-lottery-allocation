"""Revision variables and panel cohort controls for the IPOs recovered by the filing-link rule.

Adapted from the project's compare_recovered61.py: only its construction steps are kept (revisions() and
panels() below, unchanged in substance). Its diagnostic regressions and its comparisons against archived
paper results and the manuscript file are not part of the public workflow.

Reads (run folder):  ext/recovered61-complete/results/Baseline_analysis.pkl, Expanded_analysis.pkl
                     ext/0928-1002/inputs/price_revision_sample.dta, sharerevision_actual.dta,
                     T4_Panel_With_Candidate_20260925.dta; ext/0928-1002/results/table5_expanded/Input_Panel.dta
                     ext/ipo-20260921-25/t11_design_diag_deals.dta; stata/sdc_fullhistory_parsed_20260903.csv;
                     master/crsp_index_daily.sas7bdat
Writes:              results/Recovered61_revision_variables.csv, Recovered61_current_panel_controls.csv,
                     Updated_panel_deal_controls.pkl
"""
from pathlib import Path
import numpy as np
import pandas as pd
from estimate_tables67 import FIRM, DEAL, IND

R = Path('@RUN_ROOT@/ext/0928-1002')
P = Path('@RUN_ROOT@')
O = Path('@RUN_ROOT@/ext/recovered61-complete/results')
PAPER_CHECKS = @PAPER_CHECKS@ == 1


def sas(name, folder='master'):
    d = pd.read_sas(P / folder / (name + '.sas7bdat'))
    for c in d.select_dtypes(include=['object']).columns:
        d[c] = d[c].map(lambda x: x.decode('cp1252').strip() if isinstance(x, bytes) else x)
    if 'deal_num' in d:
        d['deal_num'] = pd.to_numeric(d.deal_num, errors='raise')
    return d


def setup(d):
    d = d.copy(); d['analysis_id'] = pd.to_numeric(d.deal_num); d['time_id'] = d.analysis_id; d['yr'] = d.ipo_year
    d['price_adj_imp'] = d.price_adj.fillna(0)
    # Period indicators kept as in the source script (the paper's historical period convention).
    for name, lo, hi in [('y9098', 1990, 1998), ('y9900', 1999, 2000), ('y0108', 2001, 2008), ('y0911', 2009, 2011), ('y1219', 2012, 2019), ('y2024', 2020, 2024)]:
        d[name] = d.ipo_year.between(lo, hi).astype(int)
    return d


def revisions(base, expanded):
    a = pd.read_stata(R/'inputs/price_revision_sample.dta', convert_categoricals=False)
    new = expanded.loc[expanded.restored61.eq(1)].copy()
    new['initial_midpoint'] = ((new.file_price_low+new.file_price_high)/2).where(new.file_price_low.gt(0)&new.file_price_high.gt(0))
    new['rev_signed'] = (new.oprc-new.initial_midpoint)/new.initial_midpoint
    def firstnum(x):
        vals = [t for t in str(x).split(';') if t.strip()]
        return pd.to_numeric(vals[0].replace(',', '').replace('$', ''), errors='coerce') if vals else np.nan
    new['amount_filed_mil'] = new.Full_History_Amount_Filed_This_M.map(firstnum)
    new['ln_amount_filed_adj1975'] = np.log((new.amount_filed_mil*new.proceeds_adj1975/new.proceeds_mil).where(new.amount_filed_mil.gt(0)))
    fh = pd.read_csv(P/'stata/sdc_fullhistory_parsed_20260903.csv')
    fh['deal_num'] = pd.to_numeric(fh.sdc_deal, errors='coerce')
    new = new.merge(fh[['deal_num', 'tot_first']], on='deal_num', how='left', validate='one_to_one')
    new['actual_base_total'] = new.primary_shares+new.secondary_shares.fillna(0)
    new['share_revision_raw'] = (new.actual_base_total-new.tot_first)/new.tot_first.where(new.tot_first.gt(0))
    new['proceeds_revision'] = (new.oprc*new.actual_base_total-new.initial_midpoint*new.tot_first)/(new.initial_midpoint*new.tot_first).where(new.initial_midpoint.gt(0)&new.tot_first.gt(0))
    index = sas('crsp_index_daily')
    def regret(row):
        z = index.loc[index.DATE.ge(row.fdate)&index.DATE.lt(row.idate), 'logewretd']
        return np.expm1(z.sum()) if len(z) and row.fdate < row.idate else np.nan
    new['mkt_reg_ew'] = new.apply(regret, axis=1); new['mkt_reg_ew_pos'] = new.mkt_reg_ew.clip(lower=0)
    allvars = ['rev_signed', 'skew1', 'mkt_reg_ew', 'mkt_reg_ew_pos']+FIRM+DEAL+['lagmcsi', 'ipo_vol']+IND+['ipo_year', 'ff30']
    new['sample_price'] = new[allvars].notna().all(axis=1)
    new['sample_sr_full'] = new.sample_price&new.r0.notna()&new.share_revision_raw.notna()
    new['sample_proceeds'] = new.sample_sr_full&new.proceeds_revision.notna()
    new['analysis_id'] = np.arange(int(a.analysis_id.max())+1, int(a.analysis_id.max())+1+len(new)); new['time_id'] = new.analysis_id
    new.to_csv(O/'Recovered61_revision_variables.csv', index=False)


def panels(base, expanded):
    d = pd.read_stata(Path('@RUN_ROOT@/ext/ipo-20260921-25/t11_design_diag_deals.dta'), convert_categoricals=False)
    new = expanded[expanded.restored61.eq(1)].set_index('deal_num')
    dk = pd.to_numeric(d.deal_key); restored = dk.isin(new.index)
    assert restored.sum() == len(new) and (not PAPER_CHECKS or restored.sum() == 61)
    # Recovered deals had outcomes but no cohort controls in the current panels.
    cohort = ['age', 'lnexpected', 'overhang', 'uwrank', 'vcshare', 'primaryshare', 'optimism', 'ipovol']
    print('Recovered current cohort availability', d.loc[restored, cohort].count().to_dict(), flush=True)
    fixed = d.copy()
    maps = {'age': 'age_ritter', 'overhang': 'share_overhang', 'uwrank': 'uw_rank_ave', 'vcshare': 'VB', 'primaryshare': 'pure_primary', 'optimism': 'lagmcsi', 'ipovol': 'ipo_vol'}
    for c, v in maps.items(): fixed.loc[restored, c] = dk[restored].map(new[v]).to_numpy()
    def amount(x):
        parts = [p for p in str(x).split(';') if p.strip()]
        return pd.to_numeric(parts[0].replace(',', '').replace('$', ''), errors='coerce') if parts else np.nan
    examount = np.log((new.Full_History_Amount_Filed_This_M.map(amount)*new.proceeds_adj1975/new.proceeds_mil).where(lambda x: x > 0))
    fixed.loc[restored, 'lnexpected'] = dk[restored].map(examount).to_numpy()
    bvol = expanded.set_index('deal_num').ipo_vol
    oldkey = pd.to_numeric(d.source_deal_num, errors='coerce')
    valid = ~restored&oldkey.isin(bvol.index)
    fixed.loc[valid, 'ipovol'] = oldkey[valid].map(bvol).to_numpy()
    p4 = pd.read_stata(R/'inputs/T4_Panel_With_Candidate_20260925.dta', convert_categoricals=False)
    def replace(p, deals, columns, outcomes=False):
        out = p.copy(); grp = deals.groupby(['ff30', 'time_id'])
        agg = grp[columns].mean().join(grp.size().rename('count')).join(grp.actual.sum().rename('total')).reset_index()
        if outcomes:
            now = out[['ff30', 'time_id']].merge(agg[['ff30', 'time_id', 'count', 'total']], on=['ff30', 'time_id'], how='left').fillna(0)
            out['t11'] = np.log1p(now.total); out['t12'] = now['count']
        agg.time_id += 1
        joined = out[['ff30', 'time_id']].merge(agg, on=['ff30', 'time_id'], how='left')
        empty = joined['count'].isna()&out.time_id.gt(d.time_id.min())
        for c in columns:
            out['l_'+c] = joined[c].to_numpy(); out.loc[empty, 'l_'+c] = 0
        return out
    # Structural check: the deal-level controls rebuild the current Table 4 panel exactly.
    rebuilt = replace(p4, d, cohort, True)
    for c in ['t11', 't12']+['l_'+c for c in cohort]:
        assert np.allclose(rebuilt[c], p4[c], equal_nan=True, atol=1e-10), c
    d.loc[restored].to_csv(O/'Recovered61_current_panel_controls.csv', index=False)
    fixed.to_pickle(O/'Updated_panel_deal_controls.pkl')


def main():
    base = setup(pd.read_pickle(O/'Baseline_analysis.pkl')); expanded = setup(pd.read_pickle(O/'Expanded_analysis.pkl'))
    revisions(base, expanded)
    panels(base, expanded)
    print('Recovered IPOs:', int(expanded.restored61.sum()), flush=True)


if __name__ == '__main__':
    main()

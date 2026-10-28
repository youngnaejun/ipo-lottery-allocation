"""Write ext/recovery/recovery_targets.csv, the input of sas/external/WRDS_Recovered61.sas.

Replaces the deal records that the project's original program embedded. Two kinds of rows:
  recovered61          IPOs listed in Recovered61_audit_records.csv (the filing-link recovery rule applied by
                       controls/make_recovered61_list.py); PERMNO, CRSP SIC-based FF30 and first CRSP price come
                       from master.filing_outcomes_linked, the offer terms from master.sdc_clean, and
                       r0 = (first CRSP price - offer price) / offer price, as in controls/audit_recovered61.py.
  baseline_validation  already-constructed IPOs recomputed by the SAS program as a check: the earliest IPO
                       (issue date, then PERMNO) in every fifth year from FILING_START_YEAR before
                       SAMPLE_END_YEAR, plus SAMPLE_END_YEAR. Their stored coskewness and R1/R2 returns
                       (master.analysis_full2) are written as old_* values for the comparison.
For the paper's inputs and dates this reproduces the 61 + 10 records of the original program.
"""
from pathlib import Path
import pandas as pd

P = Path('@RUN_ROOT@')
OUT = P / 'ext' / 'recovery'
FIRST, LAST = @FILING_START_YEAR@, @SAMPLE_END_YEAR@
OLD = ['coskewness'] + [f'r{k}_bhar_{y}y' for k in (2, 3) for y in (1, 3, 5)]


def sas(name):
    d = pd.read_sas(P / 'master' / (name + '.sas7bdat'))
    for c in d.select_dtypes(include=['object']).columns:
        d[c] = d[c].map(lambda x: x.decode('cp1252').strip() if isinstance(x, bytes) else x)
    if 'deal_num' in d:
        d['deal_num'] = pd.to_numeric(d.deal_num, errors='raise')
    return d


ids = pd.read_csv(P / 'ext/0928-1002/results/table1/Recovered61_audit_records.csv').deal_key.astype('int64')
s = sas('sdc_clean')
link = sas('filing_outcomes_linked')
new = s[s.deal_num.isin(ids)][['deal_num', 'idate', 'oprc']].merge(
    link[['deal_num', 'PERMNO', 'ff30', 'absprc']], on='deal_num', validate='one_to_one')
assert len(new) == len(ids) and new.PERMNO.notna().all()
new['r0'] = (new.absprc - new.oprc) / new.oprc
new['role'] = 'recovered61'

base = sas('analysis_full2')
years = list(range(FIRST, LAST, 5)) + [LAST]
picks = []
for y in years:
    z = base[base.idate.dt.year.eq(y)].sort_values(['idate', 'PERMNO'])
    if len(z):
        picks.append(z.iloc[0])
val = pd.DataFrame(picks)[['PERMNO', 'idate', 'oprc', 'r0', 'ff30'] + OLD].rename(columns={v: 'old_' + v for v in OLD})
val['role'] = 'baseline_validation'
assert not val.PERMNO.isin(new.PERMNO).any()

cols = ['permno', 'idate', 'oprc', 'r0', 'ff30', 'role'] + ['old_' + v for v in OLD]
t = pd.concat([new.rename(columns={'PERMNO': 'permno'}), val.rename(columns={'PERMNO': 'permno'})], ignore_index=True)
t['permno'] = t.permno.astype('int64'); t['ff30'] = t.ff30.astype('int64')
t['idate'] = pd.to_datetime(t.idate).dt.strftime('%Y-%m-%d')
OUT.mkdir(parents=True, exist_ok=True)
t[cols].to_csv(OUT / 'recovery_targets.csv', index=False)
print(len(new), 'recovered IPOs,', len(val), 'validation IPOs')

from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
W=Path(__file__).resolve().parent
S=Path('@RUN_ROOT@')
P=Path('@RUN_ROOT@/ext/ipo-20260921-25')
paths={'daily':S/'master/crsp_index_daily.sas7bdat','monthly_skew':S/'master/exp_skew_panel.sas7bdat','T4':P/'t11_yearfe_confirmed.dta','T5':P/'fe_ladder_20260924/T14_Filing_Panel_20260924.dta','skew_code':S/'sas/05_stage2_skewness_coskewness.sas','quarter_code':S/'sas/07b_stage2_filing_quarter_panel.sas','daily_code':Path('@RUN_ROOT@/sas/02_stage1_wrds_crsp_linking.sas')}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
hashes={k:{'path':str(p),'sha256':sha(p)} for k,p in paths.items()}
def qid(d):return (d.dt.year-1960)*4+d.dt.quarter-1
def qname(i):return f'{1960+int(i)//4}Q{int(i)%4+1}'
d=pd.read_sas(paths['daily']).rename(columns={'DATE':'date'}).sort_values('date')
assert not d.date.duplicated().any()
assert d.date.notna().all() and np.isfinite(d.ewretd).all() and (d.ewretd>-1).all()
assert np.allclose(np.log1p(d.ewretd),d.logewretd,atol=1e-12,rtol=1e-10)
d['source_time_id']=qid(d.date)
q=d.groupby('source_time_id').agg(n_days=('ewretd','size'),first_date=('date','min'),last_date=('date','max'),log_sum=('logewretd','sum')).reset_index()
q['market_return_qminus1_candidate']=np.expm1(q.log_sum)
prod=d.groupby('source_time_id').ewretd.apply(lambda x: np.prod(1+x.to_numpy())-1)
assert np.allclose(q.market_return_qminus1_candidate,prod.to_numpy(),atol=1e-12,rtol=1e-10)
q['time_id']=q.source_time_id+1
q['outcome_quarter']=q.time_id.map(qname);q['source_quarter']=q.source_time_id.map(qname)
lo,hi=(@FILING_START_YEAR@-1960)*4,(@SAMPLE_END_YEAR@-1960)*4+3  # first and last outcome quarter (Stata %tq)
q=q[q.time_id.between(lo,hi)].copy()
assert len(q)==hi-lo+1 and q.time_id.nunique()==hi-lo+1
assert (q.last_date < pd.to_datetime(q.outcome_quarter.map(lambda x: pd.Period(x,freq='Q').start_time))).all()
q.drop(columns='log_sum').to_stata(W/'Market_Return_Qminus1_Candidate_20260925.dta',write_index=False,version=118)
# Reconstruct quarterly mean from monthly skew series, then join exact quarterly lag keys.
m=pd.read_sas(paths['monthly_skew']);m=m[m.ff30.between(1,29)].copy()
m['time_id']=qid(pd.to_datetime(m.yearmonth))
a=m.groupby(['ff30','time_id']).agg(check_skew=('skew1','mean'),n_months=('skew1','count')).reset_index()
base=['l_age','l_cosk','l_lnexpected','l_overhang','l_uwrank','l_vcshare','l_primaryshare','l_optimism','l_ipovol']
coverage=[];skewchecks=[]
for family in ['T4','T5']:
 p=pd.read_stata(paths[family],convert_dates=False,convert_categoricals=False)
 assert not p.duplicated(['ff30','time_id']).any()
 x=p.merge(q[['time_id','market_return_qminus1_candidate']],on='time_id',how='left',validate='many_to_one')
 assert len(x)==len(p) and x.market_return_qminus1_candidate.notna().all()
 assert x.groupby('time_id').market_return_qminus1_candidate.nunique().eq(1).all()
 pd.testing.assert_frame_equal(p.reset_index(drop=True),x[p.columns].reset_index(drop=True))
 x.to_stata(W/f'{family}_Panel_With_Candidate_20260925.dta',write_index=False,version=118)
 for lag in range(1,5):
  z=a.copy();z.time_id+=lag
  ck=p[['ff30','time_id',f'skew_l{lag}']].merge(z,on=['ff30','time_id'],how='left',validate='one_to_one')
  assert np.allclose(ck[f'skew_l{lag}'],ck.check_skew,equal_nan=True,atol=1e-12,rtol=1e-10)
  skewchecks.append({'panel':family,'lag':lag,'cells':len(ck),'min_months':int(ck.n_months.min()),'max_months':int(ck.n_months.max()),'max_abs_difference':float((ck[f'skew_l{lag}']-ck.check_skew).abs().max())})
 for y in (['t11','t12'] if family=='T4' else ['n_main']):
  for col in range(4,10):
   lags=[1] if col<=5 else [col-4] if col<=8 else [1,2,3,4]
   needed=[y]+base+[f'skew_l{k}' for k in lags]
   if col>=5:needed+=['ff30','yr']
   complete=p[needed].notna().all(axis=1)
   after=complete & x.market_return_qminus1_candidate.notna()
   coverage.append({'outcome':y,'new_column':col,'complete_case_before':int(complete.sum()),'complete_case_after':int(after.sum()),'new_missing':int((complete & ~after).sum())})
# Coverage is input complete-case counting only, no estimation/singleton processing.
needed=d[d.source_time_id.between(lo-1,hi-1)].copy()
needed['gap_days']=needed.date.diff().dt.days
gaps=[{'date':str(row.date.date()),'previous_date':str((row.date-pd.Timedelta(days=row.gap_days)).date()),'gap_days':int(row.gap_days)} for row in needed[needed.gap_days>4].itertuples()]
examples=[]
for outcome in ['@FILING_START_YEAR@Q1','2020Q2']:
 op=pd.Period(outcome,freq='Q');prev=op-1
 for lag in range(1,5):
  refs=pd.period_range((op-lag).start_time,(op-lag).end_time,freq='M')
  for ref in refs:
   months=pd.period_range(ref-3,ref-1,freq='M')
   mrmonths=pd.period_range(prev.start_time,prev.end_time,freq='M')
   examples.append({'outcome':outcome,'skew_lag':lag,'reference_month':str(ref),'stock_return_months':', '.join(map(str,months)),'overlap_with_candidate_MR':', '.join(str(z) for z in months if z in mrmonths) or 'None'})
summary={'scope':'Candidate construction and coverage/timing audit only; no regression or Word editing; not adopted specification','daily_rows':len(d),'daily_first':str(d.date.min().date()),'daily_last':str(d.date.max().date()),'stored_missing_ewretd':int(d.ewretd.isna().sum()),'duplicate_dates':int(d.date.duplicated().sum()),'required_source_quarters':'1982Q4–2024Q3','candidate_outcome_quarters':168,'required_daily_rows':len(needed),'quarter_days_min':int(q.n_days.min()),'quarter_days_max':int(q.n_days.max()),'long_date_gaps_over_four_days':gaps,'first_candidate':q.iloc[0].astype(str).to_dict(),'last_candidate':q.iloc[-1].astype(str).to_dict(),'coverage':coverage,'skew_checks':skewchecks,'timing_examples':examples,'sources':hashes,'limitation':'Source SAS explicitly drops missing ewretd rows. No independent raw unfiltered CRSP DSI/trading-calendar reconciliation was performed; zero stored missing values does not certify every original trading date is present.'}
for k,p in paths.items():assert sha(p)==hashes[k]['sha256']
(W/'audit.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k not in ['sources','timing_examples','skew_checks']},indent=2,ensure_ascii=False))
print('All 8 skew lag reconstructions passed:',skewchecks)

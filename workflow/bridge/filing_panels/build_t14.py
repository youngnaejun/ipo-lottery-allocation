from pathlib import Path
import pandas as pd,numpy as np,json
W=Path(r'@RUN_ROOT@\ext\ipo-20260921-25')
d=pd.read_csv(W/'t11_three_definitions_deal_audit.csv',dtype={'deal_num':str})
p=pd.read_stata(W/'t11_yearfe_confirmed.dta',convert_dates=False,convert_categoricals=False)
issue=pd.to_datetime(d.idate,unit='D',origin='1960-01-01')
first=pd.to_datetime(d.fh_first_date,errors='coerce')
d['valid_q0']=d.tot_first.gt(0)&np.isfinite(d.tot_first)&first.notna()&(first<=issue)
d['q0_valid']=d.tot_first.where(d.valid_q0)
g=d.groupby(['ff30','qdate']).agg(n_all=('deal_key','size'),n_q0=('q0_valid','count'),sum_q0=('q0_valid','sum')).reset_index().rename(columns={'qdate':'time_id'})
p=p.merge(g,on=['ff30','time_id'],how='left',validate='one_to_one')
for c in ['n_all','n_q0','sum_q0']:p[c]=p[c].fillna(0)
assert (p.n_all==p.n_ipo).all()
p['q0_complete']=(p.n_all==p.n_q0).astype(int)
p['t14']=p.sum_q0.where(p.q0_complete.eq(1))
b=pd.read_stata(r'@RUN_ROOT@\stata\filing_quarter_panel.dta',convert_dates=False,convert_categoricals=False)
for k in range(1,6):
 lag=b[['ff30','qdate','industry_skew']].copy();lag.qdate+=k
 lag=lag.rename(columns={'qdate':'time_id','industry_skew':'check_skew'})
 p=p.merge(lag,on=['ff30','time_id'],how='left',validate='one_to_one')
 if k<5:assert np.allclose(p[f'skew_l{k}'],p.check_skew,equal_nan=True)
 else:p['skew_l5']=p.check_skew
 p=p.drop(columns='check_skew')
assert p.skew_l5.notna().all()
assert (p.loc[p.n_ipo.eq(0),'t14']==0).all()
assert p.loc[p.q0_complete.eq(0),'t14'].isna().all()
p.to_stata(W/'t14_confirmed_panel.dta',write_index=False,version=118)
d[['deal_key','deal_num','ff30','qdate','tot_first','fh_first_date','idate','valid_q0']].to_csv(W/'t14_q0_deal_audit.csv',index=False)
a={'eligible_completed_ipos':len(d),'q0_positive':int(d.tot_first.gt(0).sum()),'q0_zero_invalid':int(d.tot_first.eq(0).sum()),'q0_missing':int(d.tot_first.isna().sum()),'q0_valid':int(d.valid_q0.sum()),'positive_q0_invalid_date':int((d.tot_first.gt(0)&~d.valid_q0).sum()),'panel_cells':len(p),'true_zero_cells':int(p.n_ipo.eq(0).sum()),'complete_active_cells':int((p.n_ipo.gt(0)&p.q0_complete.eq(1)).sum()),'incomplete_active_cells_excluded':int(p.q0_complete.eq(0).sum()),'usable_dv_cells':int(p.t14.notna().sum()),'ipos_in_complete_active_cells':int(p.loc[p.q0_complete.eq(1),'n_ipo'].sum())}
(W/'t14_q0_audit.json').write_text(json.dumps(a,indent=2));print(json.dumps(a,indent=2))

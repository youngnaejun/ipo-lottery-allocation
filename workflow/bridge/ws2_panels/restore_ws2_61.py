from pathlib import Path
import json,pandas as pd,numpy as np
w=Path(r'@RUN_ROOT@\ext\ipo-ws2a-tables-20260914')
a=json.loads((w/'extra999_link_audit_20260917.json').read_text())['records']
ids={r['deal_key'] for r in a if r['next_market_day_match'] and r['CRSP_matches_SDC_listing_date'] and not r['monthly_prior_to_issue'] and not r['validated_same_event_deals']};assert @PAPER_CHECKS@==0 or len(ids)==61
x=pd.read_stata('@RUN_ROOT@/stata/filing_completion_analysis.dta',convert_dates=False,convert_categoricals=False)
old=pd.read_stata(w/'table11_deal_audit.dta',convert_dates=False,convert_categoricals=False)
oldids=set(old.loc[old.primary_nominal.gt(0),'deal_key']);assert (@PAPER_CHECKS@==0 or len(oldids)==8844) and not ids&oldids
x['restored_calendar61']=x.deal_key.isin(ids).astype('int8')
x['ws2_eligible_20260917']=x.deal_key.isin(ids|oldids).astype('int8')
x['primary_nominal']=x.oprc*x.primary_shares/1e6
f=pd.to_datetime(x.fdate,unit='D',origin='1960-01-01');x['qdate']=(f.dt.year-1960)*4+(f.dt.month-1)//3;x['mdate']=(f.dt.year-1960)*12+f.dt.month-1
new=x[x.ws2_eligible_20260917.eq(1)].copy();assert @PAPER_CHECKS@==0 or len(new)==8905
rest=new[new.restored_calendar61.eq(1)];assert len(rest)==len(ids) and rest.crsp_live_validated.eq(0).all() and rest.primary_nominal.gt(0).all()
assert rest[['PERMNO','idate']].drop_duplicates().shape[0]==len(rest)
fields=['deal_key','issuer_name','cusip_new','PERMNO','fdate','idate','ldate','crsp_first_date','ff30','sic_source','completed_live','crsp_live_validated','restored_calendar61','ws2_eligible_20260917','oprc','primary_shares','secondary_shares','primary_nominal','qdate','mdate']
new[fields].to_stata(w/'ws2_eligible8905_deals_20260917.dta',write_index=False,version=118)
rest[fields].to_stata(w/'ws2_restored61_deals_20260917.dta',write_index=False,version=118)
controls=['ff30','time_id','lag_skew','lag_return','lag_momentum','lag_ivol','lag_turnover','lag_lnfirms','skew_l1','skew_l2','skew_l3','skew_l4']
summary={'baseline_IPOs':8844,'restored_IPOs':61,'eligible_IPOs':8905,'added_primary_USD_millions':float(rest.primary_nominal.sum()),'dates_min_max':[str(f[x.restored_calendar61.eq(1)].min().date()),str(f[x.restored_calendar61.eq(1)].max().date())]}
for freq,period in [('quarterly','qdate'),('monthly','mdate')]:
 orig=pd.read_stata(w/f'tables12_13_{freq}_estimated.dta',convert_dates=False)
 g=new.groupby(['ff30',period]).agg(n_primary=('deal_key','size'),nominal_total=('primary_nominal','sum'),n_restored=('restored_calendar61','sum')).reset_index().rename(columns={period:'time_id'})
 p=orig[controls].merge(g,on=['ff30','time_id'],how='left',validate='one_to_one')
 p[['n_primary','nominal_total','n_restored']]=p[['n_primary','nominal_total','n_restored']].fillna(0)
 p['avg_primary']=p.nominal_total/p.n_primary.replace(0,np.nan);p['outcome_total']=np.log1p(p.nominal_total)
 assert p[controls].notna().all().all() and p.n_primary.sum()==len(new) and p.n_restored.sum()==len(rest)
 assert np.isclose(p.nominal_total.sum(),new.primary_nominal.sum())
 assert np.allclose((p.nominal_total-orig.nominal_total)[p.n_restored.eq(0)],0)
 p.to_stata(w/f'ws2_{freq}_recovered61_20260917.dta',write_index=False,version=118)
 summary[freq]={'cells':len(p),'positive_cells':int(p.n_primary.gt(0).sum()),'zero_cells':int(p.n_primary.eq(0).sum()),'affected_cells':int(p.n_restored.gt(0).sum()),'new_positive_cells':int((p.n_primary.gt(0)&orig.n_primary.eq(0)).sum())}
q=pd.read_stata(w/'ws2_quarterly_recovered61_20260917.dta');m=pd.read_stata(w/'ws2_monthly_recovered61_20260917.dta');m['qdate']=np.floor(m.time_id/3)
z=m.groupby(['ff30','qdate'])[['n_primary','nominal_total']].sum().reset_index().merge(q,left_on=['ff30','qdate'],right_on=['ff30','time_id'],suffixes=('_m','_q'),validate='one_to_one');assert len(z)==len(q) and np.allclose(z.n_primary_m,z.n_primary_q) and np.allclose(z.nominal_total_m,z.nominal_total_q)
(w/'ws2_recovery61_validation_20260917.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))

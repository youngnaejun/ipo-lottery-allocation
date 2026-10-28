from pathlib import Path
import pandas as pd,numpy as np,json
w=Path(r'@RUN_ROOT@\ext\ipo-ws2a-tables-20260914')
x=pd.read_stata('@RUN_ROOT@/stata/filing_completion_analysis.dta',convert_dates=False,convert_categoricals=False)
f=pd.to_datetime(x.fdate,unit='D',origin='1960-01-01')
a=x[x.completed_live.eq(1)&x.crsp_live_validated.eq(0)&x.ff30.between(1,29)&f.dt.year.between(@FILING_START_YEAR@,@SAMPLE_END_YEAR@)&x.oprc.gt(0)&x.primary_shares.gt(0)].copy();assert @PAPER_CHECKS@==0 or len(a)==999
cal=pd.read_sas('@RUN_ROOT@/master/crsp_index_daily.sas7bdat').DATE.sort_values().values.astype('datetime64[D]')
ids=set(a.PERMNO.dropna());cu=set(a.cusip_new);prefix=set(a.loc[a.PERMNO.isna(),'cusip_new'].str[:6]);parts=[]
with pd.read_sas('@RUN_ROOT@/master/crsp_monthly.sas7bdat',chunksize=150000) as reader:
 for c in reader:
  nc=c.NCUSIP.str.decode('ascii');mask=c.PERMNO.isin(ids)|nc.isin(cu)|nc.str[:6].isin(prefix)
  z=c.loc[mask,['PERMNO','DATE','SHRCD','EXCHCD']].copy();z['NCUSIP']=nc[mask];parts.append(z)
m=pd.concat(parts,ignore_index=True)
v=x[x.crsp_live_validated.eq(1)]
def dt(n):return pd.NaT if pd.isna(n) else pd.Timestamp('1960-01-01')+pd.Timedelta(days=int(n))
def ds(n):return None if pd.isna(n) else dt(n).strftime('%Y-%m-%d')
recs=[]
for _,r in a.iterrows():
 issue=dt(r.idate);first=dt(r.crsp_first_date);listing=dt(r.ldate);delta=r.issue_date_diff
 if pd.isna(r.PERMNO):cat='CUSIP_unmatched'
 elif delta<0:cat='CRSP_CUSIP_before_issue'
 elif delta<=7:cat='CRSP_CUSIP_2_to_7_days_after'
 elif delta<=30:cat='CRSP_CUSIP_8_to_30_days_after'
 elif delta<=365:cat='CRSP_CUSIP_31_to_365_days_after'
 else:cat='CRSP_CUSIP_over_365_days_after'
 idx=np.searchsorted(cal,issue.to_datetime64().astype('datetime64[D]'),side='right')
 nextday=pd.Timestamp(cal[idx]) if idx<len(cal) else pd.NaT
 issue_in_calendar=bool(np.isin(issue.to_datetime64().astype('datetime64[D]'),cal))
 z=m[m.PERMNO.eq(r.PERMNO)] if pd.notna(r.PERMNO) else m.iloc[0:0]
 before=z[z.DATE<issue]
 earliest=z.DATE.min()
 prev=v[(v.PERMNO==r.PERMNO)&(v.deal_key!=r.deal_key)] if pd.notna(r.PERMNO) else v.iloc[0:0]
 sameevent=prev[(prev.idate-r.idate).abs()<=7]
 near=z[(z.DATE>=issue-pd.Timedelta(days=31))&(z.DATE<=issue+pd.Timedelta(days=31))]
 exact=m[m.NCUSIP.eq(r.cusip_new)]
 family=m[m.NCUSIP.str[:6].eq(r.cusip_new[:6])] if pd.isna(r.PERMNO) else m.iloc[0:0]
 rec={k:(None if pd.isna(r[k]) else r[k]) for k in ['deal_key','issuer_name','cusip_new','PERMNO','sic_source','ff30','issue_date_diff','oprc','primary_shares','nation','exchange']}
 rec.update({'fdate':ds(r.fdate),'idate':ds(r.idate),'ldate':ds(r.ldate),'crsp_first_date':ds(r.crsp_first_date),'category':cat,'issue_is_market_day':issue_in_calendar,'next_market_day':None if pd.isna(nextday) else nextday.strftime('%Y-%m-%d'),'next_market_day_match':bool(pd.notna(first) and first==nextday),'CRSP_matches_SDC_listing_date':bool(pd.notna(first) and first==listing),'monthly_prior_to_issue':len(before)>0,'first_monthly_permno_date':None if pd.isna(earliest) else earliest.strftime('%Y-%m-%d'),'monthly_within31days':len(near)>0,'other_monthly_CUSIP_near_issue':sorted(set(near.NCUSIP)-{r.cusip_new}),'validated_same_event_deals':sameevent.deal_key.tolist(),'prior_validated_issue_deals':prev.loc[prev.idate<r.idate-7,'deal_key'].tolist(),'exact_CUSIP_monthly_permnos':sorted(exact.PERMNO.unique().astype(int).tolist()),'same_CUSIP6_monthly_permnos':sorted(family.PERMNO.unique().astype(int).tolist())})
 recs.append(rec)
summary={'N':len(recs),'categories':pd.Series([r['category'] for r in recs]).value_counts().to_dict(),'next_market_day_matches':sum(r['next_market_day_match'] for r in recs),'next_market_day_SDC_listing_also':sum(r['next_market_day_match'] and r['CRSP_matches_SDC_listing_date'] for r in recs),'listing_date_matches':sum(r['CRSP_matches_SDC_listing_date'] for r in recs),'unmatched_with_exact_monthly_CUSIP':sum(r['category']=='CUSIP_unmatched' and bool(r['exact_CUSIP_monthly_permnos']) for r in recs),'unmatched_with_same_CUSIP6':sum(r['category']=='CUSIP_unmatched' and bool(r['same_CUSIP6_monthly_permnos']) for r in recs),'validated_same_event':sum(bool(r['validated_same_event_deals']) for r in recs)}
for c in summary['categories']:
 rr=[r for r in recs if r['category']==c];print(c,len(rr),'next_market_day',sum(r['next_market_day_match'] for r in rr),'listing_match',sum(r['CRSP_matches_SDC_listing_date'] for r in rr),'prior_monthly',sum(r['monthly_prior_to_issue'] for r in rr),'othercusip_near',sum(bool(r['other_monthly_CUSIP_near_issue']) for r in rr))
print(json.dumps(summary,indent=2))
for label,rr in [('next_market_day',[r for r in recs if r['next_market_day_match']]),('otherCUSIP',[r for r in recs if r['other_monthly_CUSIP_near_issue']]),('before',[r for r in recs if r['category']=='CRSP_CUSIP_before_issue'])]:print(label,json.dumps(rr[:3],indent=2))
(w/'extra999_link_audit_20260917.json').write_text(json.dumps({'summary':summary,'records':recs},indent=2),encoding='utf-8')

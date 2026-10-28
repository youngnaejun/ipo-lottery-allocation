from pathlib import Path
import pandas as pd,numpy as np,re,json
R=Path(__file__).resolve().parents[1];P=Path('@RUN_ROOT@');O=R/'results/all_filer_controls/additional_audit';O.mkdir(parents=True,exist_ok=True)
d=pd.read_csv(R/'results/all_filer_controls/Deal_Control_Audit.csv',dtype={'dk':str})
d.fdate=pd.to_datetime(d.fdate);d['filing_month']=d.fdate.dt.to_period('M')
cross=pd.read_stata(P/'stata_output/additional_tests/completion_industry_crosswalk/filing_completion_crosswalk_analysis.dta',convert_categoricals=False)
cross['dk']=cross.deal_key.astype(str).str.replace(r'\.0$','',regex=True)
d=d.merge(cross[['dk','cusip6','cusip_new','PERMNO']],on='dk',validate='one_to_one')
pool=pd.read_stata(P/'stata/analysis_full.dta',convert_categoricals=False)
pool['month']=pool.iyearmonth.dt.to_period('M')
sent=pd.read_csv(P/'raw/UMCSENT.csv');sent['month']=pd.to_datetime(sent.observation_date).dt.to_period('M')
assert sent.month.is_unique
sent=sent.set_index('month').UMCSENT.sort_index().asfreq('M').ffill()
d['optimism_filing']=pd.Series(d.filing_month-1).map(sent).to_numpy()
vol={}
for month in d.filing_month.unique():
 z=pool[(pool.month>=month-3)&(pool.month<=month-1)&pool.r0.notna()]
 vol[month]=(z.r0.std(ddof=1),len(z))
d['ipo_vol_filing']=d.filing_month.map({k:v[0] for k,v in vol.items()})
d['vol_pool_n']=d.filing_month.map({k:v[1] for k,v in vol.items()})
# Match the original PERMNO exclusion for targets with an existing linked security.
excluded=0
for i,row in d[d.PERMNO.notna()].iterrows():
 z=pool[(pool.month>=row.filing_month-3)&(pool.month<=row.filing_month-1)&pool.r0.notna()]
 if z.PERMNO.eq(row.PERMNO).any():
  excluded+=1;z=z[z.PERMNO.ne(row.PERMNO)]
  d.loc[i,'ipo_vol_filing']=z.r0.std(ddof=1);d.loc[i,'vol_pool_n']=len(z)
# Founding lookup: only a unique positive founding year per exact CUSIP6.
age=pd.read_csv(P/'raw/ipo_age_clean.csv',dtype={'CUSIP':str})
age=age[age['ADR (2=ADR)'].ne(2)].copy()
age['key']=age.CUSIP.str.strip().str[:6]
age['Founding']=pd.to_numeric(age.Founding,errors='coerce').where(lambda s:s>0)
g=age.dropna(subset=['key','Founding']).groupby('key').Founding
unique=g.first()[g.nunique()==1]
d['age_key']=d.cusip6.astype(str).str.strip().str[:6]
d['founding_candidate']=d.age_key.map(unique)
d['age_filing_candidate']=(d.fdate.dt.year-d.founding_candidate).where(d.fdate.dt.year>=d.founding_candidate)
# Exact-name + existing alias bridge matching only. Rank uses filing YEAR,
# but multi-year ex-post rating blocks are not point-in-time published ratings.
def clean(x):
 x=str(x).upper().strip().replace('\t',' ').replace('\xa0',' ')
 x=re.sub(r"[.,']",'',x)
 for t in [' INCORPORATED',' INC',' LLC',' LTD',' LP',' CORPORATION',' CORP',' COMPANY',' CO'] :x=x.replace(t,'')
 x=x.replace('&','AND')
 for t in [' SECURITIES',' CAPITAL MARKETS',' INVESTMENT BANKING']:x=x.replace(t,'')
 return ' '.join(re.sub(r'\(.*?\)','',x).split())
uw=pd.read_csv(P/'raw/underwriter_clean.csv')
ranks=[c for c in uw if c.startswith('Rank')]
for c in ranks:uw[c]=pd.to_numeric(uw[c],errors='coerce').replace(-9,np.nan)
uw['key']=uw['Underwriter Name'].map(clean);uw['score']=uw[ranks].sum(axis=1)
uw=uw.sort_values('score',ascending=False).drop_duplicates('key').set_index('key')
source=Path('@RUN_ROOT@/sas/03_stage1_underwriter_matching.sas').read_text(encoding='utf-8-sig')
bridge=dict(re.findall(r'sdc_name\s*=\s*"([^"]+)";\s*ritter_name\s*=\s*"([^"]+)";',source))
def rankcol(y):
 for hi,col in [(1984,'Rank8084'),(1991,'Rank8591'),(2000,'Rank9200'),(2004,'Rank0104'),(2007,'Rank0507'),(2009,'Rank0809'),(2011,'Rank1011'),(2017,'Rank1217'),(2020,'Rank1820'),(2022,'Rank2122'),(2023,'Rank23'),(2024,'Rank24'),(2025,'Rank25'),(2026,'Rank26')]:
  if y<=hi:return col
manager=[]
for i,row in d.iterrows():
 vals=[];tokens=[] if pd.isna(row['Lead Managers']) else str(row['Lead Managers']).split(';')
 for token in tokens:
  key=clean(token)
  if key in ['', 'NOT APPLICABLE','NA','N/A','UNKNOWN']:continue
  key=bridge.get(key,key);col=rankcol(row.fdate.year)
  v=uw.at[key,col] if key in uw.index and col in uw.columns else np.nan  # no rank column for the year -> missing
  manager.append(dict(dk=row.dk,raw=token,key=key,rank_column=col,rank=v))
  vals.append(v)
 d.loc[i,'uw_n_names']=len(vals);d.loc[i,'uw_n_matched']=int(pd.notna(vals).sum())
 d.loc[i,'uw_rank_candidate']=np.nanmean(vals) if pd.notna(vals).any() else np.nan
d['uw_all_names_matched']=d.uw_n_names.gt(0)&d.uw_n_names.eq(d.uw_n_matched)
coverage=[]
variables=['optimism_filing','ipo_vol_filing','age_filing_candidate','uw_rank_candidate']
for status,z in [('ALL',d)]+list(d.groupby('Transaction_Status')):
 for v in variables:coverage.append(dict(status=status,variable=v,N=len(z),available=int(z[v].notna().sum()),coverage=z[v].notna().mean()))
pd.DataFrame(coverage).to_csv(O/'Coverage.csv',index=False)
pd.DataFrame(manager).to_csv(O/'Underwriter_Matches.csv',index=False)
d.drop(columns=['filing_month']).to_csv(O/'Deal_Candidates.csv',index=False)
# Equal weight at DEAL level (underwriters first averaged within a deal).
agg=d.groupby(['ff30','time_id'])[variables].mean()
counts=d.groupby(['ff30','time_id'])[variables].count().add_suffix('_n')
agg=agg.join(counts).join(d.groupby(['ff30','time_id']).size().rename('n_filings')).reset_index();agg.time_id+=1
agg.to_csv(O/'Lagged_Cohort_Candidates.csv',index=False)
qa=dict(filings=len(d),source_IPO_pool=len(pool),volatility_same_security_exclusions=excluded,vol_pool_min=int(d.vol_pool_n.min()),vol_pool_max=int(d.vol_pool_n.max()),underwriter_all_names_matched=int(d.uw_all_names_matched.sum()),age_negative_excluded=int((d.fdate.dt.year<d.founding_candidate).sum()),age_ambiguous_cusip_keys=int((g.nunique()>1).sum()),regressions_not_run=True,word_tables_unchanged=True)
(O/'QA.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
print(pd.DataFrame(coverage).to_string(index=False));print(json.dumps(qa,indent=2))

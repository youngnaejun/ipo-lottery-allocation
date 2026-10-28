from pathlib import Path
import pandas as pd,numpy as np,json,sys,hashlib
P=Path(__file__).resolve().parent
SRC=Path(r"@RUN_ROOT@\ext\recovered61-complete\results\Expanded_analysis.pkl")
e=pd.read_pickle(SRC);e['analysis_id']=pd.to_numeric(e.deal_num);e['price_adj_imp']=e.price_adj.fillna(0)
assert len(e)==e.PERMNO.nunique() and (@PAPER_CHECKS@==0 or len(e)==8984)
seen={};parts=[];total=0
for d in pd.read_sas(P/'daily.sas7bdat',chunksize=500000):
 d.columns=d.columns.str.lower();total+=len(d)
 # Preserve input ordering, which is PERMNO/date in legacy DSF. Check after extraction.
 nums=d.groupby('permno').cumcount()+1+d.permno.map(seen).fillna(0)
 parts.append(d.loc[nums<=1261].copy())
 for k,v in d.permno.value_counts().items():seen[k]=seen.get(k,0)+v
 print('read',total,flush=True)
d=pd.concat(parts,ignore_index=True);del parts
assert not d.duplicated(['permno','date']).any()
assert d.equals(d.sort_values(['permno','date']).reset_index(drop=True))
l=pd.read_sas(P/'delist.sas7bdat');l.columns=l.columns.str.lower();l=l.rename(columns={'dlstdt':'date'})
assert not l.duplicated(['permno','date']).any()
d=d.merge(l,on=['permno','date'],how='outer',validate='one_to_one').sort_values(['permno','date'])
d['n']=d.groupby('permno').cumcount()+1;d=d[d.n<=1261].copy()
d=d.merge(e[['PERMNO','idate','r0']].rename(columns={'PERMNO':'permno'}),on='permno',validate='many_to_one')
d['raw_ret']=d.ret;d.loc[d.n.eq(1)&d.ret.isna(),'ret']=d.r0;d['ret_adj']=d.ret
m=d.dlret.notna();d.loc[m,'ret_adj']=(1+d.loc[m,'ret'].fillna(0))*(1+d.loc[m,'dlret'])-1
assert not (d.ret_adj.dropna() < -1).any(),'Invalid return below -1; stop before comparison'
d.to_pickle(P/'event_rows_first1261.pkl')
events=d[d.ret_adj.eq(-1)].copy();events.to_csv(P/'boundary_events.csv',index=False)
first=d[d.n.eq(1)];first.to_csv(P/'first_observations.csv',index=False)
rows=[];lookup={k:z for k,z in d.groupby('permno')}
for row in e.itertuples():
 z=lookup.get(row.PERMNO,d.iloc[:0])
 for h in [1,3,5]:
  for k in [2,3]:
   name=f'r{k}_bhar_{h}y';v=z[z.n.between(2 if k==2 else 1,252*h+(k==2))];a=v.ret_adj.dropna();pos=a[a>-1]
   old=float(np.expm1(np.log1p(pos).sum())) if len(pos) else np.nan
   new=-1.0 if a.eq(-1).any() else old
   stored=getattr(row,name)
   rows.append(dict(permno=int(row.PERMNO),analysis_id=int(row.analysis_id),variable=name,horizon=h,stored=stored,reproduced=old,corrected=new,n_rows=len(v),n_valid=len(a),n_zero=int(a.eq(-1).sum()),baseline_match=bool(np.isclose(stored,old,atol=1e-8,rtol=1e-8,equal_nan=True))))
a=pd.DataFrame(rows)
# Mirror the production left joins: r2_all starts from the R1 one-year table,
# and final BHAR starts from r2_all. No R1 one-year rows means no horizons survive.
no_anchor=a.loc[a.variable.eq('r2_bhar_1y') & a.n_valid.eq(0),'permno']
a.loc[a.permno.isin(no_anchor),['reproduced','corrected']]=np.nan
a['baseline_match']=np.isclose(a.stored,a.reproduced,atol=1e-8,rtol=1e-8,equal_nan=True)
a.to_csv(P/'return_comparison_all.csv',index=False)
qa={'input_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'IPO_count':len(e),'daily_rows_extracted':total,'event_IPOs':int(d.permno.nunique()),'return_values':len(a),'baseline_mismatches':int((~a.baseline_match).sum()),'boundary_IPOs':int(events.permno.nunique()),'boundary_events':len(events),'nonmissing_first_ret':int(first.raw_ret.notna().sum()),'cutoff':'@DATA_END_DATE@'}
(P/'QA.json').write_text(json.dumps(qa,indent=2))
print(json.dumps(qa),flush=True)
if not a.baseline_match.all():
 a[~a.baseline_match].to_csv(P/'baseline_mismatches.csv',index=False)
 raise RuntimeError('Baseline not reproduced: separate vintage/implementation differences before correction')
correct=e.copy()
for name,g in a.groupby('variable'):
 # Apply only zero-gross boundary corrections, keeping original stored precision otherwise.
 ids=g.loc[g.n_zero.gt(0),'permno'];correct.loc[correct.PERMNO.isin(ids),name]=-1
changed=a[a.n_zero.gt(0)&a.stored.notna()].copy();changed['change_pp']=100*(changed.corrected-changed.stored);changed.to_csv(P/'changed_returns.csv',index=False)
correct.to_pickle(P/'Expanded_analysis_boundary_corrected.pkl')

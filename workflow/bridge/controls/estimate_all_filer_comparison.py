from pathlib import Path
import json,hashlib
import pandas as pd,numpy as np
from estimate_table4 import fit,CONTROLS,MR
R=Path(__file__).resolve().parents[1];O=R/'results/all_filer_controls'
d=pd.read_csv(O/'Deal_Control_Audit.csv')
p=pd.read_stata(R/'inputs/T5_Panel_With_Candidate_20260925.dta',convert_categoricals=False)
assert p.n_main.sum()==len(d) and (@PAPER_CHECKS@==0 or len(d)==13957)
count=d.groupby(['ff30','time_id']).size()
assert np.array_equal(count.reindex(pd.MultiIndex.from_frame(p[['ff30','time_id']]),fill_value=0),p.n_main)
for prefix,frame in [('all',d),('completed',d[d.in_t12.eq(True)])]:
 g=frame.groupby(['ff30','time_id']).ln_initial_amount.agg(['mean','count','size']).reset_index()
 g=g.rename(columns={'mean':prefix+'_amount','count':prefix+'_valid','size':prefix+'_n'})
 g.time_id+=1
 p=p.merge(g,on=['ff30','time_id'],how='left',validate='one_to_one')
 inside=p.time_id.gt(d.time_id.min())
 empty=p[prefix+'_n'].isna()&inside
 p.loc[empty,[prefix+'_amount',prefix+'_valid',prefix+'_n']]=0
 p[prefix+'_empty']=p[prefix+'_n'].eq(0).astype(float).where(inside)
 p[prefix+'_missing']=(1-p[prefix+'_valid']/p[prefix+'_n']).where(p[prefix+'_n']>0,0).where(inside)
# Outcome never depends on control availability. Partial-cohort means use observed
# initial filing amounts only, not substituted final amounts or zero imputation.
base=['l_cosk',MR]
full=['skew_l1']+CONTROLS+[MR,'ff30','yr']+[f'skew_l{i}' for i in range(2,5)]
matched=p.dropna(subset=full+['all_amount','completed_amount']).copy()
strict=matched[(matched.all_missing==0)&(matched.completed_missing==0)].copy()
models=[];rows=[];samples=[]
for sample_name,frame in [('matched_available',matched),('matched_complete_cohorts',strict)]:
 for col in range(4,10):
  sk=[f'skew_l{col-4}'] if col in [6,7,8] else [f'skew_l{i}' for i in range(1,5)] if col==9 else ['skew_l1']
  fe=() if col==4 else ('ff30','yr')
  variants={'original_controls':sk+CONTROLS+[MR],
     'common_controls_only':sk+base,
     'completed_initial_amount':sk+base+['completed_amount','completed_empty'],
     'all_filer_initial_amount':sk+base+['all_amount','all_empty']}
  if sample_name=='matched_available':
   variants['completed_initial_amount']+=['completed_missing']
   variants['all_filer_initial_amount']+=['all_missing']
  for variant,xs in variants.items():
   # Empty-cell indicator avoids interpreting a zero mean as a $1m filing.
   m=fit(frame,'n_main',xs,fe);m.update(sample=sample_name,variant=variant,column=col)
   models.append(m)
   for term in sk:
    v=m['terms'][term]
    rows.append(dict(sample=sample_name,variant=variant,column=col,term=term,N=m['N'],b=v['b'],t=v['t'],p=v['p'],adj_r2=m['adj_r2'],joint_p=m['joint_p']))
   samples += [dict(sample=sample_name,variant=variant,column=col,ff30=k[0],time_id=k[1]) for k in m['keys']]
 for col in range(4,10):
  fits=[m for m in models if m['sample']==sample_name and m['column']==col]
  assert all(m['keys']==fits[0]['keys'] for m in fits)
pd.DataFrame(rows).to_csv(O/'Skewness_Comparison.csv',index=False)
pd.DataFrame(samples).to_csv(O/'Estimation_Samples.csv',index=False)
(O/'Models.json').write_text(json.dumps(models,indent=2),encoding='utf-8')
p.to_stata(O/'Comparison_Panel.dta',write_index=False,version=118)
qa=dict(population_filings=len(d),count_matches_original_panel=True,matched_available_cells=len(matched),matched_complete_cohort_cells=len(strict),models=len(models),same_samples_within_comparison=True,max_independent_OLS_difference=max(m['full_dummy_max_slope_difference'] for m in models),singleton_drops=sorted(set(m['singleton_drops'] for m in models)),no_final_outcome_tables_modified=True)
(O/'QA.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
print(json.dumps(qa,indent=2));print(pd.DataFrame(rows).query('column==5').to_string(index=False));print(pd.DataFrame(rows).query('column==9').to_string(index=False))

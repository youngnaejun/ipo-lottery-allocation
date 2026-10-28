from pathlib import Path
import pandas as pd,numpy as np,json
from estimate_table4 import fit,specs
R=Path(__file__).resolve().parents[1];O=R/'results/table5_expanded';O.mkdir(parents=True,exist_ok=True)
p=pd.read_stata(R/'results/all_filer_controls/Comparison_Panel.dta',convert_categoricals=False)
d=pd.read_csv(R/'results/all_filer_controls/additional_audit/Deal_Candidates.csv')
g=d.groupby(['ff30','time_id']).uw_rank_candidate.agg(['mean','count','size']).reset_index()
g=g.rename(columns={'mean':'all_uw','count':'all_uw_valid','size':'all_uw_n'});g.time_id+=1
p=p.merge(g,on=['ff30','time_id'],how='left',validate='one_to_one')
empty=p.all_uw_n.isna()&p.time_id.gt(d.time_id.min());p.loc[empty,['all_uw','all_uw_valid','all_uw_n']]=0
original=p.copy();p['l_lnexpected']=p.all_amount;p['l_uwrank']=p.all_uw
models=[];comparisons=[]
for col,(xs,fe) in specs().items():
 m=fit(p,'n_main',xs,fe);m['column']=col;models.append(m)
 # Same-sample comparisons separate changed controls from estimation attrition.
 mask=p[['n_main']+xs+list(fe)].notna().all(axis=1)&original[['n_main']+xs+list(fe)].notna().all(axis=1)
 a=fit(p.loc[mask],'n_main',xs,fe);b=fit(original.loc[mask],'n_main',xs,fe)
 assert a['keys']==b['keys']
 for name,v in [('expanded',a),('original',b)]:v.update(column=col,variant=name);comparisons.append(v)
(O/'Models.json').write_text(json.dumps(models,indent=2),encoding='utf-8')
(O/'Same_Sample_Models.json').write_text(json.dumps(comparisons,indent=2),encoding='utf-8')
pd.DataFrame([dict(column=m['column'],term=t,**v) for m in models for t,v in m['terms'].items()]).to_csv(O/'Coefficients.csv',index=False)
pd.DataFrame([dict(column=m['column'],N=m['N'],adj_r2=m['adj_r2'],joint_p=m['joint_p']) for m in models]).to_csv(O/'Summary.csv',index=False)
pd.DataFrame([dict(column=m['column'],ff30=k[0],time_id=k[1]) for m in models for k in m['keys']]).to_csv(O/'Samples.csv',index=False)
p.to_stata(O/'Input_Panel.dta',write_index=False,version=118)
q=dict(all_pass=True,models_estimated=len(models),same_sample_comparisons_match=True,max_independent_OLS_difference=max(m['full_dummy_max_slope_difference'] for m in models),singleton_drops=[m['singleton_drops'] for m in models])
(O/'QA.json').write_text(json.dumps(q,indent=2),encoding='utf-8')
print(pd.DataFrame([dict(column=m['column'],N=m['N'],b=m['terms'].get('skew_l1',{}).get('b'),p=m['terms'].get('skew_l1',{}).get('p'),joint_p=m['joint_p']) for m in models]).to_string(index=False))

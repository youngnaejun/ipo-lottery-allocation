from pathlib import Path
import sys,json
import numpy as np
import pandas as pd
R=Path(r'@RUN_ROOT@\ext\0928-1002')
S=Path(r'@RUN_ROOT@\ext\recovered61-complete')
O=Path(r'@RUN_ROOT@\ext\ppml')
fixed=pd.read_pickle(S/'results/Updated_panel_deal_controls.pkl')
original=pd.read_stata('@RUN_ROOT@/ext/ipo-20260921-25/t11_design_diag_deals.dta',convert_categoricals=False)
cohort=['age','lnexpected','overhang','uwrank','vcshare','primaryshare','optimism','ipovol']
for table,path,cols,ys in [('T4',R/'inputs/T4_Panel_With_Candidate_20260925.dta',cohort,[('T4A','t11'),('T4B','t12')]),('T5',R/'results/table5_expanded/Input_Panel.dta',[c for c in cohort if c not in ['lnexpected','uwrank']],[('T5','n_main')])]:
 p=pd.read_stata(path,convert_categoricals=False)
 agg=fixed.groupby(['ff30','time_id'])[cols].mean().join(fixed.groupby(['ff30','time_id']).size().rename('count')).reset_index()
 agg.time_id+=1
 joined=p[['ff30','time_id']].merge(agg,on=['ff30','time_id'],how='left',validate='one_to_one')
 empty=joined['count'].isna()&p.time_id.gt(original.time_id.min())
 for c in cols:
  p['l_'+c]=joined[c].to_numpy();p.loc[empty,'l_'+c]=0
 if table=='T4':
  total=original.groupby(['ff30','time_id']).actual.sum().rename('proceeds').reset_index()
  p=p.merge(total,on=['ff30','time_id'],how='left',validate='one_to_one');p.proceeds=p.proceeds.fillna(0)
  assert np.allclose(np.log1p(p.proceeds),p.t11,atol=1e-10)
 p.to_stata(O/(table+'_input.dta'),write_index=False,version=118)
print('wrote final T4/T5 estimation panels')

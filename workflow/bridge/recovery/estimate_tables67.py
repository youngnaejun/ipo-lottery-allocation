"""HC1 OLS helper (ordinary) and the IPO-level control lists used by the bridge scripts."""
from pathlib import Path
import json, hashlib, shutil
import numpy as np
import pandas as pd
from estimate_table4 import fit, t_p
R=Path(__file__).resolve().parents[1]
FIRM=['age_ritter','coskewness','internet','NASDAQ','NYSE']
DEAL=['ln_amount_filed_adj1975','share_overhang','pure_primary','VB','uw_rank_ave']
IND=['ind_ret','ind_mom','ind_vol','ind_turn']

def ordinary(s,y,xs,fe):
    s=s.dropna(subset=[y]+xs+list(fe)).copy()
    x=s[xs].to_numpy(float); scales=x.std(axis=0)
    z=np.column_stack([x/scales,np.ones(len(s))]+[pd.get_dummies(s[f],drop_first=True,dtype=float).to_numpy() for f in fe])
    yy=s[y].to_numpy(float)
    q,rr=np.linalg.qr(z,mode='reduced'); assert np.linalg.matrix_rank(rr)==z.shape[1]
    b=np.linalg.solve(rr,q.T@yy); e=yy-z@b; df=len(s)-z.shape[1]
    ir=np.linalg.solve(rr,np.eye(z.shape[1])); bread=ir@ir.T
    scores=z*e[:,None]; cov=bread@(scores.T@scores)@bread*(len(s)/df)
    scale=np.r_[1/scales,1.]; k=len(xs)+1
    bb=b[:k]*scale; se=np.sqrt(np.diag(cov)[:k])*scale
    delta=float(np.max(abs(np.linalg.lstsq(z,yy,rcond=None)[0]-b)))
    assert delta<1e-8
    return dict(N=len(s),df_r=df,adj_r2=1-(e@e/df)/(((yy-yy.mean())@(yy-yy.mean()))/(len(s)-1)),singleton_drops=0,
        terms={t:dict(b=float(bb[i]),se=float(se[i]),t=float(bb[i]/se[i]),p=t_p(bb[i]/se[i],df)) for i,t in enumerate(xs+['_cons'])},
        ids=s.analysis_id.astype(int).tolist(),full_dummy_max_slope_difference=delta)

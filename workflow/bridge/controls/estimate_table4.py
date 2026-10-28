"""Fixed-effects OLS helpers for the industry-quarter panels (Table 4/5 specifications).

Requires only NumPy and pandas. Unweighted HC1 OLS with explicit FE projection; the intercept is
reconstructed through sample means as in Stata reghdfe. Imported by the bridge scripts for fit() and
specs(); the paper's benchmark comparison against archived results is not part of the public workflow.
"""
from pathlib import Path
import hashlib, json, math, shutil
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'results'
CONTROLS = ['l_age','l_cosk','l_lnexpected','l_overhang','l_uwrank','l_vcshare','l_primaryshare','l_optimism','l_ipovol']
MR = 'market_return_qminus1_candidate'


def beta_fraction(a, b, x):
    """Continued fraction for the incomplete beta, evaluated with modified Lentz."""
    tiny = 1e-300
    c = 1.0
    d = 1.0 - (a+b)*x/(a+1.0)
    if abs(d) < tiny: d = tiny
    d = 1.0/d
    h = d
    for m in range(1,10001):
        m2 = 2*m
        aa = m*(b-m)*x/((a+m2-1)*(a+m2))
        d = 1.0+aa*d
        if abs(d)<tiny: d=tiny
        c = 1.0+aa/c
        if abs(c)<tiny: c=tiny
        d = 1.0/d
        h *= d*c
        aa = -(a+m)*(a+b+m)*x/((a+m2)*(a+m2+1))
        d = 1.0+aa*d
        if abs(d)<tiny: d=tiny
        c = 1.0+aa/c
        if abs(c)<tiny: c=tiny
        d = 1.0/d
        delta = d*c
        h *= delta
        if abs(delta-1.0)<3e-14: return h
    raise ArithmeticError('Incomplete-beta continued fraction did not converge')


def ibeta(a,b,x):
    if x<=0: return 0.0
    if x>=1: return 1.0
    factor=math.exp(math.lgamma(a+b)-math.lgamma(a)-math.lgamma(b)+a*math.log(x)+b*math.log1p(-x))
    if x<(a+1)/(a+b+2): value=factor*beta_fraction(a,b,x)/a
    else: value=1-factor*beta_fraction(b,a,1-x)/b
    return min(1.0,max(0.0,value))


def t_p(t,df):
    return ibeta(df/2,0.5,df/(df+t*t))


def f_p(f,df1,df2):
    return ibeta(df2/2,df1/2,df2/(df2+df1*f))


def fit(frame,outcome,xvars,fe=()):
    s=frame.dropna(subset=[outcome]+xvars+list(fe)).copy()
    before=len(s)
    # Match reghdfe's recursive singleton removal; no singletons in this panel.
    if fe:
        while True:
            singleton=np.zeros(len(s),dtype=bool)
            for f in fe: singleton |= s.groupby(f)[f].transform('size').eq(1).to_numpy()
            if not singleton.any(): break
            s=s.loc[~singleton].copy()
    y=s[outcome].to_numpy(dtype=float)
    x=s[xvars].to_numpy(dtype=float)
    n,k=x.shape
    scales=x.std(axis=0,ddof=0)
    assert (scales>0).all()
    z=x/scales
    ymean=float(y.mean())
    zmean=z.mean(axis=0)
    parts=[np.ones((n,1))]
    for f in fe: parts.append(pd.get_dummies(s[f],drop_first=True,dtype=float).to_numpy())
    fmat=np.column_stack(parts)
    qf,rf=np.linalg.qr(fmat,mode='reduced')
    rank_fe=int(np.linalg.matrix_rank(rf))
    assert rank_fe==fmat.shape[1], 'Unexpected disconnected FE categories'
    zt=z-qf@(qf.T@z)
    yt=y-qf@(qf.T@y)
    qx,rx=np.linalg.qr(zt,mode='reduced')
    assert np.linalg.matrix_rank(rx)==k, 'Unexpected collinearity'
    bz=np.linalg.solve(rx,qx.T@yt)
    e=yt-zt@bz
    invr=np.linalg.solve(rx,np.eye(k))
    dxx=invr@invr.T
    # reghdfe_extend_b_and_xx: report intercept using the sample-mean normalisation.
    dz=np.empty((k+1,k+1))
    dz[:k,:k]=dxx
    dz[k,:k]=-zmean@dxx
    dz[:k,k]=dz[k,:k]
    dz[k,k]=1/n+zmean@dxx@zmean
    zaug=np.column_stack([zt+zmean,np.ones(n)])
    df=n-k-rank_fe
    scores=zaug*e[:,None]
    vz=dz@(scores.T@scores)@dz*(n/df)
    scale=np.r_[1/scales,1.0]
    b=np.r_[bz,ymean-zmean@bz]*scale
    v=vz*np.outer(scale,scale)
    se=np.sqrt(np.diag(v))
    t=b/se
    p=np.array([t_p(a,df) for a in t])
    rss=float(e@e)
    tss=float((y-ymean)@(y-ymean))
    adj=1-(rss/df)/(tss/(n-1))
    terms=xvars+['_cons']
    # Independently solve the full dummy model and compare all substantive slopes.
    full=np.column_stack([z,fmat])
    direct=np.linalg.lstsq(full,y,rcond=None)[0][:k]/scales
    delta=float(np.max(np.abs(direct-b[:k])))
    assert np.allclose(direct,b[:k],atol=1e-9,rtol=1e-9)
    result={'outcome':outcome,'N':n,'df_r':df,'df_absorbed_including_intercept':rank_fe,
      'singleton_drops':before-n,'adj_r2':adj,'industry_fe':'ff30' in fe,'year_fe':'yr' in fe,
      'mr':MR in xvars,'xvars':xvars,'keys':[list(map(int,z)) for z in s[['ff30','time_id']].to_numpy()],
      'terms':{name:{'b':float(b[i]),'se':float(se[i]),'t':float(t[i]),'p':float(p[i])} for i,name in enumerate(terms)},
      'covariance':v.tolist(),'coefficient_order':terms,'full_dummy_max_slope_difference':delta,
      'joint_F':None,'joint_p':None,'joint_df1':None}
    lags=[f'skew_l{i}' for i in range(1,5)]
    if all(a in xvars for a in lags):
        ii=[terms.index(a) for a in lags]
        w=float(b[ii]@np.linalg.solve(v[np.ix_(ii,ii)],b[ii])/4)
        result.update(joint_F=w,joint_p=f_p(w,4,df),joint_df1=4)
    return result


def specs():
    return {
      1:(['skew_l1'],()),
      2:(['skew_l1']+CONTROLS[:2],()),
      3:(['skew_l1']+CONTROLS[:7],()),
      4:(['skew_l1']+CONTROLS+[MR],()),
      5:(['skew_l1']+CONTROLS+[MR],('ff30','yr')),
      6:(['skew_l2']+CONTROLS+[MR],('ff30','yr')),
      7:(['skew_l3']+CONTROLS+[MR],('ff30','yr')),
      8:(['skew_l4']+CONTROLS+[MR],('ff30','yr')),
      9:([f'skew_l{i}' for i in range(1,5)]+CONTROLS+[MR],('ff30','yr'))}

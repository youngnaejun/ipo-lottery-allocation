from pathlib import Path
import sys, os, json, hashlib, re
import pandas as pd
import numpy as np
R=Path(r"@RUN_ROOT@\ext\0928-1002")
T=Path(r"@RUN_ROOT@\ext\recovered61-complete")
O=T/"results"; O.mkdir(exist_ok=True)
P=Path("@RUN_ROOT@")
W=Path("@RUN_ROOT@/ext/recovered61-wrds")
def read(name):
    d=pd.read_sas(W/(name+".sas7bdat"))
    for c in d.select_dtypes("object"):
        d[c]=d[c].map(lambda x:x.decode("utf8") if isinstance(x,bytes) else x)
    return d
def dump(name,obj):
    (O/name).write_text(json.dumps(obj,indent=2,default=str),encoding="utf8")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
base=pd.read_pickle(R/"results/recovered61/Baseline_analysis.pkl")
ex=pd.read_pickle(R/"results/recovered61/Expanded_analysis.pkl")
oldex=ex.copy()
wr=read("complete_results")
checks=read("baseline_comparison")
assert len(wr)==wr.permno.nunique() and (@PAPER_CHECKS@==0 or len(wr)==71)
assert len(checks)==7*int(wr.role.eq('baseline_validation').sum()) and checks.passed.eq(1).all() and (@PAPER_CHECKS@==0 or len(checks)==70)
newmask=ex.restored61.eq(1)
new=ex.loc[newmask].copy()
got=wr[wr.role.eq("recovered61")].set_index("permno").loc[new.PERMNO]
assert len(got)==len(new) and (@PAPER_CHECKS@==0 or len(got)==61) and np.array_equal(got.idate.to_numpy(),new.idate.to_numpy())
assert np.allclose(got.ff30,new.ff30) and np.allclose(got.r0,new.r0)
existing=new.coskewness.notna().to_numpy()
assert @PAPER_CHECKS@==0 or existing.sum()==44
coskdiff=got.coskewness.to_numpy()[existing]-new.coskewness.to_numpy()[existing]
assert np.allclose(coskdiff,0,atol=1e-8,rtol=1e-8)
variables=["coskewness"]+[f"r{k}_bhar_{y}y" for k in [2,3] for y in [1,3,5]]
for v in variables: ex.loc[newmask,v]=got[v].to_numpy()
ex.loc[newmask,"coskewness_source"]="WRDS 20260930 full-universe global winsorization"
pd.testing.assert_frame_equal(ex.loc[~newmask].reset_index(drop=True),oldex.loc[~newmask].reset_index(drop=True))
base.to_pickle(O/"Baseline_analysis.pkl"); ex.to_pickle(O/"Expanded_analysis.pkl")
ex.loc[newmask].to_csv(O/"Recovered61_variables_complete.csv",index=False)
# Native SAS datasets retain precision that formatted RET CSV fields do not.
daily=read("crsp_ipo_daily"); daily.columns=daily.columns.str.lower()
daily["date"]=pd.to_datetime(daily.date,unit="D",origin="1960-01-01")
assert not daily.duplicated(["permno","date"]).any()
daily=daily.merge(wr[["permno","idate","r0","role"]],on="permno",validate="many_to_one")
daily=daily[daily.date.ge(daily.idate)].sort_values(["permno","date"]).copy()
daily["n"]=daily.groupby("permno").cumcount()+1
first=daily.n.eq(1)&daily.ret.isna()
daily.loc[first,"ret"]=daily.loc[first,"r0"]
daily["adjusted"]=daily.ret
dl=daily.dlret.notna()
daily.loc[dl,"adjusted"]=(1+daily.loc[dl,"ret"].fillna(0))*(1+daily.loc[dl,"dlret"])-1
bad=daily.adjusted.le(-1)
daily.loc[bad].to_csv(O/"Nonpositive_gross_return_events.csv",index=False)
return_rows=[]
for perm,z in daily.groupby("permno"):
    ref=wr.set_index("permno").loc[perm]
    for k in [2,3]:
        lo=2 if k==2 else 1
        for years in [1,3,5]:
            hi=252*years+(1 if k==2 else 0)
            v=z[z.n.between(lo,hi)].adjusted.dropna()
            # Preserve original SAS SUM(LOG()) behavior, including its edge case.
            positive=v[v.gt(-1)]
            sas=float(np.expm1(np.log1p(positive).sum())) if len(positive) else np.nan
            product=float(np.prod(1+v)-1) if len(v) else np.nan
            stored=float(ref[f"r{k}_bhar_{years}y"])
            assert np.isclose(sas,stored,atol=1e-9,rtol=1e-9,equal_nan=True),(perm,k,years,sas,stored)
            return_rows.append(dict(permno=int(perm),role=ref.role,idate=ref.idate,measure=f"r{k}_bhar_{years}y",years=years,stored=stored,python_original=sas,product_corrected=product,log_nonpositive_count=int((v<=-1).sum()),rows_available=int(z.n.between(lo,hi).sum()),valid_returns=len(v),required_event_rows=252*years,full_event_window=bool(z.n.max()>=hi),last_observed=z.date.max(),delisting_observed=bool(z.dlret.notna().any())))
retqa=pd.DataFrame(return_rows); retqa.to_csv(O/"Return_window_and_formula_audit.csv",index=False)
# Independently pool monthly sums/counts over the exact previous 3 calendar months.
monthly=read("coskewness_monthly_sums")
monthly["month"]=pd.to_datetime(monthly.yearmonth)
cosk_rows=[]
for row in wr.itertuples():
    month=pd.Timestamp(row.idate).to_period("M").to_timestamp()
    v=monthly[monthly.ff30.eq(row.ff30)&monthly.month.ge(month-pd.DateOffset(months=3))&monthly.month.lt(month)]
    n=v.n_cosk.sum(); value=v.sum_cosk.sum()/n
    assert np.isclose(value,row.coskewness,atol=1e-8,rtol=1e-8),(row.permno,value,row.coskewness)
    assert int(n)==int(row.n_cosk)
    cosk_rows.append(dict(permno=int(row.permno),coskewness=row.coskewness,rebuilt=value,n_cosk=int(n),difference=value-row.coskewness))
pd.DataFrame(cosk_rows).to_csv(O/"Coskewness_pooling_checks.csv",index=False)
logs=(W/"run.log").read_text(errors="replace")
issues=[line for line in logs.splitlines() if line.startswith(("ERROR:","WARNING:")) or "Invalid argument to function LOG" in line]
(O/"WRDS_log_review.txt").write_text("\n".join(issues),encoding="utf8")
qa=dict(targets=len(wr),recovered=int(newmask.sum()),baseline_checks=len(checks),baseline_passed=int(checks.passed.sum()),linked_on="PERMNO and issue date",coskewness_existing_matches=True,coskewness_existing_max_difference=float(abs(coskdiff).max()) if len(coskdiff) else 0.0,new_coskewness_filled=int((~existing).sum()),return_values_independently_rebuilt=len(retqa),coskewness_pools_rebuilt=len(cosk_rows),daily_rows=len(daily),observation_cutoff=str(daily.date.max().date()),nonpositive_gross_events=int(bad.sum()),nonpositive_permnos=daily.loc[bad,"permno"].astype(int).tolist(),affected_new_return_values=int(((retqa.role=="recovered61")&retqa.log_nonpositive_count.gt(0)).sum()),baseline_rows_unchanged=True)
dump("Input_QA.json",qa)
print(json.dumps(qa,indent=2),flush=True)
# Freeze hashes of inputs actually used and original source code.
paths=list(W.glob("*"))+[R/"results/recovered61"/n for n in ["Baseline_analysis.pkl","Expanded_analysis.pkl"]]+[Path("@RUN_ROOT@/ext/ipo-20260921-25/t11_design_diag_deals.dta"),P/"stata/sdc_fullhistory_parsed_20260903.csv",P/"master/crsp_index_daily.sas7bdat"]
dump("Provenance.json",[dict(path=str(p),sha256=sha(p),bytes=p.stat().st_size) for p in paths if p.is_file()])
# Numeric-only input for exact SAS Table 2 mean/median tests.
frames=[]
for label,d in [("baseline",base),("expanded_complete",ex)]:
    d=d.copy();d["variant"]=label
    frames.append(d[["variant","PERMNO","ipo_year","skew1","r0","r2_bhar_3y","r3_bhar_3y"]])
pd.concat(frames).to_csv(O/"Table2_SAS_input.csv",index=False)
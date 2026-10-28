from pathlib import Path
import pandas as pd,numpy as np,json
W=Path(r"@RUN_ROOT@\ext\ipo-20260921-25")
R=Path(r"@RUN_ROOT@\ext\shared_root")
S=Path(r"@RUN_ROOT@\stata")
d=pd.read_csv(W/"t11_three_definitions_deal_audit.csv",dtype={"deal_num":str})
a=pd.read_stata(S/"analysis_full2.dta",convert_dates=False,convert_categoricals=False)
a.deal_num=a.deal_num.str.strip()
a["source_deal_num"]=a.deal_num
fields=["age_ritter","share_overhang","uw_rank_ave","VB","pure_primary","lagmcsi","ipo_vol","Full_History_Amount_Filed_This_M","source_deal_num"]
m=d.merge(a[["deal_num"]+fields],on="deal_num",how="left",validate="one_to_one",indicator=True)
# Alternative SDC deal IDs are linked only through a unique identical CRSP security and issue date.
un=m._merge.eq("left_only")
available=a.loc[~a.source_deal_num.isin(m.source_deal_num.dropna())].copy()
unique_target=~m.duplicated(["PERMNO","idate"],keep=False)
alt=m.loc[un & unique_target,["deal_num","PERMNO","idate"]].merge(available[["PERMNO","idate"]+fields],on=["PERMNO","idate"],how="left",validate="one_to_one").set_index("deal_num")
for c in fields:m.loc[un,c]=m.loc[un,"deal_num"].map(alt[c]).to_numpy()
m["join_route"]=np.where(~un,"SDC deal ID",np.where(m.source_deal_num.notna(),"unique PERMNO and issue date","unmatched"))
def first_amount(x):
 if not isinstance(x,str):return np.nan
 parts=[v for v in x.split(";") if v.strip()]
 return pd.to_numeric(parts[0].replace(",","").replace("$","").strip(),errors="coerce") if parts else np.nan
m["expected_amount"]=m.Full_History_Amount_Filed_This_M.map(first_amount)
m["lnexpected"]=np.log((m.expected_amount*m.factor).where(m.expected_amount.gt(0)))
# Verify original control formula on records present in the previous price-revision sample.
pr=pd.read_stata(S/"price_revision_sample.dta",convert_dates=False,convert_categoricals=False)
chk=m.merge(pr[["deal_num","ln_amount_filed_adj1975"]],left_on="source_deal_num",right_on="deal_num")
assert np.allclose(chk.lnexpected,chk.ln_amount_filed_adj1975,equal_nan=True)
mapping={"age_ritter":"age","share_overhang":"overhang","uw_rank_ave":"uwrank","VB":"vcshare","pure_primary":"primaryshare","lagmcsi":"optimism","ipo_vol":"ipovol"}
m=m.rename(columns=mapping)
cohort=["age","lnexpected","overhang","uwrank","vcshare","primaryshare","optimism","ipovol"]
for c in ["vcshare","primaryshare"]:assert m[c].dropna().isin([0,1]).all()
g=m.groupby(["ff30","qdate"])
means=g[cohort].mean();counts=g[cohort].count().add_prefix("n_")
agg=means.join(counts).join(g.actual.sum().rename("adjusted_total")).join(g.size().rename("n_ipo")).reset_index().rename(columns={"qdate":"time_id"})
p=pd.read_stata(R/"20260914-18/workstream 2/ws2_quarterly_recovered61_20260917.dta",convert_dates=False,convert_categoricals=False)
p=p.merge(agg,on=["ff30","time_id"],how="left",validate="one_to_one")
empty=p.n_primary.eq(0)
p.loc[empty,cohort+["adjusted_total","n_ipo"]+["n_"+c for c in cohort]]=0
assert (p.n_ipo==p.n_primary).all()
assert int(p.n_ipo.sum())==len(m)
assert np.isclose(p.adjusted_total.sum(),m.actual.sum())
p["t11"]=np.log1p(p.adjusted_total)
p["t12"]=p.n_primary
p["t13"]=p.adjusted_total/p.n_primary.where(p.n_primary>0)
base=pd.read_stata(S/"filing_quarter_panel.dta",convert_dates=False,convert_categoricals=False)
base["lnfirms"]=np.log(base.listed_firms.where(base.listed_firms>0))
base=base.rename(columns={"qdate":"time_id","industry_return_refresh":"indret","industry_momentum_refresh":"indmom","industry_ivol":"indvol","industry_turnover":"indturn"})
industry=["indret","indmom","indvol","indturn","lnfirms"]
base=base.sort_values(["ff30","time_id"])
for c in industry:base["l1_"+c]=base.groupby("ff30")[c].shift()
p=p.merge(base[["ff30","time_id"]+industry+["l1_"+c for c in industry]],on=["ff30","time_id"],how="left",validate="one_to_one")
for c,old in zip(industry,["lag_return","lag_momentum","lag_ivol","lag_turnover","lag_lnfirms"]):
 assert np.allclose(p["l1_"+c],p[old],equal_nan=True),c
p=p.sort_values(["ff30","time_id"])
for c in cohort:p["l1_"+c]=p.groupby("ff30")[c].shift()
# First-quarter cohort lag is unavailable: never treat out-of-window data as a no-IPO quarter.
coskpath=W/"industry_quarter_coskewness.csv"
cosk_ready=coskpath.exists()
if cosk_ready:
 c=pd.read_csv(coskpath).sort_values(["ff30","time_id"])
 assert not c.duplicated(["ff30","time_id"]).any()
 # Explicit quarterly-key join ensures no shifting across gaps.
 lag=c[["ff30","time_id","cosk"]].copy();lag.time_id+=1;lag=lag.rename(columns={"cosk":"l1_cosk"})
 p=p.merge(c[["ff30","time_id","cosk"]],how="left",on=["ff30","time_id"],validate="one_to_one").merge(lag,how="left",on=["ff30","time_id"],validate="one_to_one")
else:
 p["cosk"]=np.nan;p["l1_cosk"]=np.nan
for c in cohort+industry+["cosk"]:p=p.rename(columns={c:"q_"+c,"l1_"+c:"l_"+c})
p.to_stata(W/"t11_t13_confirmed_panel.dta",write_index=False,version=118)
m[["deal_key","deal_num","source_deal_num","join_route","ff30","qdate","actual"]+cohort].to_csv(W/"t11_t13_deal_controls_audit.csv",index=False)
cov=pd.DataFrame([{"control":c,"deal_nonmissing":int(m[c].notna().sum()),"active_cells_all_missing":int(p.loc[~empty,"q_"+c].isna().sum()),"q_panel_nonmissing":int(p["q_"+c].notna().sum()),"lag_panel_nonmissing":int(p["l_"+c].notna().sum())} for c in cohort])
cov.to_csv(W/"t11_t13_control_coverage.csv",index=False)
audit={"n_deals":len(m),"n_cells":len(p),"active_cells":int((p.n_primary>0).sum()),"zero_cells":int(empty.sum()),"join_routes":m.join_route.value_counts().to_dict(),"expected_control_verified_against_prior_rows":len(chk),"cosk_ready":cosk_ready,"first_cohort_lag_quarter_unavailable":"1983Q1; 1982Q4 cohort not present in frozen eligible frame"}
(W/"t11_t13_build_audit.json").write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2));print(cov.to_string(index=False))


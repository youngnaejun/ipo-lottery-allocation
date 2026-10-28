import pandas as pd,numpy as np,json
from pathlib import Path
r=Path(r"@RUN_ROOT@\ext\shared_root")
s=Path(r"@RUN_ROOT@\stata")
out=Path(r"@RUN_ROOT@\ext\ipo-20260921-25")
d=pd.read_stata(r/"20260914-18/workstream 2/ws2_eligible8905_deals_20260917.dta",convert_dates=False,convert_categoricals=False)
k=pd.read_stata(s/"filing_completion_analysis.dta",convert_dates=False,convert_categoricals=False)
d=d.merge(k[["deal_key","deal_num","initial_file_midpoint"]],on="deal_key",validate="one_to_one")
h=pd.read_csv(s/"sdc_fullhistory_parsed_20260903.csv",dtype={"sdc_deal":str}).rename(columns={"sdc_deal":"deal_num"})
d["deal_num"]=d.deal_num.str.strip()
d=d.merge(h[["deal_num","pri_first","mid_first","fh_first_date","tot_first"]],on="deal_num",how="left",validate="one_to_one")
a=pd.read_stata(s/"analysis_full2.dta",convert_dates=False,convert_categoricals=False)
a["factor"]=a.proceeds_adj1975/a.proceeds_mil
f=a.loc[np.isfinite(a.factor)&a.factor.gt(0)].groupby("ipo_year").factor.agg(["min","max","median"])
assert np.allclose(f["min"],f["max"])
d["ipo_year"]=pd.to_datetime(d.idate,unit="D",origin="1960-01-01").dt.year
d["factor"]=d.ipo_year.map(f["median"])
assert d.factor.notna().all()
d["valid"]=(d.pri_first.gt(0)&d.mid_first.gt(0)&d.oprc.gt(0)&(pd.to_datetime(d.fh_first_date)<=pd.to_datetime(d.idate,unit="D",origin="1960-01-01")))
d["actual"]=d.oprc*d.primary_shares/1e6*d.factor
d["planned"]=d.mid_first*d.pri_first/1e6*d.factor
d["hybrid"]=d.oprc*d.pri_first/1e6*d.factor
assert np.allclose(d.oprc*d.primary_shares/1e6,d.primary_nominal)
g=d.groupby(["ff30","qdate"]).agg(n_all=("deal_key","size"),n_valid=("valid","sum"),actual=("actual","sum"),planned=("planned","sum"),hybrid=("hybrid","sum")).reset_index().rename(columns={"qdate":"time_id"})
p=pd.read_stata(r/"20260914-18/workstream 2/ws2_quarterly_recovered61_20260917.dta",convert_dates=False,convert_categoricals=False)
p=p.merge(g,on=["ff30","time_id"],how="left",validate="one_to_one")
for c in ["n_all","n_valid","actual","planned","hybrid"]: p[c]=p[c].fillna(0)
assert (p.n_all==p.n_primary).all()
p["common"]=(p.n_all==p.n_valid).astype(int)
for c in ["actual","planned","hybrid"]: p["ln_"+c]=np.log1p(p[c].where(p.common.eq(1)))
p["ln_actual_full"]=np.log1p(p.actual)
p.to_stata(out/"t11_three_definitions_panel.dta",write_index=False,version=118)
d.to_csv(out/"t11_three_definitions_deal_audit.csv",index=False)
audit={"eligible_ipos":len(d),"initial_primary_missing":int(d.pri_first.isna().sum()),"initial_primary_zero":int(d.pri_first.eq(0).sum()),"initial_primary_negative":int(d.pri_first.lt(0).sum()),"valid_positive_initial_deals":int(d.valid.sum()),"all_panel_cells":len(p),"common_cells":int(p.common.sum()),"common_positive_cells":int(((p.common==1)&(p.n_all>0)).sum()),"common_ipos":int(p.loc[p.common.eq(1),"n_all"].sum()),"true_zero_cells":int(p.n_all.eq(0).sum()),"excluded_incomplete_cells":int(p.common.eq(0).sum())}
(out/"t11_three_definitions_audit.json").write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))

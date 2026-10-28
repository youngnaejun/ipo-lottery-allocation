import pandas as pd, numpy as np
p = pd.read_stata("t11_t13_confirmed_panel.dta", convert_categoricals=False)

# Extensive / intensive split of the T11 total on active cells.
act = p.n_primary > 0
p["ln_count"]  = np.log(p.n_primary.where(act))
p["ln_avg"]    = np.log(p.t13.where(act))
p["ln_total"]  = np.log(p.adjusted_total.where(act))
p["any_ipo"]   = act.astype(float)
p.to_stata("t11_design_diag_panel.dta", write_index=False, version=118)

# Deal-level file: each completed IPO with the industry skewness of its filing quarter.
d = pd.read_csv("t11_t13_deal_controls_audit.csv")
keys = ["ff30", "time_id"]
ind  = ["skew_l1","skew_l2","skew_l3","skew_l4",
        "q_cosk","q_indret","q_indmom","q_indvol","q_indturn","q_lnfirms",
        "l_cosk","l_indret","l_indmom","l_indvol","l_indturn","l_lnfirms"]
d = d.rename(columns={"qdate": "time_id"}).merge(p[keys + ind], on=keys, how="left", validate="many_to_one")
d["ln_actual"] = np.log(d.actual)
assert d.skew_l1.notna().all(), "every deal quarter must exist in the panel"
assert len(d) == int(p.n_primary.sum())
d.to_stata("t11_design_diag_deals.dta", write_index=False, version=118)

print("panel", p.shape, "active", int(act.sum()))
print("deals", d.shape)
print(d[["ln_actual","skew_l1"]].describe().T.to_string())
print("deals per cell:", d.groupby(keys).size().describe().to_string())

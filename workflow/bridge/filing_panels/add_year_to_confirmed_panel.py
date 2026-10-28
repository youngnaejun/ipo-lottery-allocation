"""Write t11_yearfe_confirmed.dta: t11_t13_confirmed_panel.dta plus yr = calendar year of the quarterly
time_id (Stata %tq origin 1960q1). Usage: add_year_to_confirmed_panel.py <source.dta> <destination.dta>"""
import sys
import pandas as pd
src, dst = sys.argv[1], sys.argv[2]
p = pd.read_stata(src, convert_dates=False, convert_categoricals=False)
p["yr"] = (p.time_id // 4 + 1960).astype("int16")
p.to_stata(dst, write_index=False, version=118)
print(len(p), "rows; yr range", int(p.yr.min()), int(p.yr.max()))

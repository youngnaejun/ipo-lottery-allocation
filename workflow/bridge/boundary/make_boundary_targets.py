"""Reconstruct targets.csv for the -100% boundary extract (no saved script):
PERMNO, issue date (YYYY-MM-DD) and R0 for each IPO in the final expanded analysis data."""
import sys
import pandas as pd
e = pd.read_pickle(sys.argv[1])
t = pd.DataFrame({"PERMNO": e.PERMNO, "idate": pd.to_datetime(e.idate).dt.strftime("%Y-%m-%d"), "r0": e.r0})
t.to_csv(sys.argv[2], index=False)
print(len(t), "targets")

# Stata empirical analysis

These files are the current journal-analysis layer. They read private SAS
datasets from the workspace named by `IPO_LOTTERY_ROOT` and write results below
that private root. No `.dta`, estimate, table or log output is distributed here.

`analysis.do` contains the broader Tables 1–3 workflow. `Table 3_additional
controls.do` is the latest located nested Table 3 specification, and `Appendix
B.do` contains one- and five-year return-horizon robustness analysis. Absolute
local paths have been replaced with the environment-variable contract; the
empirical commands are otherwise retained in their working language.


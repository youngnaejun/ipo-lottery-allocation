* Paper tables (1-7, B1-B4, IA1-IA3): master do-file.
* Usage (batch):  StataMP-64.exe /e do 00_master.do <data_dir> <out_dir>
* Inputs are the four .dta files written by export_stata_inputs.py.
* Every table do-file posts one row per coefficient to <out_dir>/results_<table>.csv
* (table, panel, column, term, b, se, stat, p, N, fit) and its estimation samples.
version 19
clear all
set more off
set varabbrev off
args data out
if "`data'"=="" | "`out'"=="" {
    display as error "usage: do 00_master.do <data_dir> <out_dir>"
    exit 198
}
global DATA "`data'"
global OUT  "`out'"
capture mkdir "$OUT"
log using "$OUT/00_master.log", replace text
display "Stata " c(stata_version) " " c(born_date) "  data=$DATA  out=$OUT"
foreach p in reghdfe ftools ppmlhdfe {
    which `p'
}
local here = c(pwd)
foreach f in 01_table1 02_table2 03_returns 04_panels 06_revisions 08_appendix_b3_b4 09_internet_appendix_ppml {
    display as result "==== `f'"
    do "`here'/`f'.do"
}
log close

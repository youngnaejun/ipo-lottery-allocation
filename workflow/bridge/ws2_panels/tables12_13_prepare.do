version 19
clear all
set more off
cd "@RUN_ROOT@/ext/ipo-ws2a-tables-20260914"
log using "tables12_13_prepare.log", replace text
which ppmlhdfe
which reghdfe
tempfile qlags mlags
use "@RUN_ROOT@/stata/filing_quarter_panel.dta", clear
xtset ff30 qdate
forvalues k=1/4 {
 gen double skew_l`k'=L`k'.industry_skew
}
keep ff30 qdate skew_l1-skew_l4
rename qdate time_id
save `qlags'
import sas using "@RUN_ROOT@/master/exp_skew_panel.sas7bdat", clear
gen int time_id=mofd(yearmonth)
xtset ff30 time_id
forvalues k=1/4 {
 gen double skew_l`k'=L`k'.skew1
}
keep ff30 time_id skew_l1-skew_l4
save `mlags'
foreach freq in quarterly monthly {
 use "table11_nominal_`freq'_panel.dta", clear
 local lagfile `qlags'
 if "`freq'"=="monthly" local lagfile `mlags'
 merge 1:1 ff30 time_id using `lagfile', keep(master match) assert(master match using) nogen
 assert abs(lag_skew-skew_l1)<1e-10 if !missing(lag_skew,skew_l1)
 egen missing_all=rowmiss(skew_l1-skew_l4 lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms)
 count if missing_all>0
 count if n_ipo>0
 gen double avg_primary=nominal_total/n_ipo if n_ipo>0
 gen double ln1p_avg_primary=ln(1+avg_primary) if !missing(avg_primary)
 assert abs(nominal_total-n_ipo*avg_primary)<1e-6 if n_ipo>0
 count if n_ipo>0 & avg_primary==0
 save "tables12_13_`freq'_prepared.dta", replace
}
log close
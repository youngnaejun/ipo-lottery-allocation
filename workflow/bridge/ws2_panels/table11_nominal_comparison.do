version 19
clear all
set more off
cd "@RUN_ROOT@/ext/ipo-ws2a-tables-20260914"
log using "table11_nominal_comparison.log", replace text
postfile out str12(freq) str24(term) double(b se stat p N adjr2 withinr2 df) using "table11_nominal_results.dta", replace
foreach freq in quarterly monthly {
 use "table11_deal_audit.dta", clear
 assert abs(primary_nominal-oprc*primary_shares/1000000)<1e-8
 local period qdate
 if "`freq'"=="monthly" local period mdate
 collapse (sum) nominal_total=primary_nominal, by(ff30 `period')
 rename `period' time_id
 tempfile agg
 save `agg'
 use "table11_`freq'_panel.dta", clear
 merge 1:1 ff30 time_id using `agg', assert(master match) gen(merge_nominal)
 assert merge_nominal==3 if n_ipo>0
 assert merge_nominal==1 if n_ipo==0
 replace nominal_total=0 if merge_nominal==1
 gen double nominal_outcome=ln(1+nominal_total)
 reghdfe nominal_outcome lag_skew lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms, absorb(ff30 time_id) vce(cluster ff30 time_id)
 assert e(sample)==estimation_sample
 estimates save "table11_nominal_`freq'.ster", replace
 foreach x in lag_skew lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms _cons {
  scalar bb=_b[`x']
  scalar ss=_se[`x']
  scalar tt=bb/ss
  scalar pp=2*ttail(e(df_r),abs(tt))
  post out ("`freq'") ("`x'") (bb) (ss) (tt) (pp) (e(N)) (e(r2_a)) (e(r2_within)) (e(df_r))
 }
 save "table11_nominal_`freq'_panel.dta", replace
}
postclose out
use "table11_nominal_results.dta", clear
export delimited using "table11_nominal_results.csv", replace
log close
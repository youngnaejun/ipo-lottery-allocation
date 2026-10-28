version 19
clear all
set more off
cd "@RUN_ROOT@/ext/ipo-ws2a-tables-20260914"
log using "tables12_13_estimate.log", replace text
postfile out str12 freq byte table col str24 term double b se stat p N fit df jointp using "tables12_13_results.dta", replace
foreach freq in quarterly monthly {
 use "table11_deal_audit.dta", clear
 keep if primary_nominal>0 & primary_nominal<.
 if @PAPER_CHECKS@ assert _N==8844
 local period qdate
 if "`freq'"=="monthly" local period mdate
 collapse (count) n_primary=primary_nominal (sum) positive_total=primary_nominal, by(ff30 `period')
 rename `period' time_id
 tempfile counts
 save `counts'
 use "tables12_13_`freq'_prepared.dta", clear
 merge 1:1 ff30 time_id using `counts', assert(master match) nogen
 replace n_primary=0 if missing(n_primary)
 replace positive_total=0 if missing(positive_total)
 assert abs(positive_total-nominal_total)<1e-6
 assert missing_all==0
 replace avg_primary=nominal_total/n_primary if n_primary>0
 replace avg_primary=. if n_primary==0
 replace ln1p_avg_primary=ln(1+avg_primary)
 assert avg_primary>0 if n_primary>0
 summarize n_primary
 if @PAPER_CHECKS@ assert r(sum)==8844
 foreach tab in 12 13 {
  forvalues col=1/5 {
   local xs skew_l`col'
   if `col'==5 local xs skew_l1 skew_l2 skew_l3 skew_l4
   if `tab'==12 {
    ppmlhdfe n_primary `xs' lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms, absorb(ff30 time_id) vce(cluster ff30 time_id)
    assert e(converged)==1
    scalar fit=e(r2_p)
    scalar df=.
   }
   else {
    reghdfe ln1p_avg_primary `xs' lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms if n_primary>0, absorb(ff30 time_id) vce(cluster ff30 time_id)
    scalar fit=e(r2_a)
    scalar df=e(df_r)
   }
   estimates save "table`tab'_`freq'_col`col'.ster", replace
   gen byte sample_t`tab'_c`col'=e(sample)
   scalar jp=.
   if `col'==5 {
    test skew_l1 skew_l2 skew_l3 skew_l4
    scalar jp=r(p)
   }
   foreach x in `xs' lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms _cons {
    scalar bb=_b[`x']
    scalar ss=_se[`x']
    scalar tt=bb/ss
    scalar pp=2*normal(-abs(tt))
    if `tab'==13 scalar pp=2*ttail(df,abs(tt))
    post out ("`freq'") (`tab') (`col') ("`x'") (bb) (ss) (tt) (pp) (e(N)) (fit) (df) (jp)
   }
  }
 }
 save "tables12_13_`freq'_estimated.dta", replace
}
postclose out
use "tables12_13_results.dta", clear
export delimited using "tables12_13_results.csv", replace
log close

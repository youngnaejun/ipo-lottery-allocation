version 19
clear all
set more off
cd "@RUN_ROOT@/ext/ipo-ws2a-tables-20260914"
log using "table11_quarter_month.log", replace text
tempfile deflator deals qa ma skew ret mom ivol turn firms monthly
use "@RUN_ROOT@/stata/analysis_full2.dta", clear
gen double deflator=proceeds_adj1975/proceeds_mil if proceeds_adj1975>0 & proceeds_mil>0 & !missing(proceeds_adj1975,proceeds_mil)
keep if !missing(ipo_year,deflator)
collapse (mean) deflator (min) lo=deflator (max) hi=deflator, by(ipo_year)
assert abs(hi-lo)<1e-10
keep ipo_year deflator
save `deflator'
use "@RUN_ROOT@/stata/filing_completion_analysis.dta", clear
keep if completed_live==1 & crsp_live_validated==1
if @PAPER_CHECKS@ assert _N==9412
keep if inrange(ff30,1,29)
if @PAPER_CHECKS@ assert _N==9048
capture drop ipo_year
gen int ipo_year=year(idate)
merge m:1 ipo_year using `deflator', keep(master match) nogen
assert !missing(deflator,oprc,primary_shares,fdate,idate)
assert oprc>0 & primary_shares>=0
count if fdate>idate
gen double primary_nominal=oprc*primary_shares/1000000
gen double primary_scaled=primary_nominal*deflator
gen int qdate=qofd(fdate)
gen int mdate=mofd(fdate)
assert inrange(qdate,yq(@FILING_START_YEAR@,1),yq(@SAMPLE_END_YEAR@,4))
assert inrange(mdate,ym(@FILING_START_YEAR@,1),ym(@SAMPLE_END_YEAR@,12))
gen byte one=1
save "table11_deal_audit.dta", replace
preserve
collapse (sum) total_primary=primary_scaled n_ipo=one, by(ff30 qdate)
save `qa'
restore
collapse (sum) total_primary=primary_scaled n_ipo=one, by(ff30 mdate)
save `ma'
import sas using "@RUN_ROOT@/master/exp_skew_panel.sas7bdat", clear
keep ff30 yearmonth skew1
gen int mdate=mofd(yearmonth)
rename skew1 industry_skew
keep ff30 mdate industry_skew
isid ff30 mdate
save `skew'
import sas using "@RUN_ROOT@/master/ff30_ret_refresh.sas7bdat", clear
gen int mdate=mofd(yearmonth)
rename in_ewlagmret_refresh industry_return
keep ff30 mdate industry_return
isid ff30 mdate
save `ret'
import sas using "@RUN_ROOT@/master/ff30_mom_refresh.sas7bdat", clear
gen int mdate=mofd(yearmonth)
rename ind_mom_refresh industry_momentum
keep ff30 mdate industry_momentum
isid ff30 mdate
save `mom'
import sas using "@RUN_ROOT@/master/ff30_ivol.sas7bdat", clear
gen int mdate=mofd(yearmonth)
rename lagin_ivol industry_ivol
keep ff30 mdate industry_ivol
isid ff30 mdate
save `ivol'
import sas using "@RUN_ROOT@/master/ff30_turnover.sas7bdat", clear
gen int mdate=mofd(yearmonth)
rename in_lagturnover industry_turnover
keep ff30 mdate industry_turnover
isid ff30 mdate
save `turn'
import sas using "@RUN_ROOT@/master/crsp_monthly.sas7bdat", clear
rename (PERMNO SHRCD EXCHCD) (permno shrcd exchcd)
keep if inrange(ff30,1,29) & inlist(shrcd,10,11) & inlist(exchcd,1,2,3)
gen int mdate=mofd(yearmonth)
keep if inrange(mdate,ym(@FILING_START_YEAR@-1,1),ym(@SAMPLE_END_YEAR@,12))
keep ff30 mdate permno
duplicates drop
collapse (count) listed_firms=permno, by(ff30 mdate)
save `firms'
clear
set obs 29
gen byte ff30=_n
expand ym(@SAMPLE_END_YEAR@,12)-ym(@FILING_START_YEAR@-1,1)+1
bysort ff30: gen int mdate=ym(@FILING_START_YEAR@-1,1)+_n-1
foreach f in skew ret mom ivol turn firms {
 merge 1:1 ff30 mdate using ``f'', keep(master match) nogen
}
xtset ff30 mdate
foreach v in skew return momentum ivol turnover {
 gen double lag_`v'=L.industry_`v'
}
gen double lag_lnfirms=ln(L.listed_firms) if L.listed_firms>0 & !missing(L.listed_firms)
keep if inrange(mdate,ym(@FILING_START_YEAR@,1),ym(@SAMPLE_END_YEAR@,12))
merge 1:1 ff30 mdate using `ma', assert(master match) nogen
replace total_primary=0 if missing(n_ipo)
replace n_ipo=0 if missing(n_ipo)
gen double outcome=ln(1+total_primary)
rename mdate time_id
save "table11_monthly_panel.dta", replace
use "@RUN_ROOT@/stata/filing_quarter_panel.dta", clear
keep if inrange(qdate,yq(@FILING_START_YEAR@,1),yq(@SAMPLE_END_YEAR@,4))
keep ff30 qdate l1_industry_skew l1_industry_return_refresh l1_industry_momentum_refresh l1_industry_ivol l1_industry_turnover l1_listed_firms
rename (l1_industry_skew l1_industry_return_refresh l1_industry_momentum_refresh l1_industry_ivol l1_industry_turnover) (lag_skew lag_return lag_momentum lag_ivol lag_turnover)
gen double lag_lnfirms=ln(l1_listed_firms) if l1_listed_firms>0 & !missing(l1_listed_firms)
merge 1:1 ff30 qdate using `qa', assert(master match) nogen
replace total_primary=0 if missing(n_ipo)
replace n_ipo=0 if missing(n_ipo)
gen double outcome=ln(1+total_primary)
rename qdate time_id
save "table11_quarterly_panel.dta", replace
postfile out str12(freq) str24(term) double(b se stat p N adjr2 withinr2 df) using "table11_results.dta", replace
postfile fits str12(freq) double(cells N n_ipo zero_cells missing_cells total_scaled groups times) using "table11_fit.dta", replace
foreach freq in quarterly monthly {
 use "table11_`freq'_panel.dta", clear
 scalar cells=_N
 egen missing_x=rowmiss(outcome lag_skew lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms)
 count if missing_x>0
 scalar misscells=r(N)
 reghdfe outcome lag_skew lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms, absorb(ff30 time_id) vce(cluster ff30 time_id)
 estimates save "table11_`freq'.ster", replace
 gen byte estimation_sample=e(sample)
 scalar nn=e(N)
 scalar ar=e(r2_a)
 scalar wr=e(r2_within)
 scalar df=e(df_r)
 scalar groups=e(N_clust1)
 scalar times=e(N_clust2)
 foreach x in lag_skew lag_return lag_momentum lag_ivol lag_turnover lag_lnfirms _cons {
  scalar bb=_b[`x']
  scalar ss=_se[`x']
  scalar tt=bb/ss
  scalar pp=2*ttail(df,abs(tt))
  post out ("`freq'") ("`x'") (bb) (ss) (tt) (pp) (nn) (ar) (wr) (df)
 }
 count if estimation_sample & n_ipo==0
 scalar nz=r(N)
 summarize n_ipo if estimation_sample, meanonly
 scalar ni=r(sum)
 summarize total_primary if estimation_sample, meanonly
 scalar total=r(sum)
 post fits ("`freq'") (cells) (nn) (ni) (nz) (misscells) (scalar(total)) (groups) (times)
 save "table11_`freq'_panel.dta", replace
}
postclose out
postclose fits
use "table11_results.dta", clear
export delimited using "table11_results.csv", replace
use "table11_fit.dta", clear
export delimited using "table11_fit.csv", replace
log close
* Appendix Table B3: probit of an upward price revision, average marginal effects
*   (indicator controls treated as continuous, robust delta-method z; McFadden pseudo R2).
* Appendix Table B4: OLS of the offer-price position in the initial range; (6) adds Range Width.
* Columns (4) add year FE; (5)-(6) add industry controls and FF30 FE.
do "`c(pwd)'/_post.do"
use "$DATA/revisions.dta", clear
local firm age_ritter coskewness internet NASDAQ NYSE
local deal ln_amount_filed_adj1975 share_overhang pure_primary VB uw_rank_ave
local mkt  lagmcsi lagcummktret ipo_vol
local ind  ind_ret ind_mom ind_vol ind_turn
local s1 skew1
local s2 `s1' `firm'
local s3 `s2' `deal'
local s4 `s3' `mkt'
local s5 `s4' `ind'
local s6 `s5' range_width
tempname h
open_results `h' appendix_b
forvalues c = 1/5 {
    local fe
    if `c'==4 local fe i.yr
    if `c'==5 local fe i.yr i.ff30
    quietly probit rev_up `s`c'' `fe' if sample_price==1, vce(robust)
    local r2p = e(r2_p)
    local nobs = e(N)
    quietly margins, dydx(`s`c'') post
    foreach x of local s`c' {
        local b = _b[`x']
        local se = _se[`x']
        post `h' ("TableB3") (".") (`c') ("`x'") (`b') (`se') (`b'/`se') (2*normal(-abs(`b'/`se'))) (`nobs') (`r2p')
    }
}
forvalues c = 1/6 {
    if `c'>=5 quietly reghdfe rpos `s`c'' if sample_rpos==1, absorb(yr ff30) vce(robust)
    else {
        local fe
        if `c'==4 local fe i.yr
        quietly regress rpos `s`c'' `fe' if sample_rpos==1, vce(robust)
    }
    post_model, handle(`h') table(TableB4) panel(.) column(`c') terms(`s`c'' _cons)
}
close_results `h' appendix_b

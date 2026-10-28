* Table 4 (Panel A: ln(1+adjusted primary proceeds) = t11; Panel B: completed IPO count = t12)
* and Table 5 (initial filing count = n_main). Industry-quarter OLS with HC1 standard errors.
* Columns (1)-(4): no FE; (5)-(9): FF30 and year FE absorbed by reghdfe (recursive singleton removal).
do "`c(pwd)'/_post.do"
local controls l_age l_cosk l_lnexpected l_overhang l_uwrank l_vcshare l_primaryshare l_optimism l_ipovol
local mr market_return_qminus1_candidate
local c1 skew_l1
local c2 skew_l1 l_age l_cosk
local c3 skew_l1 l_age l_cosk l_lnexpected l_overhang l_uwrank l_vcshare l_primaryshare
local c4 skew_l1 `controls' `mr'
local c5 `c4'
local c6 skew_l2 `controls' `mr'
local c7 skew_l3 `controls' `mr'
local c8 skew_l4 `controls' `mr'
local c9 skew_l1 skew_l2 skew_l3 skew_l4 `controls' `mr'
tempname h
open_results `h' panels
foreach spec in "Table4 A t4_panel t11" "Table4 B t4_panel t12" "Table5 . t5_panel n_main" {
    tokenize `spec'
    local table `1'
    local panel `2'
    local data `3'
    local y `4'
    use "$DATA/`data'.dta", clear
    forvalues c = 1/9 {
        if `c'<=4 quietly regress `y' `c`c'', vce(robust)
        else quietly reghdfe `y' `c`c'', absorb(ff30 yr) vce(robust)
        post_model, handle(`h') table(`table') panel(`panel') column(`c') terms(`c`c'' _cons)
    }
}
close_results `h' panels

* Internet Appendix Tables IA1-IA3: PPML counterparts of Table 4 A/B and Table 5
* (follows run_ppml.do of 8 October 2026: robust z, tolerance 1e-10, FE in (5)-(9)).
do "`c(pwd)'/_post.do"
local controls l_age l_cosk l_lnexpected l_overhang l_uwrank l_vcshare l_primaryshare l_optimism l_ipovol market_return_qminus1_candidate
local c1 skew_l1
local c2 `c1' l_age l_cosk
local c3 `c2' l_lnexpected l_overhang l_uwrank l_vcshare l_primaryshare
local c4 skew_l1 `controls'
local c5 `c4'
local c6 skew_l2 `controls'
local c7 skew_l3 `controls'
local c8 skew_l4 `controls'
local c9 skew_l1 skew_l2 skew_l3 skew_l4 `controls'
tempname h
open_results `h' ppml
foreach spec in "TableIA1 t4_panel proceeds" "TableIA2 t4_panel t12" "TableIA3 t5_panel n_main" {
    tokenize `spec'
    local table `1'
    local data `2'
    local y `3'
    use "$DATA/`data'.dta", clear
    forvalues c = 1/9 {
        local fe
        if `c'>=5 local fe absorb(ff30 yr)
        quietly ppmlhdfe `y' `c`c'', `fe' vce(robust) tolerance(1e-10)
        assert e(converged)==1
        post_model, handle(`h') table(`table') panel(.) column(`c') terms(`c`c'' _cons) fit(`e(r2_p)') stat(z)
    }
}
close_results `h' ppml

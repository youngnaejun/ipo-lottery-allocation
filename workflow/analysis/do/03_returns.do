* Table 3 (three-year R0, R1, R2) and Appendix Tables B1 (one-year) and B2 (five-year).
* Specifications (1)-(5) add firm, deal, market controls; (4) adds offering-year FE; (5) adds
* industry controls and FF30 FE. FE enter as explicit indicators; OLS with HC1 standard errors.
do "`c(pwd)'/_post.do"
use "$DATA/ipo_returns.dta", clear
local firm  age_ritter coskewness internet NASDAQ NYSE
local deal  lnproceeds_adj1975 price_adj_imp share_overhang pure_primary VB TT_ave
local mkt   lagmcsi lagcummktret ipo_vol
local ind   ind_ret ind_mom ind_vol ind_turn
local s1 skew1
local s2 `s1' `firm'
local s3 `s2' `deal'
local s4 `s3' `mkt'
local s5 `s4' `ind'
tempname h
open_results `h' returns
foreach pair in "Table3 R0 r0" "Table3 R1 r2_bhar_3y" "Table3 R2 r3_bhar_3y" ///
                "TableB1 R1 r2_bhar_1y" "TableB1 R2 r3_bhar_1y" "TableB2 R1 r2_bhar_5y" "TableB2 R2 r3_bhar_5y" {
    tokenize `pair'
    local table `1'
    local panel `2'
    local y `3'
    forvalues c = 1/5 {
        local fe
        if `c'==4 local fe i.ipo_year
        if `c'==5 local fe i.ipo_year i.ff30
        quietly regress `y' `s`c'' `fe', vce(robust)
        post_model, handle(`h') table(`table') panel(`panel') column(`c') terms(`s`c'' _cons)
        quietly gen byte es_`table'_`panel'_`c' = e(sample)
    }
}
close_results `h' returns
keep analysis_id es_*
export delimited using "$OUT/samples_returns.csv", replace

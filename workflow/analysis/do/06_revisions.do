* Table 6 (proceeds revision) and Table 7 (Panel A share revision, Panel B price revision).
* Follows the earlier Stata ipo_revision.do with the 15-day Market Return in (4)-(5):
* (4) offering-year FE as indicators; (5) Table 6 and 7A absorb year and FF30 FE with reghdfe,
* Table 7B uses year and FF30 indicators. HC1 standard errors throughout.
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
tempname h
open_results `h' revisions
foreach spec in "Table6 . proceeds_revision sample_proceeds" "Table7 A share_revision_raw sample_sr_full" ///
                "Table7 B rev_signed sample_price" {
    tokenize `spec'
    local table `1'
    local panel `2'
    local y `3'
    local smp `4'
    forvalues c = 1/5 {
        if `c'==5 & "`table'`panel'"!="Table7B" {
            quietly reghdfe `y' `s5' if `smp'==1, absorb(ipo_year ff30) vce(robust)
        }
        else {
            local fe
            if `c'==4 local fe i.ipo_year
            if `c'==5 local fe i.ipo_year i.ff30
            quietly regress `y' `s`c'' `fe' if `smp'==1, vce(robust)
        }
        post_model, handle(`h') table(`table') panel(`panel') column(`c') terms(`s`c'' _cons)
    }
}
close_results `h' revisions

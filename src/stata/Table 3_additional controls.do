**# TABLE 3_added: Pooled regressions of R0/R1/R2 on skewness and additional control variables
global path : environment IPO_LOTTERY_ROOT
if "$path" == "" {
    display as error "Set IPO_LOTTERY_ROOT before running this file."
    exit 198
}
global out    "$path\stata_output"

import sas using "$path\master\analysis_full2.sas7bdat", clear
save "$path\stata\analysis_full2.dta", replace

**## 1. Variable Preparation

* Price adjustment imputation
gen price_adj_imp = price_adj
gen miss_prcadj = 0
replace miss_prcadj = 1 if missing(price_adj)
replace price_adj_imp = 0 if missing(price_adj)

gen y9098 = inrange(ipo_year, 1990, 1998) // Pre-dot-com boom
gen y9900 = inrange(ipo_year, 1999, 2000) // Dot-com bubble
gen y0108 = inrange(ipo_year, 2001, 2008) // Post-bubble to pre-GFC
gen y0911 = inrange(ipo_year, 2009, 2011) // GFC recovery
gen y1219 = inrange(ipo_year, 2012, 2019) // Post-GFC expansion
gen y2024 = inrange(ipo_year, 2020, 2024) // COVID + SPAC wave

* [Dependent Variables]
label variable r0                 "R0"
label variable r2_bhar_3y         "R1"
label variable r3_bhar_3y         "R2"

* [Firm Characteristics]
label variable skew1              "Expected Skewness"
label variable age_ritter         "Age"
label variable coskewness         "Coskewness"
label variable internet           "Internet"
label variable NASDAQ             "NASDAQ"
label variable NYSE               "NYSE"

* [Deal Characteristics]
label variable lnproceeds_adj1975 "Ln(Proceeds)"
label variable price_adj_imp      	  "Price Adjustment"
label variable share_overhang     "Share Overhang"
label variable pure_primary       "Pure Primary"
label variable VB                 "Venture-Backed Deal"
label variable TT_ave             "Top-Tier Underwriter"

* [Market Characteristics]
label variable lagmcsi            "Retail Investor Optimism"
label variable lagcummktret       "Market Return"
label variable ipo_vol            "IPO Volatility"
label variable y9098 "y(1990-1998)"
label variable y9900 "y(1999-2000)"
label variable y0108 "y(2001-2008)"
label variable y0911 "y(2009-2011)"
label variable y1219 "y(2012-2019)"
label variable y2024 "y(2020-2024)"

* [Industry Characteristics]
label variable ind_ret            "Industry Return"
label variable ind_mom            "Industry Momentum"
label variable ind_vol            "Industry Volatility"
label variable ind_turn           "Industry Turnover"

local firm_vars "skew1 age_ritter coskewness internet NASDAQ NYSE"
local deal_vars "lnproceeds_adj1975 price_adj_imp share_overhang pure_primary VB TT_ave"
local mkt_vars "lagmcsi lagcummktret ipo_vol y9098 y9900 y0108 y0911 y1219 y2024"
local ind_vars "ind_ret ind_mom ind_vol ind_turn"

local spec1 "skew1"
local spec2 "`firm_vars'"
local spec3 "`firm_vars' `deal_vars'"
local spec4 "`firm_vars' `deal_vars' `mkt_vars'"
local spec5 "`firm_vars' `deal_vars' `mkt_vars' `ind_vars' i.ff30"

*-------------------------------------------------------------------
* 4. Run Regressions & Export using outreg2
*-------------------------------------------------------------------

local keepvars "`firm_vars' `deal_vars' `mkt_vars' `ind_vars'"

local firstcol = 1

foreach dep in r0 r2_bhar_3y r3_bhar_3y {

    forvalues s = 1/5 {

        quietly reg `dep' `spec`s'', robust

        * For FE models, hide year dummies and industry dummies from main table
        if inlist(`s', 5) {
            local indfe "YES"
            local kp "keep(`keepvars')"
        }
        else {
            local indfe "NO"
            local kp "keep(`spec`s'')"
        }

        * Year effects included from spec 4 onward
        if inlist(`s', 4, 5) {
            local yearfe "YES"
        }
        else {
            local yearfe "NO"
        }

        if `firstcol' == 1 {
            local rw "replace"
            local firstcol = 0
        }
        else {
            local rw "append"
        }

        outreg2 using "$out\Table3_added_PooledRegressions.rtf", `rw' ///
            ctitle(`dep', spec `s') `kp' label ///
			adjr2 tstat ///
            addtext(Year Effects, `yearfe', Industry Fixed Effects, `indfe') ///
            title("Table 3_added: Pooled Regressions of IPO Returns on Expected Skewness with Additional Controls")
    }
}

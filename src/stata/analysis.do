clear all
set more off
set matsize 800
cap log close
cap ssc install outreg2
cap ssc install estout

global path : environment IPO_LOTTERY_ROOT
if "$path" == "" {
    display as error "Set IPO_LOTTERY_ROOT before running this file."
    exit 198
}
global out    "$path\stata_output"
cap mkdir "$out"

log using "$out\Tables3_log.txt", replace text


**# 0. Import from SAS
import sas using "$path\master\analysis_full.sas7bdat", clear
save "$path\stata\analysis_full.dta", replace

*-------------------------------------------------------------------
* 1. Sample window & derived variables actually needed
*    (period dummies and FF30 dummies)
*-------------------------------------------------------------------
keep if inrange(ipo_year, 1975, 2024)

* Year period dummies (base/omitted period = 1975-1979)
gen y8089 = inrange(ipo_year, 1980, 1989)
gen y9098 = inrange(ipo_year, 1990, 1998)
gen y9900 = inrange(ipo_year, 1999, 2000)
gen y0107 = inrange(ipo_year, 2001, 2007)
gen y0811 = inrange(ipo_year, 2008, 2011)
gen y1218 = inrange(ipo_year, 2012, 2018)
gen y1924 = inrange(ipo_year, 2019, 2024)

* FF30 industry dummies ff01-ff28 (ff29 = Banking/Insurance/RE = reference)
forvalues i = 1/28 {
    local ii : display %02.0f `i'
    gen ff`ii' = (ff30 == `i')
}

label define ff30fmt ///
     1 "Food products" ///
     2 "Beer and liquor" ///
     3 "Tobacco products" ///
     4 "Recreation" ///
     5 "Printing and publishing" ///
     6 "Consumer goods" ///
     7 "Apparel" ///
     8 "Healthcare, medical equipment, pharmaceuticals" ///
     9 "Chemicals" ///
    10 "Textiles" ///
    11 "Construction and construction materials" ///
    12 "Steel works" ///
    13 "Fabricated products and machinery" ///
    14 "Electrical equipment" ///
    15 "Automobiles and trucks" ///
    16 "Aircraft, ships, and railroad equipment" ///
    17 "Precious metals, nonmetallic, and metal mining" ///
    18 "Coal" ///
    19 "Petroleum and natural gas" ///
    20 "Utilities" ///
    21 "Communication" ///
    22 "Personal and business services" ///
    23 "Business equipment" ///
    24 "Business supplies and shipping containers" ///
    25 "Transportation" ///
    26 "Wholesale" ///
    27 "Retail" ///
    28 "Restaurants, hotels, motels" ///
    29 "Banking, insurance, real estate, trading" ///
    30 "Other"
label values ff30 ff30fmt


*-------------------------------------------------------------------
* 2. Variable labels only (no renaming) -> feeds outreg2's label option
*-------------------------------------------------------------------
label variable skew1               "Expected Skewness"
label variable age_ritter          "Age"
label variable coskewness          "Coskewness"
label variable internet            "Internet"
label variable NASDAQ               "NASDAQ"
label variable NYSE                 "NYSE"
label variable lnproceeds_adj1975  "Ln(Proceeds)"
label variable share_overhang      "Share Overhang"
label variable pure_primary        "Pure Primary"
label variable VB                   "Venture-Backed Deal"
label variable TT_ave               "Top-Tier Underwriter"
label variable lagmcsi              "Retail Investor Optimism"
label variable lagcummktret        "Market Return"
label variable r0                   "R0"
label variable r2_bhar_3y          "R1"
label variable r3_bhar_3y          "R2"
label variable y8089                "1980-1989"
label variable y9098                "1990-1998"
label variable y9900                "1999-2000"
label variable y0107                "2001-2007"
label variable y0811                "2008-2011"
label variable y1218                "2012-2018"
label variable y1924                "2019-2024"

* FF30 dummy labels (reuse ff30fmt text so outreg2 label rows read industry names)
forvalues i = 1/28 {
    local ii : display %02.0f `i'
    local lab : label ff30fmt `i'
    label variable ff`ii' "`lab'"
}

save "$path\stata\analysis_full.dta", replace

**# TABLE 3: Pooled regressions of R0/R1/R2 on skewness and controls

local xset1 "skew1"
local xset2 "skew1 age_ritter coskewness internet NASDAQ NYSE"
local xset3 "skew1 age_ritter coskewness internet NASDAQ NYSE lnproceeds_adj1975 share_overhang pure_primary VB TT_ave"
local xset4 "skew1 age_ritter coskewness internet NASDAQ NYSE lnproceeds_adj1975 share_overhang pure_primary VB TT_ave lagmcsi lagcummktret y8089 y9098 y9900 y0107 y0811 y1218 y1924 ff01 ff02 ff03 ff04 ff05 ff06 ff07 ff08 ff09 ff10 ff11 ff12 ff13 ff14 ff15 ff16 ff17 ff18 ff19 ff20 ff21 ff22 ff23 ff24 ff25 ff26 ff27 ff28"

local keepvars "skew1 age_ritter coskewness internet NASDAQ NYSE lnproceeds_adj1975 share_overhang pure_primary VB TT_ave lagmcsi lagcummktret"

local firstcol = 1

foreach dep in r0 r2_bhar_3y r3_bhar_3y {
    forvalues s = 1/4 {
        quietly reg `dep' `xset`s'', robust

        if `s' == 4 {
            local yearfe "YES"
            local indfe  "YES"
            local kp     "keep(`keepvars')"
        }
        else {
            local yearfe "NO"
            local indfe  "NO"
            local kp     "keep(`xset`s'')"
        }

        if `firstcol' == 1 {
            local rw "replace"
            local firstcol = 0
        }
        else {
            local rw "append"
        }

        outreg2 using "$out\Table3_PooledRegressions.xls", `rw' ///
            ctitle(`dep', spec `s') `kp' label ///
            addtext(Year Effects, `yearfe', Industry Fixed Effects, `indfe') ///
            title("Table 3: Pooled Regressions of IPO Returns on Expected Skewness")
    }
}

log close


**# TABLE 3_added: Pooled regressions of R0/R1/R2 on skewness and additional control variables
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

**## 2. Define Variable Groups & Specifications
local firm_vars "skew1 age_ritter coskewness internet NASDAQ NYSE"
local deal_vars "lnproceeds_adj1975 price_adj_imp miss_prcadj share_overhang pure_primary VB TT_ave"
local mkt_vars_gh "lagmcsi lagcummktret ipo_vol y9098 y9900 y0108"
local mkt_vars "lagmcsi lagcummktret ipo_vol y9098 y9900 y0108 y0911 y1219 y2024"
local ind_vars "ind_ret ind_mom ind_vol ind_turn"

* Specifications
local spec1 "skew1"
local spec2 "`firm_vars'"
local spec3 "`firm_vars' `deal_vars'"
local spec4 "`firm_vars' `deal_vars' `mkt_vars_gh'"
local spec5 "`firm_vars' `deal_vars' `mkt_vars'"
local spec6 "`firm_vars' `deal_vars' `mkt_vars_gh' `ind_vars' i.ff30" 
local spec7 "`firm_vars' `deal_vars' `mkt_vars' `ind_vars' i.ff30" 

**## 3. Regression & Export using esttab
eststo clear

foreach dep in r0 r2_bhar_3y r3_bhar_3y {

    * Store models with unique names for combined table
    forvalues s = 1/7 {
        eststo `dep'_m`s': reg `dep' `spec`s'', vce(robust)
    }

    * Export individual RTF panel
    esttab ///
        `dep'_m1 `dep'_m2 `dep'_m3 `dep'_m4 `dep'_m5 `dep'_m6 `dep'_m7 ///
        using "$out\Table3_`dep'.rtf", replace ///
        b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
        keep(skew1 `firm_vars' `deal_vars' `mkt_vars' `ind_vars') ///
        order(skew1 `firm_vars' `deal_vars' `mkt_vars' `ind_vars') ///
        refcat(skew1 "Firm characteristics" ///
               lnproceeds_adj1975 "Deal characteristics" ///
               lagmcsi "Market characteristics" ///
               ind_ret "Industry characteristics", nolabel) ///
        indicate("Industry Fixed Effects = *.ff30") ///
        scalars("r2_a Adj. R-squared") sfmt(3) ///
        obslast nonotes label ///
        title("Panel for `dep': Comprehensive Streamlined Regressions")
}

* Combined Excel-readable formatted file
* Combined Excel-readable CSV file
esttab ///
    r0_m1 r0_m2 r0_m3 r0_m4 r0_m5 r0_m6 r0_m7 ///
    r2_bhar_3y_m1 r2_bhar_3y_m2 r2_bhar_3y_m3 r2_bhar_3y_m4 r2_bhar_3y_m5 r2_bhar_3y_m6 r2_bhar_3y_m7 ///
    r3_bhar_3y_m1 r3_bhar_3y_m2 r3_bhar_3y_m3 r3_bhar_3y_m4 r3_bhar_3y_m5 r3_bhar_3y_m6 r3_bhar_3y_m7 ///
    using "$out\Table3_All_21_Models.csv", replace csv ///
    b(3) t(2) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(skew1 age_ritter coskewness internet NASDAQ NYSE ///
         lnproceeds_adj1975 price_adj_imp miss_prcadj share_overhang pure_primary VB TT_ave ///
         lagmcsi lagcummktret ipo_vol y9098 y9900 y0108 y0911 y1219 y2024 ///
         ind_ret ind_mom ind_vol ind_turn) ///
    order(skew1 age_ritter coskewness internet NASDAQ NYSE ///
          lnproceeds_adj1975 price_adj_imp miss_prcadj share_overhang pure_primary VB TT_ave ///
          lagmcsi lagcummktret ipo_vol y9098 y9900 y0108 y0911 y1219 y2024 ///
          ind_ret ind_mom ind_vol ind_turn) ///
    indicate("Industry Fixed Effects = *.ff30") ///
    scalars("r2_a Adj. R-squared") sfmt(3) ///
    obslast nonotes label ///
    mtitles("R0-1" "R0-2" "R0-3" "R0-4" "R0-5" "R0-6" "R0-7" ///
            "BHAR2-1" "BHAR2-2" "BHAR2-3" "BHAR2-4" "BHAR2-5" "BHAR2-6" "BHAR2-7" ///
            "BHAR3-1" "BHAR3-2" "BHAR3-3" "BHAR3-4" "BHAR3-5" "BHAR3-6" "BHAR3-7")

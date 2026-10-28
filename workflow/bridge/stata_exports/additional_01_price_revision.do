version 19
clear all
set more off

/*==================================================================
Project: IPO Lottery Demand Replication and Extension
Program: additional_01_price_revision.do
Purpose: Estimate the price-revision additional test.

Required upstream program:
    @RUN_ROOT@\sas\05b_stage2_price_revision.sas

Primary hypothesis:
    Expected skewness positively predicts the signed offer-price
    revision and its positive part.

Important:
    rev_signed uses the ORIGINAL filing range only. It is not the
    absolute price_adj control used in Table 3.
==================================================================*/

global path "@RUN_ROOT@"
global out  "$path\stata_output\additional_tests"

capture mkdir "$out"

capture log close _all
log using "$out\PriceRevision_Analysis.log", replace text


/*------------------------------------------------------------------
1. Import the SAS analysis dataset and save a Stata working copy
------------------------------------------------------------------*/

import sas using "$path\master\price_revision_sample.sas7bdat", clear
compress
save "$path\stata\price_revision_sample.dta", replace

isid analysis_id
assert !missing(rev_signed)
assert !missing(initial_midpoint)
assert file_price_low > 0 & file_price_high > 0


/*------------------------------------------------------------------
2. Labels and deterministic sample flags
------------------------------------------------------------------*/

label variable rev_signed                 "Signed Offer-Price Revision (REVS)"
label variable rev_pos                    "Positive Offer-Price Revision (REVS_POS)"
label variable skew1                      "Expected Skewness"
label variable mkt_reg_ew                 "Registration Return (EW)"
label variable mkt_reg_ew_pos             "Positive Registration Return (EW)"
label variable mkt_reg_vw                 "Registration Return (VW)"
label variable mkt_reg_vw_pos             "Positive Registration Return (VW)"
label variable ln_amount_filed_adj1975     "Ln(Expected Proceeds)"
label variable age_ritter                  "Age"
label variable coskewness                  "Coskewness"
label variable internet                    "Internet"
label variable NASDAQ                      "NASDAQ"
label variable NYSE                        "NYSE"
label variable share_overhang              "Share Overhang"
label variable pure_primary                "Pure Primary"
label variable VB                          "Venture-Backed Deal"
label variable uw_rank_ave                 "Underwriter Rank"
label variable lagmcsi                     "Retail Investor Optimism"
label variable ipo_vol                     "IPO Volatility"
label variable ind_ret                     "Industry Return"
label variable ind_mom                     "Industry Momentum"
label variable ind_vol                     "Industry Volatility"
label variable ind_turn                    "Industry Turnover"

generate byte sample_s1 = !missing(rev_signed, skew1, ipo_year, ff30)

generate byte sample_s2 = !missing( ///
    rev_signed, skew1, mkt_reg_ew, age_ritter, coskewness, internet, ///
    NASDAQ, NYSE, ln_amount_filed_adj1975, share_overhang, ///
    pure_primary, VB, uw_rank_ave, ipo_year, ff30)

generate byte sample_s3 = sample_s2 & !missing(mkt_reg_ew_pos, lagmcsi)

generate byte sample_s4 = sample_s3 & !missing( ///
    ipo_vol, ind_ret, ind_mom, ind_vol, ind_turn)

generate byte sample_s5 = sample_s4 & !missing(rev_pos)

generate byte sample_rb365 = sample_s4 & registration_within_365 == 1
generate byte sample_rbrev = sample_s4 & revision_within_100pct == 1

label variable sample_s1 "Complete Model 1 sample"
label variable sample_s2 "Complete Model 2 sample"
label variable sample_s3 "Complete Model 3 sample"
label variable sample_s4 "Complete Model 4 sample"
label variable sample_s5 "Complete Model 5 sample"
label variable sample_rb365 "Full model; registration period <=365 days"
label variable sample_rbrev "Full model; absolute revision <=100 percent"


/*------------------------------------------------------------------
3. QA and descriptive output
------------------------------------------------------------------*/

display as text "Price-revision dataset observations: " _N
tabulate sample_s1
tabulate sample_s2
tabulate sample_s3
tabulate sample_s4
tabulate sample_s5
tabulate sample_rb365
tabulate sample_rbrev

summarize rev_signed rev_pos skew1 mkt_reg_ew mkt_reg_vw ///
    ln_amount_filed_adj1975 n_reg_trading_days, detail

pwcorr rev_signed rev_pos skew1 mkt_reg_ew mkt_reg_vw ///
    ln_amount_filed_adj1975, sig obs


/*------------------------------------------------------------------
4. Primary models

All specifications include IPO-year and FF30 fixed effects. White/HC
robust standard errors match the price-update literature's baseline.
------------------------------------------------------------------*/

local firm_controls ///
    "age_ritter coskewness internet NASDAQ NYSE"

local deal_controls ///
    "ln_amount_filed_adj1975 share_overhang pure_primary VB uw_rank_ave"

local market_controls ///
    "lagmcsi ipo_vol"

local industry_controls ///
    "ind_ret ind_mom ind_vol ind_turn"

local fixed_effects "i.ipo_year i.ff30"

quietly regress rev_signed ///
    skew1 `fixed_effects' ///
    if sample_s1, vce(robust)
estimates store PR1

quietly regress rev_signed ///
    skew1 mkt_reg_ew ///
    `firm_controls' `deal_controls' ///
    `fixed_effects' ///
    if sample_s2, vce(robust)
estimates store PR2

quietly regress rev_signed ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' lagmcsi ///
    `fixed_effects' ///
    if sample_s3, vce(robust)
estimates store PR3

quietly regress rev_signed ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_s4, vce(robust)
estimates store PR4

quietly regress rev_pos ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_s5, vce(robust)
estimates store PR5

estimates table PR1 PR2 PR3 PR4 PR5, ///
    b(%9.4f) se(%9.4f) stats(N r2_a)


/*------------------------------------------------------------------
5. Publication-oriented RTF export
------------------------------------------------------------------*/

capture which outreg2
local has_outreg2 = (_rc == 0)
if !`has_outreg2' {
    display as error "outreg2 is required for the RTF export."
    display as error "Primary estimates remain available in the log."
}
else {
    local shown ///
        "skew1 mkt_reg_ew mkt_reg_ew_pos age_ritter coskewness " ///
        "internet NASDAQ NYSE ln_amount_filed_adj1975 " ///
        "share_overhang pure_primary VB uw_rank_ave lagmcsi ipo_vol " ///
        "ind_ret ind_mom ind_vol ind_turn"

    estimates restore PR1
    outreg2 using "$out\PriceRevision_Primary.rtf", replace ///
        ctitle("REVS", "(1)") keep(`shown') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes) ///
        title("Expected Skewness and IPO Offer-Price Revision")

    estimates restore PR2
    outreg2 using "$out\PriceRevision_Primary.rtf", append ///
        ctitle("REVS", "(2)") keep(`shown') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore PR3
    outreg2 using "$out\PriceRevision_Primary.rtf", append ///
        ctitle("REVS", "(3)") keep(`shown') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore PR4
    outreg2 using "$out\PriceRevision_Primary.rtf", append ///
        ctitle("REVS", "(4)") keep(`shown') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore PR5
    outreg2 using "$out\PriceRevision_Primary.rtf", append ///
        ctitle("REVS_POS", "(5)") keep(`shown') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)
}


/*------------------------------------------------------------------
6. Prespecified robustness: VW market return and year clustering
------------------------------------------------------------------*/

quietly regress rev_signed ///
    skew1 mkt_reg_vw mkt_reg_vw_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_s4, vce(robust)
estimates store RB_VW

quietly regress rev_signed ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_s4, vce(cluster ipo_year)
estimates store RB_YEARCL

quietly regress rev_signed ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_rb365, vce(robust)
estimates store RB_REG365

quietly regress rev_signed ///
    skew1 mkt_reg_ew mkt_reg_ew_pos ///
    `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls' ///
    `fixed_effects' ///
    if sample_rbrev, vce(robust)
estimates store RB_REV100

estimates table PR4 RB_VW RB_YEARCL RB_REG365 RB_REV100, ///
    b(%9.4f) se(%9.4f) stats(N r2_a)

if `has_outreg2' {
    local shown_rb ///
        "skew1 mkt_reg_ew mkt_reg_ew_pos mkt_reg_vw mkt_reg_vw_pos " ///
        "age_ritter coskewness internet NASDAQ NYSE " ///
        "ln_amount_filed_adj1975 share_overhang pure_primary VB " ///
        "uw_rank_ave lagmcsi ipo_vol ind_ret ind_mom ind_vol ind_turn"

    estimates restore PR4
    outreg2 using "$out\PriceRevision_Robustness.rtf", replace ///
        ctitle("EW / Robust", "(1)") keep(`shown_rb') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore RB_VW
    outreg2 using "$out\PriceRevision_Robustness.rtf", append ///
        ctitle("VW / Robust", "(2)") keep(`shown_rb') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore RB_YEARCL
    outreg2 using "$out\PriceRevision_Robustness.rtf", append ///
        ctitle("EW / Cluster Year", "(3)") keep(`shown_rb') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore RB_REG365
    outreg2 using "$out\PriceRevision_Robustness.rtf", append ///
        ctitle("EW / Reg. <=365 days", "(4)") keep(`shown_rb') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)

    estimates restore RB_REV100
    outreg2 using "$out\PriceRevision_Robustness.rtf", append ///
        ctitle("EW / Abs. REVS <=1", "(5)") keep(`shown_rb') label tstat adjr2 ///
        addtext(Year FE, Yes, Industry FE, Yes)
}


/*------------------------------------------------------------------
7. Save estimates and close the reproducible log
------------------------------------------------------------------*/

estimates save "$out\PriceRevision_Estimates.ster", replace
log close

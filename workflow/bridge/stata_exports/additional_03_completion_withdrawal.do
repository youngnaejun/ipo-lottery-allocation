version 19
clear all
set more off

/*==================================================================
Project: IPO Lottery Demand Replication and Extension
Program: additional_03_completion_withdrawal.do
Purpose: Workstream 2B completion/withdrawal tests.

Primary outcome:
  completed = 1 for current Live status and 0 for Cancelled/Postponed.

Robustness outcomes/samples:
  completed_by_18m; issuer-first filing only.

Timing:
  All explanatory variables were measured at filing or in the prior
  calendar quarter by 07c_stage2_completion_withdrawal.sas.
==================================================================*/

global path "@RUN_ROOT@"
global out  "$path\stata_output\additional_tests\completion_withdrawal"

capture mkdir "$path\stata_output\additional_tests\completion_withdrawal"
capture log close _all
log using "$out\CompletionWithdrawal_Analysis.log", replace text


/*------------------------------------------------------------------
1. Load, freeze, and verify the SAS analysis master
------------------------------------------------------------------*/

import sas using "$path\master\filing_completion_analysis.sas7bdat", clear

isid deal_key
if @PAPER_CHECKS@ assert _N == 17767
assert inlist(completed,0,1) if !missing(completed)
assert inlist(completed_by_18m,0,1) if !missing(completed_by_18m)
assert skew_timing_valid == 1 if has_l1_skew == 1
assert aggregate_timing_valid == 1 if has_l1_aggregate_filings == 1

generate fq = qofd(fdate)
format fq %tq
generate filing_year_stata = year(fdate)
generate filing_qtr_stata = quarter(fdate)
assert fq == qofd(fdate) if !missing(fdate)

generate ln_l1_listed_firms = ln(l1_listed_firms) if l1_listed_firms > 0

local market_controls "l1_industry_return_refresh l1_industry_momentum_refresh l1_industry_ivol l1_bw_sentiment l1_ln_total_filings"
local deal_controls "ln_initial_amount"

egen nmiss_market = rowmiss(`market_controls')
generate byte s_current_skew = !missing(completed, l1_industry_skew, ff30, fq)
generate byte s_current_market = s_current_skew & nmiss_market == 0
generate byte s_current_deal = s_current_market & !missing(`deal_controls')

generate byte s_18m_skew = !missing(completed_by_18m, l1_industry_skew, ff30, fq)
generate byte s_18m_market = s_18m_skew & nmiss_market == 0
generate byte s_18m_deal = s_18m_market & !missing(`deal_controls')

label variable completed "Current completion status"
label variable completed_by_18m "Completed within 18 months"
label variable l1_industry_skew "L1 Industry Expected Skewness"
label variable ln_initial_amount "Log Original Amount Filed"

save "$path\stata\filing_completion_analysis.dta", replace

display as text "WORKSTREAM 2B SAMPLE QA"
count
count if !missing(completed)
count if s_current_skew
count if s_current_market
count if s_current_deal
count if s_current_deal & issuer_first_filing == 1
count if s_18m_skew
count if s_18m_market
count if s_18m_deal

tabulate completed if s_current_skew
tabulate completed if s_current_market
tabulate completed if s_current_deal
tabulate completed_by_18m if s_18m_skew
tabulate status_harmonised if s_current_skew, missing

display as text "STATUS-SPECIFIC INDUSTRY-LINK SELECTION"
tabulate status_harmonised has_l1_skew, row missing


/*------------------------------------------------------------------
2. Primary nested LPM: FF30 and filing-quarter fixed effects
------------------------------------------------------------------*/

quietly reghdfe completed l1_industry_skew if s_current_skew, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_LPM1

quietly reghdfe completed l1_industry_skew `market_controls' ///
    if s_current_market, absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_LPM2

quietly reghdfe completed l1_industry_skew `market_controls' ///
    `deal_controls' if s_current_deal, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_LPM3

quietly reghdfe completed l1_industry_skew `market_controls' ///
    `deal_controls' if s_current_deal & issuer_first_filing == 1, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_LPM_FIRST

display as text "PRIMARY NESTED LPM RESULTS"
estimates table CW_LPM1 CW_LPM2 CW_LPM3 CW_LPM_FIRST, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N r2_a)


/*------------------------------------------------------------------
3. Logit and probit AMEs

Use FF30, filing-year, and calendar-quarter-of-year effects. Full
filing-quarter dummies create extensive perfect prediction because
withdrawals are sparse after the industry-link selection documented
above; LPM retains the full filing-quarter FE specification.
------------------------------------------------------------------*/

quietly logit completed l1_industry_skew `market_controls' ///
    i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_market, vce(cluster ff30)
estimates store CW_LOGIT2_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_LOGIT2_AME

quietly logit completed l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_deal, vce(cluster ff30)
estimates store CW_LOGIT3_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_LOGIT3_AME

quietly logit completed l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_deal & issuer_first_filing == 1, vce(cluster ff30)
estimates store CW_LOGIT_FIRST_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_LOGIT_FIRST_AME

quietly probit completed l1_industry_skew `market_controls' ///
    i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_market, vce(cluster ff30)
estimates store CW_PROBIT2_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_PROBIT2_AME

quietly probit completed l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_deal, vce(cluster ff30)
estimates store CW_PROBIT3_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_PROBIT3_AME

quietly probit completed l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_current_deal & issuer_first_filing == 1, vce(cluster ff30)
estimates store CW_PROBIT_FIRST_RAW
quietly margins, dydx(l1_industry_skew) post
estimates store CW_PROBIT_FIRST_AME

display as text "CURRENT-STATUS NONLINEAR AME RESULTS"
estimates table CW_LOGIT2_AME CW_LOGIT3_AME CW_LOGIT_FIRST_AME ///
    CW_PROBIT2_AME CW_PROBIT3_AME CW_PROBIT_FIRST_AME, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
4. Eighteen-month outcome robustness
------------------------------------------------------------------*/

quietly reghdfe completed_by_18m l1_industry_skew `market_controls' ///
    `deal_controls' if s_18m_deal, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_18M_LPM

quietly reghdfe completed_by_18m l1_industry_skew `market_controls' ///
    `deal_controls' if s_18m_deal & issuer_first_filing == 1, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store CW_18M_LPM_FIRST

quietly logit completed_by_18m l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_18m_deal, vce(cluster ff30)
quietly margins, dydx(l1_industry_skew) post
estimates store CW_18M_LOGIT_AME

quietly probit completed_by_18m l1_industry_skew `market_controls' ///
    `deal_controls' i.ff30 i.filing_year_stata i.filing_qtr_stata ///
    if s_18m_deal, vce(cluster ff30)
quietly margins, dydx(l1_industry_skew) post
estimates store CW_18M_PROBIT_AME

display as text "EIGHTEEN-MONTH OUTCOME ROBUSTNESS"
estimates table CW_18M_LPM CW_18M_LPM_FIRST CW_18M_LOGIT_AME ///
    CW_18M_PROBIT_AME, b(%10.6f) se(%10.6f) p(%8.5f) stats(N r2_a)


/*------------------------------------------------------------------
5. Focused output tables
------------------------------------------------------------------*/

estimates restore CW_LPM1
outreg2 using "$out\CompletionWithdrawal_Primary.rtf", replace ///
    ctitle("LPM", "Skew only") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, No, Deal controls, No, Inference, Two-way clustered: FF30 and filing quarter) ///
    title("Workstream 2B: Completion and Withdrawal")

estimates restore CW_LPM2
outreg2 using "$out\CompletionWithdrawal_Primary.rtf", append ///
    ctitle("LPM", "Market controls") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, Yes, Deal controls, No, Inference, Two-way clustered: FF30 and filing quarter)

estimates restore CW_LPM3
outreg2 using "$out\CompletionWithdrawal_Primary.rtf", append ///
    ctitle("LPM", "Deal controls") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, Yes, Deal controls, Yes, Inference, Two-way clustered: FF30 and filing quarter)

estimates restore CW_LPM_FIRST
outreg2 using "$out\CompletionWithdrawal_Primary.rtf", append ///
    ctitle("LPM", "Issuer first") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, Yes, Deal controls, Yes, Inference, Two-way clustered: FF30 and filing quarter)

estimates restore CW_LOGIT2_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", replace ///
    ctitle("Logit AME", "Market controls") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30) ///
    title("Workstream 2B: Nonlinear Average Marginal Effects")

estimates restore CW_LOGIT3_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", append ///
    ctitle("Logit AME", "Deal controls") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_LOGIT_FIRST_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", append ///
    ctitle("Logit AME", "Issuer first") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_PROBIT2_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", append ///
    ctitle("Probit AME", "Market controls") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_PROBIT3_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", append ///
    ctitle("Probit AME", "Deal controls") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_PROBIT_FIRST_AME
outreg2 using "$out\CompletionWithdrawal_NonlinearAME.rtf", append ///
    ctitle("Probit AME", "Issuer first") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_18M_LPM
outreg2 using "$out\CompletionWithdrawal_Robustness.rtf", replace ///
    ctitle("18m LPM", "All deals") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, Yes, Deal controls, Yes, Inference, Two-way clustered: FF30 and filing quarter) ///
    title("Workstream 2B: Outcome and Refiling Robustness")

estimates restore CW_18M_LPM_FIRST
outreg2 using "$out\CompletionWithdrawal_Robustness.rtf", append ///
    ctitle("18m LPM", "Issuer first") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Filing-quarter FE, Yes, Market controls, Yes, Deal controls, Yes, Inference, Two-way clustered: FF30 and filing quarter)

estimates restore CW_18M_LOGIT_AME
outreg2 using "$out\CompletionWithdrawal_Robustness.rtf", append ///
    ctitle("18m Logit", "AME") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates restore CW_18M_PROBIT_AME
outreg2 using "$out\CompletionWithdrawal_Robustness.rtf", append ///
    ctitle("18m Probit", "AME") keep(l1_industry_skew) label tstat ///
    addtext(Inference, Clustered by FF30)

estimates save "$out\CompletionWithdrawal_Estimates.ster", replace

display as text "WORKSTREAM 2B ANALYSIS COMPLETE"
log close

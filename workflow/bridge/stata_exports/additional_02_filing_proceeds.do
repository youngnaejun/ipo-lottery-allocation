version 19
clear all
set more off

/*==================================================================
Project: IPO Lottery Demand Replication and Extension
Program: additional_02_filing_proceeds.do
Purpose: Preliminary Workstream 2A filing/proceeds tests.

Outcomes:
  1. Completed-IPO filing count assigned by filing quarter (PPML).
  2. Log(1 + real aggregate proceeds) (OLS).
  3. Industry share of quarterly real proceeds (fractional logit and
     OLS robustness).

The panel is complete over FF30 industries 1-29 and calendar quarters.
The estimation window begins in 1983Q1, when SDC filing-date coverage
starts.  Industry and calendar-quarter fixed effects are included.
==================================================================*/

global path "@RUN_ROOT@"
global out  "$path\stata_output\additional_tests\filing_proceeds"

capture mkdir "$out"
capture log close _all
log using "$out\FilingProceeds_Analysis.log", replace text


/*------------------------------------------------------------------
1. Load and freeze the SAS panel
------------------------------------------------------------------*/

import sas using "$path\master\filing_quarter_panel.sas7bdat", clear

generate qdate = qofd(quarter)
format qdate %tq

isid ff30 qdate
assert _N == 29*(yq(@SAMPLE_END_YEAR@,4)-yq(@SAMPLE_START_YEAR@,1)+1)
assert inrange(ff30,1,29)
assert filings >= 0 if filing_coverage == 1
assert inrange(proceeds_share,0,1) if filing_coverage == 1

save "$path\stata\filing_quarter_panel.dta", replace

xtset ff30 qdate

generate ln_l1_listed_firms = ln(l1_listed_firms) if l1_listed_firms > 0
local industry_controls "l1_industry_return l1_industry_momentum l1_industry_ivol l1_industry_turnover ln_l1_listed_firms"
local industry_controls_clean "l1_industry_return_clean l1_industry_momentum_clean l1_industry_ivol l1_industry_turnover ln_l1_listed_firms"
local industry_controls_refresh "l1_industry_return_refresh l1_industry_momentum_refresh l1_industry_ivol l1_industry_turnover ln_l1_listed_firms"

/* Control-variable tail sensitivity.  The source monthly panels contain
   several extreme return/momentum observations, so preserve the raw-control
   models as primary and pre-report a 1st/99th percentile sensitivity set. */
local industry_controls_w ""
foreach v in l1_industry_return l1_industry_momentum l1_industry_ivol ///
             l1_industry_turnover ln_l1_listed_firms {
    quietly summarize `v' if filing_coverage == 1, detail
    generate w_`v' = min(max(`v',r(p1)),r(p99)) if !missing(`v')
    local industry_controls_w "`industry_controls_w' w_`v'"
}

generate byte sample_base = filing_coverage == 1 & ///
    !missing(filings, ln_proceeds, proceeds_share, l1_industry_skew)

egen nmiss_controls = rowmiss(`industry_controls')
generate byte sample_controls = sample_base & nmiss_controls == 0
egen nmiss_controls_clean = rowmiss(`industry_controls_clean')
generate byte sample_controls_clean = sample_base & nmiss_controls_clean == 0
egen nmiss_controls_refresh = rowmiss(`industry_controls_refresh')
generate byte sample_controls_refresh = sample_base & nmiss_controls_refresh == 0

label variable l1_industry_skew "L1 Industry Expected Skewness"
label variable filings "Completed IPOs Assigned to Initial Filing Quarter"
label variable ln_proceeds "Log(1 + Real Aggregate Proceeds)"
label variable proceeds_share "Quarterly Real Proceeds Share"

display as text "WORKSTREAM 2A PANEL QA"
count
count if filing_coverage == 1
count if filing_coverage == 1 & filings == 0
count if sample_base
count if sample_controls
count if sample_controls_refresh
summarize filings real_proceeds ln_proceeds proceeds_share ///
    l1_industry_skew `industry_controls' if sample_base, detail

bysort qdate: egen check_filings = total(filings) if filing_coverage == 1
bysort qdate: egen check_proceeds = total(real_proceeds) if filing_coverage == 1
bysort qdate: egen check_share = total(proceeds_share) if filing_coverage == 1
assert abs(check_filings-total_filings) < 1e-8 if filing_coverage == 1
assert abs(check_proceeds-total_real_proceeds) < ///
    1e-6*max(1,abs(total_real_proceeds)) if filing_coverage == 1
assert abs(check_share-1) < 1e-8 if filing_coverage == 1 & total_real_proceeds > 0
assert check_share == 0 if filing_coverage == 1 & total_real_proceeds == 0
drop check_filings check_proceeds check_share


/*------------------------------------------------------------------
2. Filing counts: PPML with FF30 and calendar-quarter fixed effects
------------------------------------------------------------------*/

quietly ppmlhdfe filings l1_industry_skew if sample_base, ///
    absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_PPML1

quietly ppmlhdfe filings l1_industry_skew `industry_controls' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_PPML2

display as text "PPML FILING-COUNT RESULTS"
estimates table FP_PPML1 FP_PPML2, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
3. Real aggregate proceeds: OLS with the same fixed effects
------------------------------------------------------------------*/

quietly reghdfe ln_proceeds l1_industry_skew if sample_base, ///
    absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_OLS1

quietly reghdfe ln_proceeds l1_industry_skew `industry_controls' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_OLS2

display as text "OLS REAL-PROCEEDS RESULTS"
estimates table FP_OLS1 FP_OLS2, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N r2_a)


/*------------------------------------------------------------------
4. Proceeds share: fractional logit; OLS is the FE robustness model

fracreg accepts the boundary observations (0 and 1).  Because it does
not support multi-way clustering, the fractional model clusters by
FF30; the OLS robustness uses two-way FF30 x quarter clustering.
------------------------------------------------------------------*/

quietly fracreg logit proceeds_share l1_industry_skew ///
    `industry_controls' i.ff30 i.qdate if sample_controls, ///
    vce(cluster ff30)
estimates store FP_FRAC

quietly margins, dydx(l1_industry_skew) post
estimates store FP_FRAC_AME

quietly reghdfe proceeds_share l1_industry_skew `industry_controls' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_SHARE_OLS

display as text "PROCEEDS-SHARE RESULTS"
estimates table FP_FRAC_AME FP_SHARE_OLS, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
5. Locally repaired return/momentum controls
------------------------------------------------------------------*/

quietly ppmlhdfe filings l1_industry_skew `industry_controls_clean' ///
    if sample_controls_clean, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_PPML_CLEAN

quietly reghdfe ln_proceeds l1_industry_skew `industry_controls_clean' ///
    if sample_controls_clean, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_OLS_CLEAN

quietly fracreg logit proceeds_share l1_industry_skew ///
    `industry_controls_clean' i.ff30 i.qdate if sample_controls_clean, ///
    vce(cluster ff30)
quietly margins, dydx(l1_industry_skew) post
estimates store FP_FRAC_AME_CLEAN

quietly reghdfe proceeds_share l1_industry_skew `industry_controls_clean' ///
    if sample_controls_clean, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_SHARE_OLS_CLEAN

display as text "LOCALLY REPAIRED RETURN/MOMENTUM RESULTS"
estimates table FP_PPML_CLEAN FP_OLS_CLEAN FP_FRAC_AME_CLEAN ///
    FP_SHARE_OLS_CLEAN, b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
6. Refreshed raw CRSP RET controls (missing RET preserved)
------------------------------------------------------------------*/

quietly ppmlhdfe filings l1_industry_skew `industry_controls_refresh' ///
    if sample_controls_refresh, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_PPML_REFRESH

quietly reghdfe ln_proceeds l1_industry_skew `industry_controls_refresh' ///
    if sample_controls_refresh, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_OLS_REFRESH

quietly fracreg logit proceeds_share l1_industry_skew ///
    `industry_controls_refresh' i.ff30 i.qdate if sample_controls_refresh, ///
    vce(cluster ff30)
quietly margins, dydx(l1_industry_skew) post
estimates store FP_FRAC_AME_REFRESH

quietly reghdfe proceeds_share l1_industry_skew `industry_controls_refresh' ///
    if sample_controls_refresh, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_SHARE_OLS_REFRESH

display as text "RAW CRSP RET REFRESH RESULTS"
estimates table FP_PPML_REFRESH FP_OLS_REFRESH FP_FRAC_AME_REFRESH ///
    FP_SHARE_OLS_REFRESH, b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
7. Tail sensitivity: industry controls winsorized at 1%/99%
------------------------------------------------------------------*/

quietly ppmlhdfe filings l1_industry_skew `industry_controls_w' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_PPML_W

quietly reghdfe ln_proceeds l1_industry_skew `industry_controls_w' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_OLS_W

quietly fracreg logit proceeds_share l1_industry_skew ///
    `industry_controls_w' i.ff30 i.qdate if sample_controls, ///
    vce(cluster ff30)
quietly margins, dydx(l1_industry_skew) post
estimates store FP_FRAC_AME_W

quietly reghdfe proceeds_share l1_industry_skew `industry_controls_w' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_SHARE_OLS_W

display as text "WINSORIZED-CONTROL SENSITIVITY RESULTS"
estimates table FP_PPML_W FP_OLS_W FP_FRAC_AME_W FP_SHARE_OLS_W, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N)

/* Diagnose which winsorized control block changes the filing estimate. */
quietly ppmlhdfe filings l1_industry_skew w_l1_industry_return ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_STEP_RET

quietly ppmlhdfe filings l1_industry_skew w_l1_industry_return ///
    w_l1_industry_momentum if sample_controls, ///
    absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_STEP_MOM

quietly ppmlhdfe filings l1_industry_skew w_l1_industry_return ///
    w_l1_industry_momentum w_l1_industry_ivol if sample_controls, ///
    absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_STEP_IVOL

quietly ppmlhdfe filings l1_industry_skew w_l1_industry_return ///
    w_l1_industry_momentum w_l1_industry_ivol ///
    w_l1_industry_turnover if sample_controls, ///
    absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_STEP_TURN

quietly ppmlhdfe filings l1_industry_skew `industry_controls_w' ///
    if sample_controls, absorb(ff30 qdate) vce(cluster ff30 qdate)
estimates store FP_STEP_SIZE

display as text "STEPWISE WINSORIZED-CONTROL DIAGNOSTIC"
estimates table FP_STEP_RET FP_STEP_MOM FP_STEP_IVOL FP_STEP_TURN ///
    FP_STEP_SIZE, b(%10.6f) se(%10.6f) p(%8.5f) stats(N)


/*------------------------------------------------------------------
8. Focused output tables
------------------------------------------------------------------*/

estimates restore FP_PPML1
outreg2 using "$out\FilingProceeds_Primary.rtf", replace ///
    ctitle("Completed IPO activity", "PPML FE") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, No) ///
    title("Workstream 2A: Completed-IPO Filing Activity and Proceeds")

estimates restore FP_PPML2
outreg2 using "$out\FilingProceeds_Primary.rtf", append ///
    ctitle("Completed IPO activity", "PPML FE + controls") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, Yes)

estimates restore FP_OLS1
outreg2 using "$out\FilingProceeds_Primary.rtf", append ///
    ctitle("Ln proceeds", "OLS FE") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, No)

estimates restore FP_OLS2
outreg2 using "$out\FilingProceeds_Primary.rtf", append ///
    ctitle("Ln proceeds", "OLS FE + controls") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, Yes)

estimates restore FP_FRAC_AME
outreg2 using "$out\FilingProceeds_Primary.rtf", append ///
    ctitle("Proceeds share", "Fractional AME") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, Yes)

estimates restore FP_SHARE_OLS
outreg2 using "$out\FilingProceeds_Primary.rtf", append ///
    ctitle("Proceeds share", "OLS FE") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Industry controls, Yes)

estimates restore FP_PPML_CLEAN
outreg2 using "$out\FilingProceeds_CleanControls.rtf", replace ///
    ctitle("Filings", "PPML") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return/momentum repair, Local 1/99) ///
    title("Workstream 2A: Locally Repaired Return/Momentum Controls")

estimates restore FP_OLS_CLEAN
outreg2 using "$out\FilingProceeds_CleanControls.rtf", append ///
    ctitle("Ln proceeds", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return/momentum repair, Local 1/99)

estimates restore FP_FRAC_AME_CLEAN
outreg2 using "$out\FilingProceeds_CleanControls.rtf", append ///
    ctitle("Proceeds share", "Fractional AME") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return/momentum repair, Local 1/99)

estimates restore FP_SHARE_OLS_CLEAN
outreg2 using "$out\FilingProceeds_CleanControls.rtf", append ///
    ctitle("Proceeds share", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return/momentum repair, Local 1/99)

estimates restore FP_PPML_REFRESH
outreg2 using "$out\FilingProceeds_RawCRSPControls.rtf", replace ///
    ctitle("Filings", "PPML") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return source, Raw CRSP RET) ///
    title("Workstream 2A: Raw CRSP RET Controls")

estimates restore FP_OLS_REFRESH
outreg2 using "$out\FilingProceeds_RawCRSPControls.rtf", append ///
    ctitle("Ln proceeds", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return source, Raw CRSP RET)

estimates restore FP_FRAC_AME_REFRESH
outreg2 using "$out\FilingProceeds_RawCRSPControls.rtf", append ///
    ctitle("Proceeds share", "Fractional AME") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return source, Raw CRSP RET)

estimates restore FP_SHARE_OLS_REFRESH
outreg2 using "$out\FilingProceeds_RawCRSPControls.rtf", append ///
    ctitle("Proceeds share", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Return source, Raw CRSP RET)

estimates restore FP_PPML_W
outreg2 using "$out\FilingProceeds_Robustness.rtf", replace ///
    ctitle("Filings", "PPML") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Controls winsorized, 1/99) ///
    title("Workstream 2A: Winsorized-Control Sensitivity")

estimates restore FP_OLS_W
outreg2 using "$out\FilingProceeds_Robustness.rtf", append ///
    ctitle("Ln proceeds", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Controls winsorized, 1/99)

estimates restore FP_FRAC_AME_W
outreg2 using "$out\FilingProceeds_Robustness.rtf", append ///
    ctitle("Proceeds share", "Fractional AME") ///
    keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Controls winsorized, 1/99)

estimates restore FP_SHARE_OLS_W
outreg2 using "$out\FilingProceeds_Robustness.rtf", append ///
    ctitle("Proceeds share", "OLS") keep(l1_industry_skew) label tstat ///
    addtext(Industry FE, Yes, Quarter FE, Yes, Controls winsorized, 1/99)

estimates restore FP_STEP_RET
outreg2 using "$out\FilingProceeds_ControlDiagnostic.rtf", replace ///
    ctitle("+ Return") keep(l1_industry_skew) label tstat ///
    title("Workstream 2A: Stepwise Winsorized-Control Diagnostic")

estimates restore FP_STEP_MOM
outreg2 using "$out\FilingProceeds_ControlDiagnostic.rtf", append ///
    ctitle("+ Momentum") keep(l1_industry_skew) label tstat

estimates restore FP_STEP_IVOL
outreg2 using "$out\FilingProceeds_ControlDiagnostic.rtf", append ///
    ctitle("+ IVol") keep(l1_industry_skew) label tstat

estimates restore FP_STEP_TURN
outreg2 using "$out\FilingProceeds_ControlDiagnostic.rtf", append ///
    ctitle("+ Turnover") keep(l1_industry_skew) label tstat

estimates restore FP_STEP_SIZE
outreg2 using "$out\FilingProceeds_ControlDiagnostic.rtf", append ///
    ctitle("+ Listed firms") keep(l1_industry_skew) label tstat

estimates save "$out\FilingProceeds_Estimates.ster", replace
log close

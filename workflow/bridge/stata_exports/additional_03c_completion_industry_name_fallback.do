version 19
clear all
set more off

/*==================================================================
Project: IPO Lottery Demand Replication and Extension
Program: additional_03c_completion_industry_name_fallback.do
Purpose: Re-estimate all-filings completion models after supplementing
         CRSP/Compustat FF30 with an SDC industry-name crosswalk.

Design:
  - Original CRSP SIC / pre-filing Compustat SICH always takes priority.
  - SDC defines the first listed SIC description as the primary line of
    business; later descriptions are not used to vote on primary industry.
  - Conservative fallback uses high-confidence first-description mappings.
  - Extended fallback adds medium-confidence first-description mappings and
    is reported as robustness.
==================================================================*/

global path "@RUN_ROOT@"
global out  "$path\stata_output\additional_tests\completion_industry_crosswalk"

capture mkdir "$path\stata_output\additional_tests\completion_industry_crosswalk"
capture log close _all
log using "$out\CompletionIndustryCrosswalk_Analysis.log", replace text

use "$path\stata\filing_completion_analysis.dta", clear
isid deal_key
if @PAPER_CHECKS@ assert _N == 17767

merge 1:1 deal_key using "$out\SDC_Industry_Deal_Mapping.dta", ///
    keepusing(fallback_ff30_conservative fallback_ff30_extended ///
              ff30_conservative ff30_extended ///
              industry_source_conservative industry_source_extended ///
              match_method confidence) assert(match) nogen

capture confirm variable fq
if _rc generate fq = qofd(fdate)
format fq %tq
generate filing_year_cross = year(fdate)
generate filing_qtr_cross = quarter(fdate)

assert ff30_conservative == ff30 if inrange(ff30,1,29)
assert ff30_extended == ff30 if inrange(ff30,1,29)
assert !missing(ff30_conservative) if !missing(fallback_ff30_conservative)
assert !missing(ff30_extended) if !missing(fallback_ff30_extended)

/*------------------------------------------------------------------
1. Attach prior-quarter industry variables using each supplemented FF30
------------------------------------------------------------------*/

tempfile panel_cons panel_ext

preserve
use "$path\stata\filing_quarter_panel.dta", clear
keep ff30 qdate l1_industry_skew l1_industry_return_refresh ///
    l1_industry_momentum_refresh l1_industry_ivol ///
    l1_bw_sentiment l1_listed_firms
rename ff30 ff30_conservative
rename qdate fq
rename l1_industry_skew sk_cons
rename l1_industry_return_refresh ret_cons
rename l1_industry_momentum_refresh mom_cons
rename l1_industry_ivol ivol_cons
rename l1_bw_sentiment bw_cons
rename l1_listed_firms listed_cons
isid ff30_conservative fq
save `panel_cons'
restore

merge m:1 ff30_conservative fq using `panel_cons', nogen keep(master match)

preserve
use "$path\stata\filing_quarter_panel.dta", clear
keep ff30 qdate l1_industry_skew l1_industry_return_refresh ///
    l1_industry_momentum_refresh l1_industry_ivol ///
    l1_bw_sentiment l1_listed_firms
rename ff30 ff30_extended
rename qdate fq
rename l1_industry_skew sk_ext
rename l1_industry_return_refresh ret_ext
rename l1_industry_momentum_refresh mom_ext
rename l1_industry_ivol ivol_ext
rename l1_bw_sentiment bw_ext
rename l1_listed_firms listed_ext
isid ff30_extended fq
save `panel_ext'
restore

merge m:1 ff30_extended fq using `panel_ext', nogen keep(master match)

local controls_cons "ret_cons mom_cons ivol_cons bw_cons"
local controls_ext  "ret_ext mom_ext ivol_ext bw_ext"

egen nmiss_cons = rowmiss(`controls_cons')
egen nmiss_ext = rowmiss(`controls_ext')
generate byte s_cons_skew = !missing(completed, sk_cons, ff30_conservative, fq)
generate byte s_cons_full = s_cons_skew & nmiss_cons == 0 & !missing(ln_initial_amount)
generate byte s_ext_skew = !missing(completed, sk_ext, ff30_extended, fq)
generate byte s_ext_full = s_ext_skew & nmiss_ext == 0 & !missing(ln_initial_amount)

display as text "STATUS-SPECIFIC COVERAGE AFTER SDC NAME CROSSWALK"
tabulate status_harmonised industry_source_conservative, row missing
tabulate status_harmonised industry_source_extended, row missing
tabulate completed if s_cons_skew
tabulate completed if s_ext_skew

/*------------------------------------------------------------------
2. Original, conservative, and extended LPM comparison
------------------------------------------------------------------*/

quietly reghdfe completed l1_industry_skew if s_current_skew, ///
    absorb(ff30 fq) vce(cluster ff30 fq)
estimates store XW_ORIGINAL

quietly reghdfe completed sk_cons if s_cons_skew, ///
    absorb(ff30_conservative fq) vce(cluster ff30_conservative fq)
estimates store XW_CONS_MIN

quietly reghdfe completed sk_cons `controls_cons' ///
    ln_initial_amount if s_cons_full, ///
    absorb(ff30_conservative fq) vce(cluster ff30_conservative fq)
estimates store XW_CONS_FULL

quietly reghdfe completed sk_ext if s_ext_skew, ///
    absorb(ff30_extended fq) vce(cluster ff30_extended fq)
estimates store XW_EXT_MIN

quietly reghdfe completed sk_ext `controls_ext' ///
    ln_initial_amount if s_ext_full, ///
    absorb(ff30_extended fq) vce(cluster ff30_extended fq)
estimates store XW_EXT_FULL

display as text "COMPLETION LPM WITH INDUSTRY-NAME FALLBACK"
estimates table XW_ORIGINAL XW_CONS_MIN XW_CONS_FULL ///
    XW_EXT_MIN XW_EXT_FULL, b(%10.6f) se(%10.6f) p(%8.5f) stats(N r2_a)

/*------------------------------------------------------------------
3. Nonlinear AME and 18-month sensitivity
------------------------------------------------------------------*/

quietly logit completed sk_ext `controls_ext' ///
    ln_initial_amount i.ff30_extended i.filing_year_cross ///
    i.filing_qtr_cross if s_ext_full, vce(cluster ff30_extended)
quietly margins, dydx(sk_ext) post
estimates store XW_EXT_LOGIT_AME

quietly probit completed sk_ext `controls_ext' ///
    ln_initial_amount i.ff30_extended i.filing_year_cross ///
    i.filing_qtr_cross if s_ext_full, vce(cluster ff30_extended)
quietly margins, dydx(sk_ext) post
estimates store XW_EXT_PROBIT_AME

generate byte s_ext_18m = !missing(completed_by_18m, sk_ext, ///
    ff30_extended, fq) & nmiss_ext == 0 & !missing(ln_initial_amount)
quietly reghdfe completed_by_18m sk_ext `controls_ext' ///
    ln_initial_amount if s_ext_18m, ///
    absorb(ff30_extended fq) vce(cluster ff30_extended fq)
estimates store XW_EXT_18M

display as text "EXTENDED-MAPPING NONLINEAR AND 18-MONTH SENSITIVITY"
estimates table XW_EXT_LOGIT_AME XW_EXT_PROBIT_AME XW_EXT_18M, ///
    b(%10.6f) se(%10.6f) p(%8.5f) stats(N r2_a)

/*------------------------------------------------------------------
4. Tables and machine-readable coefficient summary
------------------------------------------------------------------*/

estimates restore XW_ORIGINAL
outreg2 using "$out\CompletionIndustryCrosswalk_LPM.rtf", replace ///
    ctitle("Original link", "Skew only") keep(l1_industry_skew) ///
    label tstat addtext(Industry FE, Yes, Filing-quarter FE, Yes, ///
    Mapping, CRSP/Compustat only, Inference, Two-way clustered) ///
    title("Completion Probability with SDC Industry-Name Fallback")

foreach model in XW_CONS_MIN XW_CONS_FULL XW_EXT_MIN XW_EXT_FULL {
    estimates restore `model'
    local var "sk_cons"
    local mapping "Conservative"
    if strpos("`model'", "EXT") {
        local var "sk_ext"
        local mapping "Extended"
    }
    outreg2 using "$out\CompletionIndustryCrosswalk_LPM.rtf", append ///
        ctitle("`model'") keep(`var') label tstat ///
        addtext(Industry FE, Yes, Filing-quarter FE, Yes, ///
        Mapping, `mapping', Inference, Two-way clustered)
}

tempname posth
postfile `posth' str32 model str32 variable double b se p N ///
    using "$out\CompletionIndustryCrosswalk_Results.dta", replace

foreach model in XW_ORIGINAL XW_CONS_MIN XW_CONS_FULL ///
                 XW_EXT_MIN XW_EXT_FULL XW_EXT_LOGIT_AME ///
                 XW_EXT_PROBIT_AME XW_EXT_18M {
    estimates restore `model'
    local var "l1_industry_skew"
    capture scalar b0 = _b[`var']
    if _rc {
        local var "sk_cons"
        capture scalar b0 = _b[`var']
    }
    if _rc {
        local var "sk_ext"
        scalar b0 = _b[`var']
    }
    scalar se0 = _se[`var']
    scalar p0 = 2*normal(-abs(b0/se0))
    if !strpos("`model'","LOGIT") & !strpos("`model'","PROBIT") {
        scalar p0 = 2*ttail(e(df_r),abs(b0/se0))
    }
    if se0 <= 1e-12 | missing(p0) {
        scalar se0 = .
        scalar p0 = .
    }
    post `posth' ("`model'") ("`var'") (b0) (se0) (p0) (e(N))
}
postclose `posth'

preserve
use "$out\CompletionIndustryCrosswalk_Results.dta", clear
export delimited using "$out\CompletionIndustryCrosswalk_Results.csv", replace
list, noobs abbreviate(28)
restore

save "$out\filing_completion_crosswalk_analysis.dta", replace
estimates save "$out\CompletionIndustryCrosswalk_Estimates.ster", replace

display as text "COMPLETION INDUSTRY CROSSWALK ANALYSIS COMPLETE"
log close

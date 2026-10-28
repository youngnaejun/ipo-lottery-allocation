version 19
clear all
set more off

/*==================================================================
Project: IPO Lottery Demand Replication and Extension
Program: additional_01n_sharerevision_actual.do
Created: 2026-09-03

Purpose
  Build and test the quantity-margin measure, defined as:

    ShareRevision = (actual final base shares - initial base shares filed)
                    / initial base shares filed.

  Initial base shares come from the first SDC Full History record.
  Actual final base shares come from the offer-level primary plus
  secondary shares fields. The last SDC Full History record is retained
  only for QA because it is not necessarily the final IPO offer.

Samples
  FULL   Widest full-controls sample in which both ShareRevision and
         REVS are observed. RPOS is not required.
  COMMON Table 4 range-data common sample, used for direct comparison
         with the established REVS/RPOS ladder.

Inference
  Robust, FF30-clustered, issue-year-clustered, and two-way
  issue-year/FF30-clustered standard errors are reported. A missing
  standard error is retained and flagged rather than silently replaced.

Inputs
  @RUN_ROOT@\stata\price_revision_sample.dta
  @RUN_ROOT@\stata\sdc_fullhistory_parsed_20260903.csv

Outputs
  @RUN_ROOT@\stata\sharerevision_actual.dta
  @RUN_ROOT@\stata_output\additional_tests\sharerevision_actual\
==================================================================*/

global path "@RUN_ROOT@"
global src  "$path\stata\sdc_fullhistory_parsed_20260903.csv"
global out  "$path\stata_output\additional_tests\sharerevision_actual"

capture mkdir "$path\stata_output\additional_tests\sharerevision_actual"
capture log close _all
log using "$out\ShareRevisionActual_Analysis.log", replace text

tempfile fh results period coverage


/*------------------------------------------------------------------
1. Import the reproducibly parsed SDC Full History fields
------------------------------------------------------------------*/

import delimited "$src", clear varnames(1) ///
    stringcols(1 2 3 4 5 6 7 8 10 11) encoding(utf8)

rename sdc_deal deal_num
replace deal_num = trim(deal_num)
isid deal_num

destring n_filings tot_first tot_last pri_first pri_last ///
    ovr_first ovr_last mid_first mid_last lo_first lo_last ///
    hi_first hi_last, replace force

generate double fh_first_date_n = daily(fh_first_date, "YMD")
generate double fh_last_date_n  = daily(fh_last_date, "YMD")
format fh_first_date_n fh_last_date_n %td

keep deal_num n_filings fh_first_date_n fh_last_date_n ///
    tot_first tot_last pri_first pri_last ovr_first ovr_last ///
    mid_first mid_last lo_first lo_last hi_first hi_last
save `fh', replace


/*------------------------------------------------------------------
2. Merge offer-level final terms and define analysis samples
------------------------------------------------------------------*/

use "$path\stata\price_revision_sample.dta", clear
isid analysis_id
replace deal_num = trim(deal_num)

merge 1:1 deal_num using `fh', keep(master match) generate(_mfh)
assert _mfh == 3

generate double range_spread = file_price_high - file_price_low
generate double rpos = (oprc - file_price_low) / range_spread ///
    if range_spread > 0 & !missing(oprc)
generate byte above_range = (oprc > file_price_high) ///
    if !missing(oprc, file_price_high)

generate byte sample_r0_original = ready_full_model == 1 & ///
    !missing(r0, skew1, ipo_year, ff30)
generate byte sample_bb = sample_r0_original == 1 & ///
    !missing(r0, skew1, rev_signed, rpos, above_range, ipo_year, ff30)

local firm_controls "age_ritter coskewness internet NASDAQ NYSE"
local deal_controls ///
    "ln_amount_filed_adj1975 share_overhang pure_primary VB uw_rank_ave"
local registration_controls "mkt_reg_ew mkt_reg_ew_pos"
local market_controls "lagmcsi ipo_vol"
local industry_controls "ind_ret ind_mom ind_vol ind_turn"
local controls ///
    `registration_controls' `firm_controls' `deal_controls' ///
    `market_controls' `industry_controls'


/*------------------------------------------------------------------
3. Construct actual-endpoint ShareRevision and ProceedsRevision
------------------------------------------------------------------*/

* Existing SAS convention: missing secondary shares means no secondary tranche.
generate double secondary_shares_final = ///
    cond(missing(secondary_shares), 0, secondary_shares) ///
    if !missing(primary_shares)
generate double actual_base_total = primary_shares + secondary_shares_final ///
    if !missing(primary_shares)

generate double share_ratio_actual = actual_base_total / tot_first ///
    if tot_first > 0 & !missing(actual_base_total)
generate double sharerev_actual = share_ratio_actual - 1 ///
    if !missing(share_ratio_actual)
label variable sharerev_actual ///
    "Actual total base-share revision from initial filing"

* Secondary diagnostic only: last recorded filing is not the final offer.
generate double sharerev_lastfile = (tot_last - tot_first) / tot_first ///
    if n_filings >= 2 & tot_first > 0 & !missing(tot_last)
label variable sharerev_lastfile ///
    "First-to-last SDC filing-history revision (QA only)"

* Issuer capital: actual primary proceeds versus initially planned primary proceeds.
generate double proceedsrev_actual = ///
    (oprc * primary_shares - initial_midpoint * pri_first) / ///
    (initial_midpoint * pri_first) ///
    if oprc > 0 & initial_midpoint > 0 & primary_shares >= 0 & pri_first > 0
label variable proceedsrev_actual ///
    "Actual primary-proceeds revision from initial filing"

generate byte sample_sr_full_raw = sample_r0_original == 1 & ///
    !missing(rev_signed, sharerev_actual)

* One set of 1/99 cutoffs from the widest eligible sample is used everywhere.
quietly summarize sharerev_actual if sample_sr_full_raw, detail
local sr_p1  = r(p1)
local sr_p99 = r(p99)
generate double sharerev_actual_w = sharerev_actual
replace sharerev_actual_w = `sr_p1' if sharerev_actual_w < `sr_p1' ///
    & !missing(sharerev_actual_w)
replace sharerev_actual_w = `sr_p99' if sharerev_actual_w > `sr_p99' ///
    & !missing(sharerev_actual_w)
label variable sharerev_actual_w ///
    "Actual total base-share revision, winsorised 1/99"

generate byte sample_sr_full = sample_r0_original == 1 & ///
    !missing(rev_signed, sharerev_actual_w)
generate byte sample_sr_common = sample_bb == 1 & ///
    !missing(sharerev_actual_w)
egen long year_ff30_cluster = group(ipo_year ff30)
label variable sample_sr_full "Full eligible ShareRevision/REVS sample"
label variable sample_sr_common "Table 4 common ShareRevision sample"


/*------------------------------------------------------------------
4. Definition and endpoint QA
------------------------------------------------------------------*/

generate double implied_final_total = proceeds_mil * 1000000 / oprc ///
    if proceeds_mil >= 0 & oprc > 0
generate double final_total_gap = actual_base_total - implied_final_total ///
    if !missing(actual_base_total, implied_final_total)

generate double initial_amount_gap = ///
    tot_first * initial_midpoint - amount_filed_mil * 1000000 ///
    if tot_first > 0 & initial_midpoint > 0 & amount_filed_mil >= 0

generate byte initial_date_mismatch = fh_first_date_n != fdate ///
    if !missing(fh_first_date_n, fdate)
generate byte history_after_issue = fh_last_date_n > idate ///
    if !missing(fh_last_date_n, idate)
generate byte winsor_tail = ///
    (sharerev_actual < `sr_p1' | sharerev_actual > `sr_p99') ///
    if !missing(sharerev_actual)
generate byte split_like = ///
    (share_ratio_actual <= 1/3 | share_ratio_actual >= 3) ///
    if share_ratio_actual > 0 & !missing(share_ratio_actual)
generate byte sample_sr_full_nosplit = sample_sr_full & split_like != 1
generate byte sample_sr_common_nosplit = sample_sr_common & split_like != 1
label variable sample_sr_full_nosplit "Full ShareRevision sample excluding split-like ratios"
label variable sample_sr_common_nosplit "Common ShareRevision sample excluding split-like ratios"

display as text "=== DEFINITION QA ==="
display as text "ShareRevision winsor cutoffs: " ///
    as result %9.4f `sr_p1' " and " %9.4f `sr_p99'
count if sample_r0_original
count if sample_bb
count if sample_sr_full
count if sample_sr_common
count if sample_bb & !missing(proceedsrev_actual)

display as text "Actual total shares versus proceeds/offer-price identity"
count if sample_bb & !missing(final_total_gap)
count if sample_bb & !missing(final_total_gap) & abs(final_total_gap) <= 1
count if sample_bb & !missing(final_total_gap) & abs(final_total_gap) <= 1000

display as text "Initial Full History record checks"
count if sample_bb & !missing(initial_date_mismatch)
count if sample_bb & initial_date_mismatch == 0
count if sample_bb & !missing(initial_amount_gap) & abs(initial_amount_gap) <= 10000

display as text "Why the last Full History token is not the actual offer"
count if sample_bb & history_after_issue == 1
summarize idate fh_last_date_n if sample_bb

display as text "Single-record cases resolved using actual final terms"
count if sample_bb & n_filings == 1 & sharerev_actual == 0
count if sample_bb & n_filings == 1 & sharerev_actual != 0 ///
    & !missing(sharerev_actual)

display as text "Security-type and SPAC checks"
capture noisily tabulate security_type if sample_sr_full, missing
capture noisily tabulate spac_flag if sample_sr_full, missing

display as text "Distribution and correlations"
summarize sharerev_actual sharerev_actual_w proceedsrev_actual ///
    if sample_sr_full, detail
pwcorr sharerev_actual_w sharerev_lastfile rev_signed rpos ///
    if sample_sr_common, sig obs

display as text "Potential split/outlier cases"
count if sample_sr_full & winsor_tail == 1
count if sample_sr_full & split_like == 1

preserve
keep if sample_sr_full & ///
    (winsor_tail == 1 | split_like == 1 | initial_date_mismatch == 1 | ///
     history_after_issue == 1)
keep analysis_id deal_num issuer_name ipo_year fdate idate ///
    fh_first_date_n fh_last_date_n n_filings initial_midpoint ///
    tot_first actual_base_total share_ratio_actual sharerev_actual ///
    sharerev_actual_w winsor_tail split_like initial_date_mismatch ///
    history_after_issue primary_shares secondary_shares_final ///
    proceeds_mil oprc
sort ipo_year deal_num
export delimited using "$out\ShareRevisionActual_OutlierQA.csv", replace
restore


/*------------------------------------------------------------------
5. Coverage export
------------------------------------------------------------------*/

tempname C
postfile `C' str64 metric double value using `coverage', replace

quietly count
post `C' ("price_revision_frame") (r(N))
quietly count if sample_r0_original
post `C' ("r0_full_controls_sample") (r(N))
quietly count if sample_bb
post `C' ("table4_common_sample") (r(N))
quietly count if sample_sr_full
post `C' ("sharerevision_full_eligible") (r(N))
quietly count if sample_sr_common
post `C' ("sharerevision_table4_common") (r(N))
quietly count if sample_bb & !missing(proceedsrev_actual)
post `C' ("proceedsrevision_table4_common") (r(N))
quietly count if sample_bb & n_filings == 1 & sharerev_actual == 0
post `C' ("single_record_true_zero_common") (r(N))
quietly count if sample_bb & n_filings == 1 & sharerev_actual != 0 ///
    & !missing(sharerev_actual)
post `C' ("single_record_actual_revision_common") (r(N))
quietly count if sample_sr_full & winsor_tail == 1
post `C' ("winsor_tail_full") (r(N))
quietly count if sample_sr_full & split_like == 1
post `C' ("split_like_full") (r(N))
quietly count if sample_sr_full_nosplit
post `C' ("sharerevision_full_excluding_split_like") (r(N))
quietly count if sample_sr_common_nosplit
post `C' ("sharerevision_common_excluding_split_like") (r(N))
quietly count if sample_bb & history_after_issue == 1
post `C' ("last_history_after_issue_common") (r(N))

quietly reghdfe sharerev_actual_w skew1 `controls' ///
    if sample_sr_full, absorb(ipo_year ff30) vce(robust)
post `C' ("estimation_n_full_after_absorbed_singletons") (e(N))
quietly reghdfe sharerev_actual_w skew1 `controls' ///
    if sample_sr_common, absorb(ipo_year ff30) vce(robust)
post `C' ("estimation_n_common_after_absorbed_singletons") (e(N))
postclose `C'

preserve
use `coverage', clear
format value %12.0fc
list, noobs abbreviate(64)
export delimited using "$out\ShareRevisionActual_Coverage.csv", replace
restore


/*------------------------------------------------------------------
6. Coefficient collector
------------------------------------------------------------------*/

tempname H
postfile `H' str8 panel str8 sample str8 inference str36 model ///
    str24 outcome str24 term double coef se tstat pval nobs ///
    using `results', replace
global SRA_HANDLE `H'

capture program drop sra_post
program define sra_post
    args panel sample inference model outcome term
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    local names : colnames `b'
    local k = 0
    forvalues i = 1/`=colsof(`b')' {
        local name : word `i' of `names'
        if "`name'" == "`term'" local k = `i'
    }
    if `k' == 0 {
        display as error "Term `term' not found in `model'"
        exit 111
    }
    scalar __coef = `b'[1, `k']
    scalar __se = sqrt(`V'[`k', `k'])
    scalar __t = __coef / __se
    scalar __p = .
    if !missing(__t) & e(df_r) > 0 {
        scalar __p = 2 * ttail(e(df_r), abs(__t))
    }
    post $SRA_HANDLE ("`panel'") ("`sample'") ("`inference'") ///
        ("`model'") ("`outcome'") ("`term'") ///
        (__coef) (__se) (__t) (__p) (e(N))
end


/*------------------------------------------------------------------
7. Panel A: expected skewness and the quantity/price margins
------------------------------------------------------------------*/

foreach samp in FULL COMMON FULLNS COMMNS {
    local samplevar sample_sr_full
    if "`samp'" == "COMMON" local samplevar sample_sr_common
    if "`samp'" == "FULLNS" local samplevar sample_sr_full_nosplit
    if "`samp'" == "COMMNS" local samplevar sample_sr_common_nosplit

    foreach inf in ROBUST FF30 YEAR CELL TWO {
        local vceopt "vce(robust)"
        if "`inf'" == "FF30" local vceopt "vce(cluster ff30)"
        if "`inf'" == "YEAR" local vceopt "vce(cluster ipo_year)"
        if "`inf'" == "CELL" local vceopt "vce(cluster year_ff30_cluster)"
        if "`inf'" == "TWO"  local vceopt "vce(cluster ipo_year ff30)"

        quietly reghdfe sharerev_actual_w skew1 `controls' ///
            if `samplevar', absorb(ipo_year ff30) `vceopt'
        sra_post "A" "`samp'" "`inf'" "Skew-to-ShareRevision" ///
            "ShareRevision" "skew1"

        quietly reghdfe rev_signed skew1 `controls' ///
            if `samplevar', absorb(ipo_year ff30) `vceopt'
        sra_post "A" "`samp'" "`inf'" "Skew-to-REVS-same-sample" ///
            "REVS" "skew1"
    }
}


/*------------------------------------------------------------------
8. Panel B: R0 specification ladder on identical samples
------------------------------------------------------------------*/

foreach samp in FULL COMMON FULLNS COMMNS {
    local samplevar sample_sr_full
    if "`samp'" == "COMMON" local samplevar sample_sr_common
    if "`samp'" == "FULLNS" local samplevar sample_sr_full_nosplit
    if "`samp'" == "COMMNS" local samplevar sample_sr_common_nosplit

    foreach inf in ROBUST FF30 YEAR CELL TWO {
        local vceopt "vce(robust)"
        if "`inf'" == "FF30" local vceopt "vce(cluster ff30)"
        if "`inf'" == "YEAR" local vceopt "vce(cluster ipo_year)"
        if "`inf'" == "CELL" local vceopt "vce(cluster year_ff30_cluster)"
        if "`inf'" == "TWO"  local vceopt "vce(cluster ipo_year ff30)"

        quietly reghdfe r0 skew1 `controls' if `samplevar', ///
            absorb(ipo_year ff30) `vceopt'
        sra_post "B" "`samp'" "`inf'" "R0-baseline" "R0" "skew1"

        quietly reghdfe r0 skew1 rev_signed `controls' if `samplevar', ///
            absorb(ipo_year ff30) `vceopt'
        sra_post "B" "`samp'" "`inf'" "R0-plus-REVS" "R0" "skew1"
        sra_post "B" "`samp'" "`inf'" "R0-plus-REVS" "R0" "rev_signed"

        quietly reghdfe r0 skew1 sharerev_actual_w `controls' ///
            if `samplevar', absorb(ipo_year ff30) `vceopt'
        sra_post "B" "`samp'" "`inf'" "R0-plus-ShareRevision" ///
            "R0" "skew1"
        sra_post "B" "`samp'" "`inf'" "R0-plus-ShareRevision" ///
            "R0" "sharerev_actual_w"

        quietly reghdfe r0 skew1 rev_signed sharerev_actual_w `controls' ///
            if `samplevar', absorb(ipo_year ff30) `vceopt'
        sra_post "B" "`samp'" "`inf'" "R0-plus-REVS-and-SR" "R0" "skew1"
        sra_post "B" "`samp'" "`inf'" "R0-plus-REVS-and-SR" "R0" "rev_signed"
        sra_post "B" "`samp'" "`inf'" "R0-plus-REVS-and-SR" ///
            "R0" "sharerev_actual_w"
    }
}

postclose `H'

preserve
use `results', clear
format coef se tstat %10.4f
format pval %9.4f
sort panel sample inference model term
list, noobs abbreviate(36) sepby(panel sample inference)
export delimited using "$out\ShareRevisionActual_Results.csv", replace
restore


/*------------------------------------------------------------------
9. Period diagnostic: pre-1990 versus 1990+
------------------------------------------------------------------*/

generate byte post90 = ipo_year >= 1990 if !missing(ipo_year)

tempname P
postfile `P' str8 sample str8 inference str20 outcome ///
    double b_pre se_pre t_pre p_pre b_post se_post t_post p_post ///
    p_inter nobs using `period', replace

foreach samp in FULL COMMON {
    local samplevar sample_sr_full
    if "`samp'" == "COMMON" local samplevar sample_sr_common

    foreach inf in ROBUST FF30 YEAR CELL TWO {
        local vceopt "vce(robust)"
        if "`inf'" == "FF30" local vceopt "vce(cluster ff30)"
        if "`inf'" == "YEAR" local vceopt "vce(cluster ipo_year)"
        if "`inf'" == "CELL" local vceopt "vce(cluster year_ff30_cluster)"
        if "`inf'" == "TWO"  local vceopt "vce(cluster ipo_year ff30)"

        foreach y in sharerev_actual_w rev_signed {
            quietly reghdfe `y' c.skew1##i.post90 `controls' ///
                if `samplevar', absorb(ipo_year ff30) `vceopt'

            quietly lincom _b[skew1]
            local bpre = r(estimate)
            local sepre = r(se)
            local tpre = r(estimate) / r(se)
            local ppre = r(p)

            quietly lincom _b[skew1] + _b[1.post90#c.skew1]
            local bpost = r(estimate)
            local sepost = r(se)
            local tpost = r(estimate) / r(se)
            local ppost = r(p)

            quietly test 1.post90#c.skew1
            local pint = r(p)

            post `P' ("`samp'") ("`inf'") ("`y'") ///
                (`bpre') (`sepre') (`tpre') (`ppre') ///
                (`bpost') (`sepost') (`tpost') (`ppost') ///
                (`pint') (e(N))
        }
    }
}

postclose `P'

preserve
use `period', clear
format b_* se_* t_* %10.4f
format p_* %9.4f
sort sample outcome inference
list, noobs abbreviate(24) sepby(sample outcome)
export delimited using "$out\ShareRevisionActual_PeriodDiagnostic.csv", replace
restore


/*------------------------------------------------------------------
10. Save linkable variables
------------------------------------------------------------------*/

preserve
keep analysis_id deal_num ipo_year fdate idate sample_r0_original sample_bb ///
    sample_sr_full sample_sr_common sample_sr_full_nosplit ///
    sample_sr_common_nosplit n_filings fh_first_date_n fh_last_date_n ///
    tot_first tot_last pri_first pri_last ovr_first ovr_last ///
    actual_base_total secondary_shares_final share_ratio_actual ///
    sharerev_actual sharerev_actual_w sharerev_lastfile proceedsrev_actual ///
    initial_date_mismatch history_after_issue winsor_tail split_like ///
    final_total_gap initial_amount_gap
order analysis_id deal_num ipo_year sharerev_actual sharerev_actual_w ///
    proceedsrev_actual sample_sr_full sample_sr_common
compress
save "$path\stata\sharerevision_actual.dta", replace
restore

display as text "DONE: additional_01n_sharerevision_actual"
log close _all

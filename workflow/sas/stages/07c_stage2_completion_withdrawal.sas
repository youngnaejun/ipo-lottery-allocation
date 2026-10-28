/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
07c_stage2_completion_withdrawal.sas

Stage:
Workstream 2B - completion and withdrawal

Purpose:
Merge filing-time FF30 expected skewness and predetermined controls
onto the all-filings outcome file. Preserve every Deal ID and report
status-specific availability before any regression sample is selected.

Inputs:
- master.filing_outcomes_linked
- master.filing_quarter_panel

Outputs:
- master.filing_completion_analysis
- master.completion_merge_qa
- master.completion_merge_attrition
- output\completion_merge_status_qa.csv
- output\completion_merge_attrition.csv
- output\completion_merge_ff30_missing.csv

Timing rules:
- Filing quarter, not issue quarter, determines the merge.
- Expected skewness and industry controls are prior-quarter values.
- Aggregate filing volume is taken from the prior calendar quarter.
- Actual proceeds, offer price, and other completed-deal outcomes are
  retained in the source record but are not analysis controls here.
- FF30-missing filings remain in the master and are explicitly flagged.

Created:
12 August 2026
********************************************************************/

%include "%sysget(IPO_CONFIG)";

proc printto log="&output.\07c_stage2_completion_withdrawal.log" new;
run;

/*------------------------------------------------------------------
  1. Filing-time keys and filing-available deal characteristics
------------------------------------------------------------------*/

data work.filing_base;
    set master.filing_outcomes_linked;

    filing_date_known = not missing(fdate);
    if filing_date_known then do;
        filing_quarter = intnx('qtr', fdate, 0, 'b');
        prior_filing_quarter = intnx('qtr', filing_quarter, -1, 'b');
        filing_year = year(fdate);
        filing_qtr_number = qtr(fdate);
    end;

    ff30_analysis_eligible = (1 <= ff30 <= 29);
    ff30_utility = (ff30 = 30);

    if initial_amount_mil > 0 then
        ln_initial_amount = log(initial_amount_mil);
    else ln_initial_amount = .;

    if file_price_low > 0 and file_price_high > 0 then do;
        initial_file_midpoint = (file_price_low + file_price_high) / 2;
        ln_initial_file_midpoint = log(initial_file_midpoint);
    end;
    else call missing(initial_file_midpoint, ln_initial_file_midpoint);

    if upcase(strip(venture_backed)) = 'TRUE' then vc_filing = 1;
    else if upcase(strip(venture_backed)) = 'FALSE' then vc_filing = 0;
    else vc_filing = .;

    if upcase(strip(not_underwritten)) = 'TRUE' then not_underwritten_filing = 1;
    else if upcase(strip(not_underwritten)) = 'FALSE' then not_underwritten_filing = 0;
    else not_underwritten_filing = .;

    if upcase(strip(spac_flag)) = 'TRUE' then spac_filing = 1;
    else if upcase(strip(spac_flag)) = 'FALSE' then spac_filing = 0;
    else spac_filing = .;

    length issuer_key $120;
    issuer_key = compress(upcase(strip(issuer_name)),,'kad');
    if missing(issuer_key) then issuer_key = cats('_MISSING_', deal_key);

    format filing_quarter prior_filing_quarter yyq6.;
    label
        filing_quarter = 'Calendar quarter containing SDC filing date'
        prior_filing_quarter = 'Calendar quarter immediately before filing'
        ff30_analysis_eligible = 'FF30 industry 1-29 observed'
        ln_initial_amount = 'Log original domestic amount filed'
        initial_file_midpoint = 'Original filing-range midpoint'
        vc_filing = 'Venture-backed filing indicator'
        issuer_key = 'Normalised issuer-name key for refiling checks';
run;

proc sql noprint;
    select count(*), count(distinct deal_key)
      into :input_n trimmed, :input_deals trimmed
    from work.filing_base;
quit;

/*------------------------------------------------------------------
  2. Merge current filing-quarter row, whose L1 variables are already
     computed from the immediately preceding quarter in 07b.
------------------------------------------------------------------*/

proc sql;
    create table work.filing_merged as
    select a.*,
           b.quarter as matched_panel_quarter format=yyq6.,
           b.l1_industry_skew,
           b.l1_industry_return_refresh,
           b.l1_industry_momentum_refresh,
           b.l1_industry_ivol,
           b.l1_industry_turnover,
           b.l1_listed_firms,
           b.l1_mcsi,
           b.l1_bw_sentiment,
           b.l1_bw_sentiment_orth,
           c.total_filings as l1_total_filings,
           c.ln_total_filings as l1_ln_total_filings
    from work.filing_base as a
    left join master.filing_quarter_panel as b
      on a.ff30 = b.ff30
     and a.filing_quarter = b.quarter
    left join master.filing_quarter_panel as c
      on a.ff30 = c.ff30
     and a.prior_filing_quarter = c.quarter
    order by a.deal_key;
quit;

data work.filing_merged;
    set work.filing_merged;

    panel_match = not missing(matched_panel_quarter);
    has_l1_skew = not missing(l1_industry_skew);
    has_l1_return = not missing(l1_industry_return_refresh);
    has_l1_ivol = not missing(l1_industry_ivol);
    has_l1_sentiment = not missing(l1_bw_sentiment);
    has_l1_aggregate_filings = not missing(l1_total_filings);
    has_initial_amount = not missing(ln_initial_amount);

    current_resolved_sample = not missing(completed);
    outcome_18m_sample = not missing(completed_by_18m);

    /* Nested samples are flags only; no rows are deleted. */
    sample_skew_current = current_resolved_sample and has_l1_skew;
    sample_skew_18m = outcome_18m_sample and has_l1_skew;
    sample_market_current = sample_skew_current and
                            has_l1_return and has_l1_ivol and
                            has_l1_sentiment and has_l1_aggregate_filings;
    sample_deal_current = sample_market_current and has_initial_amount;

    /* Timing invariants: these must be the quarter before filing. */
    skew_timing_valid = (has_l1_skew and
                         prior_filing_quarter =
                         intnx('qtr', filing_quarter, -1, 'b'));
    aggregate_timing_valid = (has_l1_aggregate_filings and
                              prior_filing_quarter =
                              intnx('qtr', filing_quarter, -1, 'b'));

    label
        l1_industry_skew = 'Prior-quarter FF30 expected skewness'
        l1_industry_return_refresh = 'Prior-quarter FF30 return, raw CRSP RET'
        l1_industry_momentum_refresh = 'Prior-quarter FF30 momentum, raw CRSP RET'
        l1_industry_ivol = 'Prior-quarter FF30 idiosyncratic volatility'
        l1_total_filings = 'Prior-quarter aggregate completed-IPO filing count'
        l1_bw_sentiment = 'Prior-quarter Baker-Wurgler sentiment'
        sample_skew_current = 'Resolved current-status sample with L1 skew'
        sample_market_current = 'Resolved sample with L1 skew and market controls'
        sample_deal_current = 'Resolved sample with market controls and initial amount';
run;

/*------------------------------------------------------------------
  3. Issuer-first and refiling episode variables
------------------------------------------------------------------*/

proc sort data=work.filing_merged out=work.filing_issuer_sort;
    by issuer_key fdate deal_key;
run;

data work.filing_issuer_flags;
    set work.filing_issuer_sort;
    by issuer_key fdate deal_key;
    retain issuer_filing_sequence filing_episode_id prior_issuer_fdate;

    if first.issuer_key then do;
        issuer_filing_sequence = 1;
        filing_episode_id = 1;
        prior_issuer_fdate = .;
    end;
    else do;
        issuer_filing_sequence + 1;
        if not missing(fdate) and not missing(prior_issuer_fdate) and
           fdate - prior_issuer_fdate > 730 then filing_episode_id + 1;
    end;

    issuer_first_filing = (issuer_filing_sequence = 1);
    if not missing(fdate) and not missing(prior_issuer_fdate) then
        refiling_gap_days = fdate - prior_issuer_fdate;
    else refiling_gap_days = .;

    if not missing(fdate) then prior_issuer_fdate = fdate;

    keep deal_key issuer_first_filing issuer_filing_sequence
         filing_episode_id refiling_gap_days;
run;

proc sort data=work.filing_merged;       by deal_key; run;
proc sort data=work.filing_issuer_flags; by deal_key; run;

data master.filing_completion_analysis;
    merge work.filing_merged(in=a) work.filing_issuer_flags;
    by deal_key;
    if a;
run;

/*------------------------------------------------------------------
  4. Invariants, status coverage, and nested-sample attrition
------------------------------------------------------------------*/

proc sort data=master.filing_completion_analysis
          out=work.final_deal_check nodupkey
          dupout=work.final_deal_duplicates;
    by deal_key;
run;

proc sql;
    create table master.completion_merge_qa as
    select status_harmonised,
           count(*) as n,
           sum(ff30_analysis_eligible) as ff30_1_29_n,
           sum(panel_match) as panel_match_n,
           sum(has_l1_skew) as l1_skew_n,
           sum(has_l1_return) as l1_return_n,
           sum(has_l1_ivol) as l1_ivol_n,
           sum(has_l1_sentiment) as l1_sentiment_n,
           sum(has_l1_aggregate_filings) as l1_aggregate_filings_n,
           sum(has_initial_amount) as initial_amount_n,
           sum(sample_skew_current) as sample_skew_current_n,
           sum(sample_market_current) as sample_market_current_n,
           sum(sample_deal_current) as sample_deal_current_n,
           sum(issuer_first_filing) as issuer_first_n
    from master.filing_completion_analysis
    group by status_harmonised
    order by status_harmonised;

    create table master.completion_merge_attrition as
    select 1 as step, 'All linked filings retained' as criterion length=70,
           count(*) as n from master.filing_completion_analysis
    union all
    select 2, 'Current status resolved: Live/Cancelled/Postponed',
           sum(current_resolved_sample)
           from master.filing_completion_analysis
    union all
    select 3, 'Resolved and FF30 1-29 observed',
           sum(current_resolved_sample and ff30_analysis_eligible)
           from master.filing_completion_analysis
    union all
    select 4, 'Resolved with prior-quarter expected skewness',
           sum(sample_skew_current)
           from master.filing_completion_analysis
    union all
    select 5, 'Plus prior-quarter return/ivol/sentiment/aggregate filings',
           sum(sample_market_current)
           from master.filing_completion_analysis
    union all
    select 6, 'Plus log original amount filed',
           sum(sample_deal_current)
           from master.filing_completion_analysis
    union all
    select 7, 'Step 6 restricted to issuer-first filings',
           sum(sample_deal_current and issuer_first_filing)
           from master.filing_completion_analysis;

    create table work.ff30_missing_detail as
    select deal_key, deal_num, issuer_name, status_harmonised,
           fdate, idate, cusip_new, crsp_link_route,
           sic_source, siccd, ff30, completed, completed_by_18m,
           initial_amount_mil, transaction_status
    from master.filing_completion_analysis
    where not ff30_analysis_eligible
    order by status_harmonised, fdate, deal_key;
quit;

data master.completion_merge_attrition;
    set master.completion_merge_attrition;
    previous_n = lag(n);
    if step = 1 then dropped = .;
    else dropped = previous_n - n;
    drop previous_n;
run;

proc export data=master.completion_merge_qa
    outfile="&output.\completion_merge_status_qa.csv"
    dbms=csv replace;
run;

proc export data=master.completion_merge_attrition
    outfile="&output.\completion_merge_attrition.csv"
    dbms=csv replace;
run;

proc export data=work.ff30_missing_detail
    outfile="&output.\completion_merge_ff30_missing.csv"
    dbms=csv replace;
run;

title 'Workstream 2B filing-time merge: status coverage';
proc print data=master.completion_merge_qa noobs;
run;

title 'Workstream 2B filing-time merge: nested attrition';
proc print data=master.completion_merge_attrition noobs;
run;

title 'Workstream 2B filing-time merge: invariants';
proc sql;
    select &input_n as input_n,
           count(*) as output_n,
           count(distinct deal_key) as output_deals,
           (select count(*) from work.final_deal_duplicates)
               as duplicate_deal_rows,
           sum(has_l1_skew and not skew_timing_valid)
               as invalid_skew_timing,
           sum(has_l1_aggregate_filings and not aggregate_timing_valid)
               as invalid_aggregate_timing
    from master.filing_completion_analysis;
quit;

title;
proc printto;
run;

/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
05b_stage2_price_revision.sas

Stage:
Stage 2 - Additional-test variable construction

Purpose:
Construct the firm-level analysis dataset for the price-revision test.
The test asks whether expected skewness predicts an upward revision from
the midpoint of the INITIAL filing range to the final offer price.

Methodological rules:
1. REV is signed: (offer price - initial midpoint) / initial midpoint.
2. Use the original low/high filing prices only. Do not fall back to an
   amended filing range.
3. Registration-period market returns run from the SDC filing date
   through the last CRSP trading day before the IPO issue date. Lowry and
   Schwert (2004) treat the offer price as set on the day before the IPO.
4. CRSP equal-weighted return is primary; value-weighted is robustness.
5. Do not winsorise REV in the construction program. Tail treatments, if
   approved, belong in explicitly labelled Stata robustness tests.

Inputs:
- master.analysis_full2
- master.crsp_index_daily

Outputs:
- master.price_revision_sample
- master.price_revision_attrition

Expected current counts before execution:
- Full IPO master: 8,923
- Valid original filing range and offer price: approximately 5,148

Last updated:
August 2026
********************************************************************/

%include "%sysget(IPO_CONFIG)";


/* ================================================================
   STEP 1. Create the signed price-revision variables
   ================================================================ */

data work.price_revision_base;
    set master.analysis_full2;

    analysis_id = _n_;

    /* Initial range only. Requiring both endpoints avoids MEAN()
       silently using a single observed endpoint. */
    if file_price_low > 0 and file_price_high > 0 then
        initial_midpoint = (file_price_low + file_price_high) / 2;
    else initial_midpoint = .;

    if initial_midpoint > 0 and oprc > 0 then do;
        rev_signed = (oprc - initial_midpoint) / initial_midpoint;
        rev_pos    = max(rev_signed, 0);
        abs_rev    = abs(rev_signed);
        rev_eligible = 1;
    end;
    else do;
        rev_signed  = .;
        rev_pos     = .;
        abs_rev     = .;
        rev_eligible = 0;
    end;

    registration_calendar_days = idate - fdate;
    valid_registration_dates =
        (not missing(fdate) and not missing(idate) and fdate < idate);

    /* SDC amount-filed field retained in the current master. The raw
       header is "Full History Amount Filed This Market (USD Millions)".
       SDC Platinum defines the domestic amount filed at full-history
       filing as original domestic shares filed multiplied by the
       original midpoint filing price. It is therefore a predetermined
       expected-proceeds measure for this test.

       It is character-valued and can contain a semicolon-delimited
       history (for example, "43.75;58.70;58.70"). Use the first
       nonblank history value as the initial amount-filed proxy. SCAN's
       default behavior ignores a leading empty token. Remove thousands
       separators before numeric conversion. */
    amount_filed_history_raw = Full_History_Amount_Filed_This_M;
    amount_filed_mil = input(
        compress(scan(amount_filed_history_raw, 1, ';'), ',$ '),
        ?? best32.
    );

    if not missing(amount_filed_history_raw) then
        n_amount_filed_history = countc(strip(amount_filed_history_raw), ';') + 1;
    else n_amount_filed_history = .;

    /* Reuse the observation-specific CPI conversion embedded in the
       existing actual-proceeds variables. Both source amounts are USD
       millions, so the same deflator is applicable. */
    if proceeds_mil > 0 and proceeds_adj1975 > 0 then
        proceeds_deflator1975 = proceeds_adj1975 / proceeds_mil;
    else proceeds_deflator1975 = .;

    if amount_filed_mil > 0 and proceeds_deflator1975 > 0 then do;
        amount_filed_adj1975    = amount_filed_mil * proceeds_deflator1975;
        ln_amount_filed_adj1975 = log(amount_filed_adj1975);
    end;
    else do;
        amount_filed_adj1975    = .;
        ln_amount_filed_adj1975 = .;
    end;

    label
        analysis_id                  = "Price-revision analysis row identifier"
        initial_midpoint             = "Midpoint of original filing price range"
        rev_signed                   = "Signed offer-price revision from initial midpoint"
        rev_pos                      = "Positive part of signed offer-price revision"
        abs_rev                      = "Absolute signed offer-price revision"
        rev_eligible                 = "Valid original filing range and offer price"
        valid_registration_dates     = "Filing date precedes IPO issue date"
        registration_calendar_days   = "Calendar days from filing to IPO issue"
        amount_filed_history_raw     = "Raw SDC semicolon-delimited amount-filed history"
        amount_filed_mil             = "Initial expected proceeds, USD millions"
        n_amount_filed_history       = "Number of SDC amount-filed history entries"
        proceeds_deflator1975        = "Existing IPO proceeds conversion to 1975 dollars"
        amount_filed_adj1975         = "Initial expected proceeds in 1975 USD millions"
        ln_amount_filed_adj1975      = "Log initial expected proceeds in 1975 USD millions"
    ;
run;


/* ================================================================
   STEP 2. Keep eligible IPOs for the registration-period join
   ================================================================ */

data work.price_revision_eligible;
    set work.price_revision_base;
    if rev_eligible = 1;
run;

proc sort data=work.price_revision_eligible;
    by analysis_id;
run;

proc sort data=master.crsp_index_daily
          out=work.crsp_index_daily(keep=date ewretd vwretd logewretd logvwretd);
    by date;
run;


/* ================================================================
   STEP 3. Compound CRSP returns over the registration period

   The interval includes CRSP trading dates on/after fdate and before
   idate. Thus the end point is the last trading day before the IPO.
   ================================================================ */

proc sql;
    create table work.registration_market_daily as
    select
        a.analysis_id,
        b.date,
        b.logewretd,
        b.logvwretd
    from work.price_revision_eligible as a
    inner join work.crsp_index_daily as b
        on b.date >= a.fdate
       and b.date <  a.idate
    where a.valid_registration_dates = 1
    order by a.analysis_id, b.date;
quit;

proc sql;
    create table work.registration_market_return as
    select
        analysis_id,
        count(logewretd) as n_reg_trading_days,
        min(date)        as reg_first_trading_date format=yymmddn8.,
        max(date)        as reg_last_trading_date  format=yymmddn8.,
        exp(sum(logewretd)) - 1 as mkt_reg_ew,
        exp(sum(logvwretd)) - 1 as mkt_reg_vw
    from work.registration_market_daily
    group by analysis_id;
quit;


/* ================================================================
   STEP 4. Merge returns and create analysis/readiness flags
   ================================================================ */

proc sort data=work.registration_market_return;
    by analysis_id;
run;

data master.price_revision_sample;
    merge work.price_revision_eligible(in=in_ipo)
          work.registration_market_return;
    by analysis_id;
    if in_ipo;

    if not missing(mkt_reg_ew) then mkt_reg_ew_pos = max(mkt_reg_ew, 0);
    else mkt_reg_ew_pos = .;

    if not missing(mkt_reg_vw) then mkt_reg_vw_pos = max(mkt_reg_vw, 0);
    else mkt_reg_vw_pos = .;

    has_registration_return =
        (n_reg_trading_days > 0 and not missing(mkt_reg_ew));
    has_expected_proceeds = not missing(ln_amount_filed_adj1975);

    has_core_controls =
        nmiss(skew1, age_ritter, internet, VB, uw_rank_ave,
              share_overhang, lagmcsi, ff30, ipo_year) = 0;

    has_full_controls =
        nmiss(skew1, age_ritter, coskewness, internet, NASDAQ, NYSE,
              VB, uw_rank_ave, share_overhang, pure_primary,
              lagmcsi, ipo_vol, ind_ret, ind_mom, ind_vol, ind_turn,
              ff30, ipo_year) = 0;

    ready_core_model =
        (has_registration_return = 1 and has_expected_proceeds = 1
         and has_core_controls = 1);

    ready_full_model =
        (has_registration_return = 1 and has_expected_proceeds = 1
         and has_full_controls = 1);

    registration_within_365 =
        (valid_registration_dates = 1
         and registration_calendar_days > 0
         and registration_calendar_days <= 365);

    revision_within_100pct =
        (not missing(abs_rev) and abs_rev <= 1);

    label
        n_reg_trading_days      = "CRSP trading days in registration period"
        reg_first_trading_date  = "First CRSP date in registration return"
        reg_last_trading_date   = "Last CRSP date before IPO issue"
        mkt_reg_ew              = "CRSP EW return from filing through pre-IPO day"
        mkt_reg_ew_pos          = "Positive part of CRSP EW registration return"
        mkt_reg_vw              = "CRSP VW return from filing through pre-IPO day"
        mkt_reg_vw_pos          = "Positive part of CRSP VW registration return"
        has_registration_return = "Nonmissing registration-period EW return"
        has_expected_proceeds   = "Nonmissing initial expected proceeds"
        has_core_controls       = "Complete core price-revision controls"
        has_full_controls       = "Complete full price-revision controls"
        ready_core_model        = "Complete expected-proceeds core model"
        ready_full_model        = "Complete expected-proceeds full model"
        registration_within_365 = "Filing-to-issue interval is 1-365 calendar days"
        revision_within_100pct  = "Absolute signed price revision is at most 100 percent"
    ;
run;


/* ================================================================
   STEP 5. Persist attrition counts and QA output
   ================================================================ */

proc sql;
    create table master.price_revision_attrition as
    select 1 as order, "Full analysis_full2 master" as step length=70,
           count(*) as n
    from work.price_revision_base

    union all
    select 2, "Valid original filing range and offer price", count(*)
    from master.price_revision_sample

    union all
    select 3, "+ valid registration-period EW return", count(*)
    from master.price_revision_sample
    where has_registration_return = 1

    union all
    select 4, "+ initial expected proceeds", count(*)
    from master.price_revision_sample
    where has_registration_return = 1
      and has_expected_proceeds = 1

    union all
    select 5, "+ complete core controls", count(*)
    from master.price_revision_sample
    where ready_core_model = 1

    union all
    select 6, "+ complete full controls", count(*)
    from master.price_revision_sample
    where ready_full_model = 1
    ;
quit;

proc sort data=master.price_revision_attrition;
    by order;
run;

title "Price Revision Additional Test: Sample Attrition";
proc print data=master.price_revision_attrition noobs;
run;

title "Price Revision Additional Test: Variable Distributions";
proc means data=master.price_revision_sample
           n nmiss mean std min p1 p5 p25 median p75 p95 p99 max;
    var rev_signed rev_pos
        mkt_reg_ew mkt_reg_vw n_reg_trading_days
        registration_calendar_days
        amount_filed_mil amount_filed_adj1975 ln_amount_filed_adj1975
        skew1;
run;

proc sort data=master.price_revision_sample
          out=work.price_revision_tail;
    by descending abs_rev;
run;

title "Price Revision Additional Test: Largest Absolute Revisions";
proc print data=work.price_revision_tail(obs=25) noobs;
    var issuer_name ticker idate fdate oprc file_price_low file_price_high
        initial_midpoint rev_signed skew1;
    format idate fdate yymmddn8.;
run;

proc sort data=master.price_revision_sample
          out=work.registration_period_tail;
    by descending registration_calendar_days;
run;

title "Price Revision Additional Test: Longest Registration Periods";
proc print data=work.registration_period_tail(obs=25) noobs;
    var issuer_name ticker idate fdate registration_calendar_days
        n_reg_trading_days rev_signed skew1;
    format idate fdate yymmddn8.;
run;

title "Price Revision Additional Test: Duplicate Deal Identifiers";
proc sql;
    select deal_num, count(*) as n
    from master.price_revision_sample
    where not missing(deal_num)
    group by deal_num
    having count(*) > 1;
quit;

title;

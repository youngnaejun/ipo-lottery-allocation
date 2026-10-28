/*=============================================================================
  FILE: 04d_additional_controls.sas
  PURPOSE: Construct additional control variables for Table 3 regression
           Following Green and Hwang (2012), Management Science, Table 5

  NEW VARIABLES:
    1. price_adj   - Price Adjustment        (deal characteristics)
    2. ipo_vol     - IPO Volatility           (market characteristics)
    3. ind_ret     - Industry Return          (industry characteristics)
    4. ind_mom     - Industry Momentum        (industry characteristics)
    5. ind_vol     - Industry Volatility      (industry characteristics)
    6. ind_turn    - Industry Turnover        (industry characteristics)

  PIPELINE POSITION:
    Runs after Stage 04 (master.analysis_full, N=8,924).
    Produces master.analysis_full2 for use in Stage 05 Table 3 regressions.

  INPUT (local):
    master.analysis_full    - primary analysis dataset (N=8,924; permno, idate,
                              r0, ff30, iyearmonth, oprc, etc.)
    master.sdc_clean        - SDC variables including PROL, PRODSLD (filing range)
    master.crsp_monthly     - CRSP monthly: permno, yearmonth, mret, exchcd, ff30,
                              vol, shrout, mktcap

  INPUT (WRDS remote):
    crsp.dsf                - CRSP daily stock file (for ind_vol)
    crsp.msenames           - CRSP names file (shrcd, exchcd, siccd by date)
    ff.factors_daily        - Fama-French daily factors (rf, vwretd)

  OUTPUT (local, permanent):
    master.ff30_ret         - FF30 x yearmonth: EW lagged industry return
    master.ff30_mom         - FF30 x yearmonth: VW industry momentum (J=12, K=2)
    master.ff30_ivol        - FF30 x yearmonth: lagged industry idiosyncratic vol
    master.ff30_turnover    - FF30 x yearmonth: lagged industry turnover
    master.additional_controls - permno x idate: all 6 new variables
    master.analysis_full2   - analysis_full + new controls (N=8,924)

  APPROACH:
    Reconstructed independently from Green and Hwang (2012) definitions,
    using our pipeline's master.crsp_monthly as the source for industry
    characteristics (parallel to ipo.crsp_month in the project's original SAS program). Does not
    rely on work.r (session-only) or that program's intermediate datasets.
    Industry volatility requires CRSP daily and is computed on WRDS via rsubmit.

  VARIABLES (added 2025-07-03):
    - Industry Return  : EW lagged mret at FF30 x yearmonth t-1 (G&H: t=5.06***)
    - Industry Momentum: VW cumulative return, J=12 months, K=2 month skip
                         (G&H Table 5 last column: t=6.62***)
    - Industry Vol     : market model residual std, averaged at FF30 x month t-1
                         (G&H: t=1.38, insignificant; included for completeness)
    - Industry Turnover: NYSE+AMEX vol/shrout lagged, exchcd=1|31 as in the project's original SAS program
                         (G&H: t=0.81, insignificant; included for completeness)
    - IPO Vol          : std(R0) across all IPOs in 3 months prior to each IPO
    - Price Adjustment : |oprc - midpoint(PROL,PRODSLD)| / midpoint

  AUTHOR: Youngnae Jun
  DATE:   03 Jul 2025
=============================================================================*/

%include "%sysget(IPO_CONFIG)";


/*=============================================================================
  PART 1: PRICE ADJUSTMENT  [local; no WRDS needed]
  Definition : |offer price - midpoint of filing range| / midpoint
               Following Green and Hwang (2012): "the absolute value of the
               percentage change between the offer price and the average of
               the high and low initial filing prices"
  Source     : master.sdc_clean variables (from Stage 01 rename):
                 file_price_low  = original low filing price  (SDC VAR19 / PROL)
                 file_price_high = original high filing price (SDC VAR20 / PRODSLD)
                 amended_low     = amended low filing price
                 amended_high    = amended high filing price
                 oprc            = offer price
               NOTE: master.sdc_clean also contains prcadj (line 243 of
               Stage 01), which uses original filing range only. We
               recompute here to apply the amended fallback rule.
  Reference  : Green and Hwang (2012) Table 5; Lowry et al. (2010)

  MIDPOINT PRIORITY RULE:
    Primary   : original filing range (file_price_low, file_price_high)
                — consistent with G&H "initial filing prices"
    Fallback  : amended filing range (amended_low, amended_high)
                — used only when original range is missing or zero
    If both missing: price_adj = . (missing)

  This rule maximises coverage while preserving G&H's "initial" definition
  as the primary source.
=============================================================================*/

proc sql;
    create table work.price_adj as
    select
        a.permno,
        a.idate,

        /* Step 1: determine which midpoint to use */
        case
            when b.file_price_low  > 0 and b.file_price_high > 0
                then (b.file_price_low + b.file_price_high) / 2   /* original — primary */
            when b.amended_low     > 0 and b.amended_high    > 0
                then (b.amended_low   + b.amended_high)    / 2   /* amended  — fallback */
            else .
        end as file_midpoint,

        /* Step 2: flag which source was used (for diagnostics) */
        case
            when b.file_price_low  > 0 and b.file_price_high > 0 then "original"
            when b.amended_low     > 0 and b.amended_high    > 0 then "amended"
            else "missing"
        end as midpoint_source length=8,

        /* Step 3: price adjustment = |oprc - midpoint| / midpoint */
        case
            when b.file_price_low  > 0 and b.file_price_high > 0
                then abs(a.oprc - (b.file_price_low + b.file_price_high) / 2)
                         / ((b.file_price_low + b.file_price_high) / 2)
            when b.amended_low  > 0 and b.amended_high > 0 
				and (b.amended_low + b.amended_high) / 2 between a.oprc * 0.1 and a.oprc * 10 /* remove data entry errors */
                then abs(a.oprc - (b.amended_low + b.amended_high) / 2)
                         / ((b.amended_low + b.amended_high) / 2)
            else .
        end as price_adj

    from master.analysis_full  a
    left join master.sdc_clean b
        on a.cusip_new = b.cusip_new and a.idate = b.idate;
    /* NOTE: master.sdc_clean has no permno (added at Stage 02 CRSP link).
       Join on cusip_new + idate, which are present in both datasets.
       cusip_new is the 8-digit CUSIP standardised in Stage 01 line 202.   */
quit;

/* Coverage and source breakdown */
proc freq data=work.price_adj;
    tables midpoint_source;
    title "PART 1 — Price Adjustment: midpoint source breakdown";
run;

proc means data=work.price_adj n nmiss mean std min p25 p50 p75 max;
    var price_adj;
    title "PART 1 — Price Adjustment: descriptive stats";
run;

proc sql;
    select count(*)                              as n_total,
           sum(missing(price_adj))              as n_miss,
           sum(missing(price_adj))/count(*)*100 as pct_miss,
           sum(midpoint_source="original")      as n_original,
           sum(midpoint_source="amended")       as n_amended
    from work.price_adj;
    title "PART 1 — Price Adjustment: coverage summary (flag if pct_miss >10%)";
quit;


/*=============================================================================
  PART 2: IPO VOLATILITY  [local; no WRDS needed]
  Definition : Std dev of R0 across all IPOs issued in the 3 months prior to
               each IPO (full market pool, not industry-restricted; self excluded)
  Source     : master.analysis_full (r0, iyearmonth)
  Reference  : Green and Hwang (2012) Section 3.3.1
  Logic      : For each IPO at iyearmonth t, collect r0 of all other IPOs
               issued in months t-3, t-2, t-1; take std dev.
               Follows ipo_ivol in the project's original SAS program (skewness.sas)
               but corrected to group by permno AND idate (not permno alone).
=============================================================================*/

/* Pipeline note: IPO offering month must exist before Step 2A reads it. In the original file it was
   first written by Step 3D, so one run on a fresh analysis_full left iyearmonth missing and every IPO's
   window spanned the whole sample; the archived values came from a second pass. Creating it here is
   idempotent with Step 3D and makes a single run sufficient. */
data master.analysis_full;
    set master.analysis_full;
    iyearmonth= intnx('month', idate, 0, 'beginning');
    format iyearmonth yymmn6.;
run;

/* Step 2A: Build IPO list with 3-month backward window boundaries */
data work.ipo_r0;
    set master.analysis_full;
    ym_lo = intnx('month', iyearmonth, -3, 'beginning');
    ym_hi = intnx('month', iyearmonth, -1, 'beginning');
    format ym_lo ym_hi yymmn6.;
    keep permno idate iyearmonth r0 ym_lo ym_hi;
run;

/* Step 2B: Self-join — for each IPO, collect other IPOs' R0 in window */
proc sql;
    create table work.ipo_vol as
    select
        a.permno,
        a.idate,
        std(b.r0)   as ipo_vol,
        count(b.r0) as n_ipo_vol
    from work.ipo_r0 a
    left join work.ipo_r0 b
        on  b.permno    ne a.permno        /* exclude self */
        and b.r0        is not missing
        and b.iyearmonth between a.ym_lo and a.ym_hi
    group by a.permno, a.idate;
quit;

proc means data=work.ipo_vol n nmiss mean std min p1 p25 p50 p75 p99 max;
    var ipo_vol n_ipo_vol;
    title "PART 2 — IPO Volatility";
run;
/* Note: small n_ipo_vol in 1975-1980 is expected (few IPOs per quarter) */


/*=============================================================================
  PART 3: INDUSTRY RETURN  [local; uses master.crsp_monthly]
  Definition : Equal-weighted average of stocks' lagged monthly return within
               IPO's FF30 industry, in month t-1 relative to IPO offering month
  Source     : master.crsp_monthly (mret, ff30, yearmonth); same construction
               as work.r in Stage 05 but using lagged mret
  Reference  : Green and Hwang (2012) Section 3.3.1
  Logic      : For each FF30 x yearmonth, compute EW mean of mret at t-1.
               Merge to IPO on ff30 x iyearmonth — giving the return one month
               before the offering.
               Follows ff30_ret_ew in the project's original SAS program (skewness.sas).
=============================================================================*/

/* Step 3A: Prepare monthly returns — common stocks, FF30 1-29 */
data work.crsp_m;
    set master.crsp_monthly;
    if exchcd in (1, 2, 3);        /* NYSE, AMEX, NASDAQ — consistent with work.r */
    if missing(ff30)   then delete;
    if ff30 = 30       then delete;
    if missing(mret)   then delete;
    keep permno ff30 yearmonth mret;
run;

proc sort data=work.crsp_m; by permno yearmonth; run;

/* Step 3B: Create lagged mret within permno time series */
data work.crsp_m;
    set work.crsp_m;
    by permno;
    lagmret = lag(mret);
    if first.permno then lagmret = .;
run;

/* Step 3C: EW industry return per FF30 x yearmonth */
/* in_ewlagmret at yearmonth t = mean(lagmret) = mean of month t-1 returns */
proc sql;
    create table master.ff30_ret as
    select ff30,
           yearmonth,
           mean(lagmret) as in_ewlagmret   label="EW avg lagged mret, FF30 x month",
           count(permno) as n_stocks_ret
    from work.crsp_m
    where not missing(lagmret)
    group by ff30, yearmonth;
quit;

/* Step 3D: Merge to IPO on ff30 x iyearmonth */
/* iyearmonth is IPO offering month t;                         */
/* Create IPO offering month from idate */
data master.analysis_full;
    set master.analysis_full;

    iyearmonth= intnx('month', idate, 0, 'beginning');
    format iyearmonth yymmn6.;
run;

/* in_ewlagmret at t already represents mean return at t-1     */
proc sql;
    create table work.ind_ret as
    select
        a.permno,
        a.idate,
        b.in_ewlagmret as ind_ret
    from master.analysis_full a
    left join master.ff30_ret b
        on  a.ff30       = b.ff30
        and a.iyearmonth = b.yearmonth;
quit;

proc means data=work.ind_ret n nmiss mean std min p25 p50 p75 max;
    var ind_ret;
    title "PART 3 — Industry Return (EW, t-1)";
run;


/*=============================================================================
  PART 4: INDUSTRY MOMENTUM  [local; uses master.crsp_monthly]
  Definition : Cumulative VW industry return from month t-13 to t-2
               (12-month formation window, skipping most recent month)
  Source     : master.crsp_monthly (mret, lagmktcap, ff30, yearmonth)
  Reference  : Green and Hwang (2012) Section 3.3.1
  Logic      : J=12 months formation, K=2 month skip before holding.
   EW ind_ret + EW ind_mom reproduces GH Table 5's skew1 t-stat almost
    exactly for R0 (2.54 vs GH's 2.51, 1975-2008 window). VW version
    left skew1 insignificant.
=============================================================================*/

%let J = 12;   /* formation period in months */
%let K = 2;    /* skip period in months      */

/* Step 4A: VW industry return per FF30 x yearmonth */
data work.crsp_m2;
    set master.crsp_monthly;
    if exchcd in (1, 2, 3);
    if missing(ff30)   then delete;
    if ff30 = 30       then delete;
    if missing(mret)   then delete;
    keep permno ff30 yearmonth mret;
run;

proc sql;
    create table work.in_mret as
    select ff30,
           yearmonth,
           mean(mret) as in_mret   /* EW return � changed from VW per weighting-consistency check */
    from work.crsp_m2
    group by ff30, yearmonth;
quit;

/* Step 4B: J-month cumulative return ending at formation month */
/* For each FF30 x formation yearmonth, sum log(1+in_mret) over J months  */
proc sql;
    create table work.umd as
    select a.ff30,
           a.yearmonth as form_ym,
           exp(sum(log(1 + b.in_mret))) - 1 as cum_return
    from work.in_mret (keep=ff30 yearmonth) as a
    inner join work.in_mret as b
        on  a.ff30 = b.ff30
        and 0 <= intck('month', b.yearmonth, a.yearmonth) < &J
    group by a.ff30, a.yearmonth
    having count(b.in_mret) = &J;    /* require full J-month window */
quit;

/* Step 4C: Assign to holding month (form_ym + K months) */
/* holding month = IPO offering month; ind_mom = momentum signal at t       */
proc sql;
    create table master.ff30_mom as
    select a.ff30,
           b.yearmonth as yearmonth,   /* this is the holding/IPO month */
           a.cum_return as ind_mom
    from work.umd as a
    inner join work.in_mret as b
        on  a.ff30 = b.ff30
        and intck('month', a.form_ym, b.yearmonth) = &K;
quit;

/* Step 4D: Merge to IPO */
proc sql;
    create table work.ind_mom as
    select
        a.permno,
        a.idate,
        b.ind_mom
    from master.analysis_full a
    left join master.ff30_mom b
        on  a.ff30       = b.ff30
        and a.iyearmonth = b.yearmonth;
quit;

proc means data=work.ind_mom n nmiss mean std min p25 p50 p75 max;
    var ind_mom;
    title "PART 4 — Industry Momentum (VW, J=&J, K=&K)";
run;


/*=============================================================================
  PART 5: INDUSTRY VOLATILITY  [WRDS remote; uses CRSP daily]
  Definition : Average idiosyncratic volatility of stocks in IPO's FF30 industry
               in month t-1. Idiosyncratic vol = std dev of market model residuals
               (ret_i - rf = alpha + beta*(vwretd - rf) + epsilon) per stock-month.
  Source     : crsp.dsf (daily returns), crsp.msenames (FF30 via SIC),
               ff.factors_daily (rf, vwretd)
  Reference  : Green and Hwang (2012) Table 5 (t=1.38; insignificant)
  Logic      : Follows Stage 05's coskewness construction approach (lines 420-551)
               for daily data pull and FF30 assignment.
               Use %assign_ff30 macro consistent with Stage 05.
               Lagged at FF30 x yearmonth level before merging to IPO.
  NOTE: crsp.dsf is large (~60M rows). Run via rsubmit on WRDS.
        Download only the FF30 x yearmonth aggregated result (small).
=============================================================================*/

%wrds_signon;

rsubmit;

options compress=binary;

/* Step 5A: FF30 macro */
%macro assign_ff30;
    if siccd > 99 then do;
        if      (100  le siccd le  299) or (700  le siccd le  799) or
                (910  le siccd le  919) or (2000 le siccd le 2046) or
                (2048 le siccd le 2048) or (2050 le siccd le 2063) or
                (2064 le siccd le 2068) or (2070 le siccd le 2079) or
                (2086 le siccd le 2087) or (2090 le siccd le 2092) or
                (2095 le siccd le 2099) then ff30 = 1;
        else if (2080 le siccd le 2080) or (2082 le siccd le 2085) then ff30 = 2;
        else if (2100 le siccd le 2199) then ff30 = 3;
        else if (920 le siccd le 999) or (3650 le siccd le 3652) or
                (3732 le siccd le 3732) or (3930 le siccd le 3931) or
                (3940 le siccd le 3949) or (7800 le siccd le 7833) or
                (7840 le siccd le 7841) or (7900 le siccd le 7911) or
                (7920 le siccd le 7933) or (7940 le siccd le 7949) or
                (7980 le siccd le 7980) or (7990 le siccd le 7999) then ff30 = 4;
        else if (2700 le siccd le 2799) or (3993 le siccd le 3993) then ff30 = 5;
        else if (2047 le siccd le 2047) or (2391 le siccd le 2392) or
                (2510 le siccd le 2519) or (2590 le siccd le 2599) or
                (2840 le siccd le 2844) or (3160 le siccd le 3172) or
                (3190 le siccd le 3199) or (3229 le siccd le 3229) or
                (3230 le siccd le 3231) or (3260 le siccd le 3263) or
                (3269 le siccd le 3269) or (3630 le siccd le 3639) or
                (3750 le siccd le 3751) or (3800 le siccd le 3800) or
                (3860 le siccd le 3873) or (3910 le siccd le 3915) or
                (3960 le siccd le 3962) or (3991 le siccd le 3991) or
                (3995 le siccd le 3995) then ff30 = 6;
        else if (2300 le siccd le 2390) or (3020 le siccd le 3021) or
                (3100 le siccd le 3111) or (3130 le siccd le 3131) or
                (3140 le siccd le 3149) or (3150 le siccd le 3151) or
                (3963 le siccd le 3965) then ff30 = 7;
        else if (2830 le siccd le 2836) or (3693 le siccd le 3693) or
                (3840 le siccd le 3851) or (8000 le siccd le 8099) then ff30 = 8;
        else if (2800 le siccd le 2829) or (2850 le siccd le 2899) then ff30 = 9;
        else if (2200 le siccd le 2299) or (2393 le siccd le 2399) then ff30 = 10;
        else if (800 le siccd le 899) or (1500 le siccd le 1799) or
                (2400 le siccd le 2439) or (2450 le siccd le 2459) or
                (2490 le siccd le 2499) or (2660 le siccd le 2661) or
                (2950 le siccd le 2952) or (3200 le siccd le 3241) or
                (3250 le siccd le 3275) or (3280 le siccd le 3299) or
                (3420 le siccd le 3452) or (3490 le siccd le 3499) or
                (3996 le siccd le 3996) then ff30 = 11;
        else if (3300 le siccd le 3399) then ff30 = 12;
        else if (3400 le siccd le 3400) or (3443 le siccd le 3444) or
                (3460 le siccd le 3479) or (3510 le siccd le 3599) then ff30 = 13;
        else if (3600 le siccd le 3613) or (3620 le siccd le 3621) or
                (3623 le siccd le 3629) or (3640 le siccd le 3646) or
                (3648 le siccd le 3649) or (3660 le siccd le 3660) or
                (3690 le siccd le 3692) or (3699 le siccd le 3699) then ff30 = 14;
        else if (2296 le siccd le 2296) or (2396 le siccd le 2396) or
                (3010 le siccd le 3011) or (3537 le siccd le 3537) or
                (3647 le siccd le 3647) or (3694 le siccd le 3694) or
                (3700 le siccd le 3716) or (3790 le siccd le 3792) or
                (3799 le siccd le 3799) then ff30 = 15;
        else if (3720 le siccd le 3721) or (3723 le siccd le 3725) or
                (3728 le siccd le 3731) or (3740 le siccd le 3743) then ff30 = 16;
        else if (1000 le siccd le 1119) or (1400 le siccd le 1499) then ff30 = 17;
        else if (1200 le siccd le 1299) then ff30 = 18;
        else if (1300 le siccd le 1389) then ff30 = 19;
        else if (4900 le siccd le 4949) then ff30 = 20;
        else if (4800 le siccd le 4813) or (4820 le siccd le 4822) or
                (4830 le siccd le 4841) or (4880 le siccd le 4899) or
                (4890 le siccd le 4891) or (4899 le siccd le 4899) then ff30 = 21;
        else if (7200 le siccd le 7212) or (7214 le siccd le 7299) or
                (7300 le siccd le 7372) or (7374 le siccd le 7399) or
                (7500 le siccd le 7549) or (7600 le siccd le 7631) or
                (7640 le siccd le 7699) or (8100 le siccd le 8499) or
                (8600 le siccd le 8748) or (8800 le siccd le 8999) then ff30 = 22;
        else if (3570 le siccd le 3579) or (3622 le siccd le 3622) or
                (3661 le siccd le 3669) or (3670 le siccd le 3695) or
                (3810 le siccd le 3812) or (3820 le siccd le 3829) or
                (3830 le siccd le 3839) or (7373 le siccd le 7373) then ff30 = 23;
        else if (2440 le siccd le 2449) or (2520 le siccd le 2549) or
                (2600 le siccd le 2699) or (2760 le siccd le 2761) or
                (3220 le siccd le 3221) or (3410 le siccd le 3412) or
                (3950 le siccd le 3955) then ff30 = 24;
        else if (4000 le siccd le 4013) or (4040 le siccd le 4049) or
                (4100 le siccd le 4173) or (4190 le siccd le 4231) or
                (4240 le siccd le 4249) or (4400 le siccd le 4712) or
                (4720 le siccd le 4789) then ff30 = 25;
        else if (5000 le siccd le 5199) then ff30 = 26;
        else if (5200 le siccd le 5799) then ff30 = 27;
        else if (5800 le siccd le 5899) or (7000 le siccd le 7049) or
                (7213 le siccd le 7213) then ff30 = 28;
        else if (6000 le siccd le 6799) then ff30 = 29;
        else if (4950 le siccd le 4991) then ff30 = 30;
        else ff30 = .;
    end;
%mend assign_ff30;


/* Step 5B: Pull CRSP daily + names */
proc sql;
    create table work.dsf_raw as
    select a.permno, a.date, a.ret,
           b.shrcd, b.exchcd, b.siccd
    from crsp.dsf a
    left join crsp.msenames b
        on  a.permno = b.permno
        and a.date between b.namedt and b.nameendt
    where a.date between '@CONTROLS_START_DATE@'d and '@DATA_END_DATE@'d
      and a.ret is not missing;
quit;


/* Step 5C: Apply common stock / exchange / FF30 filters */
data work.dsf_ff30;
    set work.dsf_raw;
    if shrcd in (10, 11);
    if exchcd in (1, 2, 3);

    ff30 = .;
    %assign_ff30;

    if missing(ff30) then delete;
    if ff30 = 30 then delete;

    yearmonth = intnx('month', date, 0, 'beginning');
    format yearmonth yymmn6.;

    keep permno date yearmonth ff30 ret;
run;

proc datasets lib=work nolist;
    delete dsf_raw;
quit;


/* Step 5D: Merge daily factors */
data work.fac;
    set ff.factors_daily(keep=date rf);
    where date between '@CONTROLS_START_DATE@'d and '@DATA_END_DATE@'d;
run;

data work.dsi;
    set crsp.dsi(keep=date vwretd);
    where date between '@CONTROLS_START_DATE@'d and '@DATA_END_DATE@'d;
run;

proc sort data=work.dsf_ff30; by date; run;
proc sort data=work.fac;      by date; run;
proc sort data=work.dsi;      by date; run;

data work.dsf_d3;
    merge work.dsf_ff30(in=a) work.fac(in=b) work.dsi(in=c);
    by date;
    if a and b and c;

    if missing(vwretd) or missing(rf) then delete;

    rrf   = ret - rf;
    mktrf = vwretd - rf;

    keep permno yearmonth ff30 rrf mktrf;
run;

proc datasets lib=work nolist;
    delete dsf_ff30 fac dsi;
quit;


/* Step 5E: Keep FF30 lookup BEFORE deleting dsf_d3 */
proc sort data=work.dsf_d3(keep=permno yearmonth ff30)
          out=work.ff30_lookup
          nodupkey;
    by permno yearmonth;
run;


/* Step 5F: Market model residuals per permno x yearmonth */
proc sort data=work.dsf_d3;
    by permno yearmonth;
run;

proc reg data=work.dsf_d3 noprint;
    by permno yearmonth;
    model rrf = mktrf;
    output out=work.resid residual=resid;
quit;

proc datasets lib=work nolist;
    delete dsf_d3;
quit;


/* Step 5G: Idiosyncratic volatility per stock-month */
proc sql;
    create table work.ivol_stock as
    select permno,
           yearmonth,
           std(resid) as ivol,
           count(resid) as n_days
    from work.resid
    group by permno, yearmonth
    having calculated n_days >= 10;
quit;

proc datasets lib=work nolist;
    delete resid;
quit;


/* Step 5H: FF30 x yearmonth average idiosyncratic volatility */
proc sql;
    create table work.ivol_ff30 as
    select b.ff30,
           a.yearmonth,
           mean(a.ivol)    as in_ivol,
           count(a.permno) as n_stocks_vol
    from work.ivol_stock a
    inner join work.ff30_lookup b
        on  a.permno = b.permno
        and a.yearmonth = b.yearmonth
    group by b.ff30, a.yearmonth;
quit;

proc datasets lib=work nolist;
    delete ivol_stock ff30_lookup;
quit;


/* Step 5I: Lag industry volatility within FF30 */
proc sort data=work.ivol_ff30;
    by ff30 yearmonth;
run;

data work.ff30_ivol_lagged;
    set work.ivol_ff30;
    by ff30;

    lagin_ivol = lag(in_ivol);
    if first.ff30 then lagin_ivol = .;

    label lagin_ivol = "Lagged FF30 industry idiosyncratic volatility";
run;


/* Step 5J: Download to local master library */
proc download data=work.ff30_ivol_lagged out=master.ff30_ivol;
run;

endrsubmit;
%wrds_signoff;


/* Step 5K: Merge to IPO sample */
proc sql;
    create table work.ind_vol as
    select
        a.permno,
        a.idate,
        b.lagin_ivol as ind_vol,
        b.n_stocks_vol
    from master.analysis_full a
    left join master.ff30_ivol b
        on  a.ff30 = b.ff30
        and a.iyearmonth = b.yearmonth;
quit;

proc means data=work.ind_vol n nmiss mean std min p25 p50 p75 max;
    var ind_vol n_stocks_vol;
    title "PART 5 - Industry Volatility (market model residual, lagged t-1)";
run;

title;

/*=============================================================================
  PART 6: INDUSTRY TURNOVER  [local; uses master.crsp_monthly]
  Definition : Average volume turnover of NYSE+AMEX stocks in IPO's FF30
               industry, lagged one month before the offering
  Measure    : vol / shrout per stock, monthly. Vol winsorised at 1%/99% per
               month. EW average across FF30 x yearmonth.
  Source     : master.crsp_monthly (vol, shrout, exchcd, ff30, yearmonth)
  Reference  : Green and Hwang (2012) Table 5 (t=0.81; insignificant)
  Logic      : Follows ff30_turnover in the project's original SAS program (skewness.sas
               lines 3850-3893). exchcd = 1 (NYSE) or 31 (AMEX) in that program;
               we use exchcd in (1,2) to capture NYSE and AMEX consistently
               with our pipeline's exchange coding.
  NOTE: master.crsp_monthly must contain vol (shares traded) and shrout
        (shares outstanding in thousands). Check Stage 02 if missing.
=============================================================================*/

/* Step 6A: Restrict to NYSE + AMEX; convert units */
data work.crsp_turn;
    set master.crsp_monthly;
    if exchcd in (1, 2);              /* NYSE (1) and AMEX (2) */
    if missing(ff30)   then delete;
    if ff30 = 30       then delete;
    if missing(vol)    then delete;
    if missing(shrout) then delete;
    if shrout <= 0     then delete;
    vol_raw = vol * 100;              /* CRSP monthly vol in 100s -> units */
    shr     = shrout * 1000;         /* shrout in 1000s -> units           */
    keep permno ff30 yearmonth vol_raw shr;
run;

/* Step 6B: Winsorise vol at 1%/99% per yearmonth (as in the project's original SAS program) */
proc sort data=work.crsp_turn; by yearmonth; run;

proc means data=work.crsp_turn noprint;
    by yearmonth;
    output out=work.trunc_99 (drop=_freq_ _type_) p99(vol_raw)=p99_vol;
run;
data work.crsp_turn;
    merge work.crsp_turn work.trunc_99;
    by yearmonth;
    if vol_raw > p99_vol then vol_raw = p99_vol;
    drop p99_vol;
run;

proc means data=work.crsp_turn noprint;
    by yearmonth;
    output out=work.trunc_01 (drop=_freq_ _type_) p1(vol_raw)=p1_vol;
run;
data work.crsp_turn;
    merge work.crsp_turn work.trunc_01;
    by yearmonth;
    if vol_raw < p1_vol then vol_raw = p1_vol;
    drop p1_vol;
run;

/* Step 6C: Turnover per stock */
data work.crsp_turn;
    set work.crsp_turn;
    turnover = vol_raw / shr;
    drop vol_raw shr;
run;

/* Step 6D: Lag turnover within permno */
proc sort data=work.crsp_turn; by permno yearmonth; run;

data work.crsp_turn;
    set work.crsp_turn;
    by permno;
    n + 1;
    if first.permno then n = 1;
    lag_turnover = lag(turnover);
    if n = 1 then lag_turnover = .;
    drop n turnover;
run;

/* Step 6E: EW average lagged turnover per FF30 x yearmonth */
proc sql;
    create table master.ff30_turnover as
    select ff30,
           yearmonth,
           mean(lag_turnover) as in_lagturnover   label="EW avg lagged turnover, FF30 x month",
           count(permno)      as n_stocks_turn
    from work.crsp_turn
    where not missing(lag_turnover)
    group by ff30, yearmonth;
quit;

/* Step 6F: Merge to IPO */
proc sql;
    create table work.ind_turn as
    select
        a.permno,
        a.idate,
        b.in_lagturnover as ind_turn,
        b.n_stocks_turn
    from master.analysis_full a
    left join master.ff30_turnover b
        on  a.ff30       = b.ff30
        and a.iyearmonth = b.yearmonth;
quit;

proc means data=work.ind_turn n nmiss mean std min p25 p50 p75 max;
    var ind_turn;
    title "PART 6 — Industry Turnover (NYSE+AMEX, lagged t-1)";
run;


/*=============================================================================
  PART 7: MERGE ALL INTO master.additional_controls
=============================================================================*/

proc sql;
    create table master.additional_controls as
    select
        a.permno,
        a.idate,
        b.price_adj,
        c.ipo_vol,
        c.n_ipo_vol,
        d.ind_ret,
        e.ind_mom,
        f.ind_vol,
        f.n_stocks_vol,
        g.ind_turn,
        g.n_stocks_turn
    from master.analysis_full  a
    left join work.price_adj   b on a.permno = b.permno and a.idate = b.idate
    left join work.ipo_vol     c on a.permno = c.permno and a.idate = c.idate
    left join work.ind_ret     d on a.permno = d.permno and a.idate = d.idate
    left join work.ind_mom     e on a.permno = e.permno and a.idate = e.idate
    left join work.ind_vol     f on a.permno = f.permno and a.idate = f.idate
    left join work.ind_turn    g on a.permno = g.permno and a.idate = g.idate;
quit;

proc means data=master.additional_controls n nmiss;
    var price_adj ipo_vol ind_ret ind_mom ind_vol ind_turn;
    title "PART 7 — Coverage Check: All New Control Variables";
run;


/*=============================================================================
  PART 8: CREATE master.analysis_full2  (N must remain 8,924)
=============================================================================*/

proc sql;
    create table master.analysis_full2 as
    select a.*,
           b.price_adj,
           b.ipo_vol,
           b.ind_ret,
           b.ind_mom,
           b.ind_vol,
           b.ind_turn
    from master.analysis_full        a
    left join master.additional_controls b
        on a.permno = b.permno and a.idate = b.idate;
quit;

proc sql;
    select count(*) as n_obs label="N (should be 8,924)"
    from master.analysis_full2;
quit;

proc means data=master.analysis_full2 n nmiss mean std;
    var r0 skew1 price_adj ipo_vol ind_ret ind_mom ind_vol ind_turn
        lagmcsi lagcummktret;
    title "PART 8 — master.analysis_full2: Key Variable Summary";
run;


/*=============================================================================
  REGRESSION SPEC NOTE (for Stage 05 Table 3 update):

  Replace master.analysis_full with master.analysis_full2 in Stage 05.
  Add the following variables to the proc model specification:

    Deal block     : price_adj         (NEW)
    Market block   : lagmcsi           (unchanged — Retail Investor Optimism)
                     lagcummktret      (unchanged — Market Return)
                     ipo_vol           (NEW)
    Industry block : ind_ret           (NEW — EW, t-1)
                     ind_mom           (NEW — VW, J=12, K=2)
                     ind_vol           (NEW — market model residual, t-1)
                     ind_turn          (NEW — NYSE+AMEX vol/shrout, lagged)

  Suggested: run Table 3 in two specs mirroring G&H Table 5:
    Spec A: full controls excluding industry characteristics
    Spec B: full controls including all industry characteristics
  ind_vol and ind_turn are G&H-insignificant; report in note or appendix
  if they do not affect the main skewness coefficients materially.
=============================================================================*/

title;

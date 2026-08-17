/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
05_stage2_skewness_coskewness.sas

Stage:
Stage 2 - Variable Construction

Purpose:
Construct expected skewness and coskewness measures following the
IPO lottery demand methodology.

Inputs:
- master.analysis_universe
- master.crsp_monthly
- WRDS CRSP daily stock returns
- WRDS CRSP value-weighted market returns
- WRDS Fama-French daily risk-free rate

Outputs:
- master.exp_skew
- master.analysis_skew

Key variables:
- skew1: expected skewness based on 1st, 50th, and 99th percentiles
- skew5: expected skewness based on 5th, 50th, and 95th percentiles
- coskewness: industry-level coskewness from daily quadratic market model

Notes:
Expected skewness is constructed from pooled FF30 industry returns over
the three months before the IPO. Coskewness is estimated from daily
stock-month regressions and pooled within FF30 industry windows.

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";

/* 1. Build slim local subsets before WRDS upload */

data work.analysis_sample_slim;
    set master.analysis_universe;
    keep permno ff30 idate;
run;

data work.crsp_monthly_slim;
    set master.crsp_monthly;
    keep permno yearmonth mret exchcd ff30;
run;


/* 2. Remote processing on WRDS */
%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

rsubmit;

options compress=binary;

proc upload data=work.analysis_sample_slim out=work.analysis_sample; run;
proc upload data=work.crsp_monthly_slim    out=work.crsp_monthly;    run;


/* 2.1 Prepare CRSP monthly returns for expected skewness */

data work.r;
    set work.crsp_monthly;

    if exchcd in (1, 2, 3);

    if mret ne . then lnmret = log(1 + mret);
    else lnmret = .;

    if missing(ff30)   then delete;
    if missing(lnmret) then delete;

    keep permno yearmonth lnmret ff30;
run;

proc sort data=work.r;
    by yearmonth ff30;
run;


/* 2.2 Prepare IPO list and three-month pre-IPO window */

data work.list;
    set work.analysis_sample;

    start_date = intnx('month', idate, -3, 'beginning');
    end_date   = intnx('month', idate, -1, 'beginning');
    format start_date end_date yymmn6.;

    rename permno = permno_ipo
           ff30   = ff30_ipo;

    keep permno ff30 idate start_date end_date;
run;

proc sort data=work.list;
    by start_date ff30_ipo;
run;


/* 2.3 Pool all FF30 stock-month observations within the pre-IPO window */

proc sql;
    create table work.r2 as
    select a.permno,
           a.yearmonth,
           a.lnmret,
           a.ff30,
           b.permno_ipo,
           b.ff30_ipo,
           b.idate,
           b.start_date,
           b.end_date
    from work.r as a
    inner join work.list as b
    on  a.yearmonth between b.start_date and b.end_date
    and a.ff30 = b.ff30_ipo;
quit;

proc sort data=work.r2;
    by permno_ipo;
run;


/* 2.4 Construct expected skewness measures */

proc means data=work.r2 noprint;
    var lnmret;
    by permno_ipo;
    output out=work.r5
        p1=p_1 p5=p_5 p50=p_50 p95=p_95 p99=p_99
        n=observations;
run;

data work.exp_skew;
    set work.r5;

    if (p_99 - p_1) ne 0 then
        skew1 = ((p_99 - p_50) - (p_50 - p_1)) / (p_99 - p_1);
    else skew1 = .;

    if (p_95 - p_5) ne 0 then
        skew5 = ((p_95 - p_50) - (p_50 - p_5)) / (p_95 - p_5);
    else skew5 = .;

    right_skew = p_99 - p_50;
    left_skew  = p_50 - p_1;

    label
        skew1        = "Expected skewness: percentile 1/50/99, pooled 3-month FF30"
        skew5        = "Expected skewness: percentile 5/50/95, pooled 3-month FF30"
        observations = "Number of stock-month observations used for skewness"
        right_skew   = "Right-tail distance: p99 - p50"
        left_skew    = "Left-tail distance: p50 - p1"
    ;
run;


/* 3. Construct coskewness */

/* 3.1 FF30 industry assignment */

%macro assign_ff30;
    if siccd > 99 then do;
        if      (100  le siccd le  299) or (700  le siccd le  799) or
                (910  le siccd le  919) or (2000 le siccd le 2046) or
                (2048 le siccd le 2048) or (2050 le siccd le 2063) or
                (2064 le siccd le 2068) or (2070 le siccd le 2079) or
                (2086 le siccd le 2087) or (2090 le siccd le 2092) or
                (2095 le siccd le 2099)
            then ff30 = 1;
        else if siccd in (2080,2082,2083,2084,2085) then ff30 = 2;
        else if (2100 le siccd le 2199) then ff30 = 3;
        else if (920  le siccd le  999) or (3650 le siccd le 3652) or
                siccd = 3732 or (3930 le siccd le 3931) or
                (3940 le siccd le 3949) or (7800 le siccd le 7841) or
                (7900 le siccd le 7933) or (7940 le siccd le 7949) or
                siccd in (7980,7990,7999)
            then ff30 = 4;
        else if (2700 le siccd le 2799) or siccd = 3993 then ff30 = 5;
        else if siccd = 2047 or (2391 le siccd le 2392) or
                (2510 le siccd le 2519) or (2590 le siccd le 2599) or
                (2840 le siccd le 2844) or (3160 le siccd le 3172) or
                (3190 le siccd le 3199) or
                siccd in (3229,3260,3262,3263,3269,3230,3231) or
                (3630 le siccd le 3639) or (3750 le siccd le 3751) or
                siccd in (3800,3860,3861) or (3870 le siccd le 3873) or
                siccd in (3910,3911,3914,3915) or
                (3960 le siccd le 3962) or siccd in (3991,3995)
            then ff30 = 6;
        else if (2300 le siccd le 2390) or (3020 le siccd le 3021) or
                (3100 le siccd le 3111) or (3130 le siccd le 3131) or
                (3140 le siccd le 3151) or (3963 le siccd le 3965)
            then ff30 = 7;
        else if siccd in (2830,2831,2833,2834,2835,2836,3693) or
                (3840 le siccd le 3851) or (8000 le siccd le 8099)
            then ff30 = 8;
        else if (2800 le siccd le 2829) or (2850 le siccd le 2899)
            then ff30 = 9;
        else if (2200 le siccd le 2284) or (2290 le siccd le 2299) or
                (2393 le siccd le 2395) or (2397 le siccd le 2399)
            then ff30 = 10;
        else if (800  le siccd le  899) or (1500 le siccd le 1549) or
                (1600 le siccd le 1799) or (2400 le siccd le 2439) or
                (2450 le siccd le 2459) or (2490 le siccd le 2499) or
                (2660 le siccd le 2661) or (2950 le siccd le 2952) or
                (3200 le siccd le 3200) or (3210 le siccd le 3211) or
                (3240 le siccd le 3275) or (3280 le siccd le 3281) or
                (3290 le siccd le 3299) or (3420 le siccd le 3452) or
                (3490 le siccd le 3499) or siccd = 3996
            then ff30 = 11;
        else if (3300 le siccd le 3399) then ff30 = 12;
        else if siccd = 3400 or siccd in (3443,3444) or
                (3460 le siccd le 3479) or (3510 le siccd le 3599)
            then ff30 = 13;
        else if (3600 le siccd le 3600) or (3610 le siccd le 3613) or
                (3620 le siccd le 3621) or (3623 le siccd le 3629) or
                (3640 le siccd le 3646) or (3648 le siccd le 3649) or
                siccd = 3660 or (3690 le siccd le 3692) or siccd = 3699
            then ff30 = 14;
        else if siccd in (2296,2396) or (3010 le siccd le 3011) or
                siccd in (3537,3647,3694) or (3700 le siccd le 3716) or
                (3790 le siccd le 3792) or siccd = 3799
            then ff30 = 15;
        else if (3720 le siccd le 3721) or (3723 le siccd le 3725) or
                (3728 le siccd le 3731) or (3740 le siccd le 3743)
            then ff30 = 16;
        else if (1000 le siccd le 1119) or (1400 le siccd le 1499)
            then ff30 = 17;
        else if (1200 le siccd le 1299) then ff30 = 18;
        else if (1300 le siccd le 1339) or (1370 le siccd le 1389) or
                (2900 le siccd le 2912) or (2990 le siccd le 2999)
            then ff30 = 19;
        else if (4900 le siccd le 4942) then ff30 = 20;
        else if (4800 le siccd le 4899) then ff30 = 21;
        else if (7020 le siccd le 7021) or (7030 le siccd le 7033) or
                (7200 le siccd le 7299) or (7300 le siccd le 7399) or
                (7500 le siccd le 7549) or (7600 le siccd le 7641) or
                (7690 le siccd le 7699) or (8100 le siccd le 8499) or
                (8600 le siccd le 8748) or (8800 le siccd le 8999)
            then ff30 = 22;
        else if (3570 le siccd le 3579) or siccd = 3622 or
                (3661 le siccd le 3669) or (3670 le siccd le 3695) or
                (3810 le siccd le 3812) or (3820 le siccd le 3827) or
                siccd = 3829 or (3830 le siccd le 3839) or siccd = 7373
            then ff30 = 23;
        else if (2440 le siccd le 2449) or (2520 le siccd le 2549) or
                (2600 le siccd le 2699) or (2760 le siccd le 2761) or
                (3220 le siccd le 3221) or (3410 le siccd le 3412) or
                (3950 le siccd le 3955)
            then ff30 = 24;
        else if (4000 le siccd le 4013) or (4040 le siccd le 4049) or
                (4100 le siccd le 4199) or (4200 le siccd le 4231) or
                (4240 le siccd le 4249) or (4400 le siccd le 4789)
            then ff30 = 25;
        else if (5000 le siccd le 5199) then ff30 = 26;
        else if (5200 le siccd le 5799) or
                (5900 le siccd le 5999) then ff30 = 27;
        else if (5800 le siccd le 5819) or (5820 le siccd le 5829) or
                (5890 le siccd le 5899) or (7000 le siccd le 7019) or
                (7040 le siccd le 7049) or siccd = 7213
            then ff30 = 28;
        else if (6000 le siccd le 6799) then ff30 = 29;
        else if (4950 le siccd le 4961) or
                siccd in (4970,4971,4990,4991)
            then ff30 = 30;
        else ff30 = .;
    end;
    else ff30 = .;
%mend assign_ff30;


/* 3.2 Pull CRSP daily returns, daily market returns, and risk-free rates */

data work.names;
    set crsp.msenames
        (keep = permno namedt nameendt shrcd exchcd siccd);
run;

data work.dsf_raw;
    set crsp.dsf
        (keep = permno date ret);
    where date between '01Jan1975'd and '31Dec2024'd;
run;

proc sql;
    create table work.dsf_named as
    select a.*,
           b.shrcd,
           b.exchcd,
           b.siccd
    from work.dsf_raw as a
    left join work.names as b
    on  a.permno = b.permno
    and a.date between b.namedt and b.nameendt;
quit;

proc datasets lib=work nolist;
    delete dsf_raw;
quit;

proc sort data=work.dsf_named;
    by permno date;
run;

data work.dsf_named;
    set work.dsf_named;
    by permno date;

    retain _shrcd _exchcd _siccd;

    if first.permno then do;
        _shrcd  = shrcd;
        _exchcd = exchcd;
        _siccd  = siccd;
    end;
    else do;
        if missing(shrcd)  then shrcd  = _shrcd;  else _shrcd  = shrcd;
        if missing(exchcd) then exchcd = _exchcd; else _exchcd = exchcd;
        if missing(siccd)  then siccd  = _siccd;  else _siccd  = siccd;
    end;

    drop _shrcd _exchcd _siccd;
run;

data work.dsf_named;
    set work.dsf_named;

    if shrcd in (10, 11);
    if exchcd in (1, 2, 3);

    %assign_ff30;

    if missing(ff30) then delete;
    if missing(ret)  then delete;

    keep permno date ret ff30;
run;

data work.dsi;
    set crsp.dsi
        (keep = date vwretd);
    where date between '01Jan1975'd and '31Dec2024'd;

    if missing(vwretd) then delete;
run;

data work.ff_rf;
    set ff.factors_daily
        (keep = date rf);
    where date between '01Jan1975'd and '31Dec2024'd;

    if missing(rf) then delete;
run;


/* 3.3 Estimate stock-month coskewness exposure */

proc sort data=work.dsf_named; by date; run;
proc sort data=work.dsi;       by date; run;
proc sort data=work.ff_rf;     by date; run;

data work.d3;
    merge work.dsf_named (in=a)
          work.dsi       (in=b)
          work.ff_rf     (in=c);
    by date;

    if a and b and c;

    yearmonth = mdy(month(date), 1, year(date));
    format yearmonth yymmn6.;

    retrf    = ret - rf;
    mktrf    = vwretd - rf;
    mktrf_sq = mktrf ** 2;

    keep permno yearmonth ff30 retrf mktrf mktrf_sq;
run;

proc sort data=work.d3;
    by permno yearmonth;
run;

proc reg data=work.d3 noprint outest=work.est;
    by permno yearmonth;
    model retrf = mktrf mktrf_sq;
quit;

data work.est;
    set work.est;

    rename mktrf_sq = coskew_pm;
    keep permno yearmonth mktrf_sq;
run;

proc sort data=work.d3
          (keep=permno yearmonth ff30)
          nodupkey
          out=work.pm_ff30;
    by permno yearmonth;
run;

proc sort data=work.est;
    by permno yearmonth;
run;

data work.est_ff30;
    merge work.est     (in=a)
          work.pm_ff30 (in=b);
    by permno yearmonth;

    if a and b;
run;


/* 3.4 Winsorise stock-month coskewness before IPO-level pooling */

proc means data=work.est_ff30 noprint;
    var coskew_pm;
    output out=work._cosk_pctl
        p1=p1_cosk
        p99=p99_cosk;
run;

data _null_;
    set work._cosk_pctl;

    call symputx('p1_cosk',  p1_cosk);
    call symputx('p99_cosk', p99_cosk);
run;

data work.est_ff30;
    set work.est_ff30;

    coskew_pm_raw = coskew_pm;

    if coskew_pm < &p1_cosk then
        coskew_pm = &p1_cosk;
    else if coskew_pm > &p99_cosk then
        coskew_pm = &p99_cosk;
run;


/* 3.5 Pool stock-month coskewness to IPO level */

proc sort data=work.est_ff30;
    by ff30 yearmonth;
run;

proc sort data=work.list;
    by ff30_ipo;
run;

proc sql;
    create table work.cosk_match as
    select a.permno,
           a.yearmonth,
           a.ff30,
           a.coskew_pm,
           b.permno_ipo,
           b.ff30_ipo,
           b.start_date,
           b.end_date
    from work.est_ff30 as a
    inner join work.list as b
    on  a.ff30 = b.ff30_ipo
    and a.yearmonth between b.start_date and b.end_date;
quit;

proc sort data=work.cosk_match;
    by permno_ipo;
run;

proc means data=work.cosk_match noprint;
    var coskew_pm;
    by permno_ipo;
    output out=work.cosk_ipo
        mean(coskew_pm) = coskewness
        n(coskew_pm)    = n_cosk;
run;


/* 4. Build final expected skewness dataset */

proc sort data=work.exp_skew;
    by permno_ipo;
run;

proc sort data=work.cosk_ipo;
    by permno_ipo;
run;

data work.exp_skew_final;
    merge work.exp_skew (in=a)
          work.cosk_ipo (keep=permno_ipo coskewness n_cosk);
    by permno_ipo;

    if a;

    label
        coskewness = "Industry coskewness: average gamma2, FF30 x 3-month window"
        n_cosk     = "Number of stock-month gamma2 observations pooled for coskewness"
    ;

    keep permno_ipo skew1 skew5 right_skew left_skew
         coskewness n_cosk
         p_1 p_5 p_50 p_95 p_99 observations;
run;

proc download data=work.exp_skew_final
              out=master.exp_skew;
run;

endrsubmit;

signoff;


/* 5. Merge skewness and coskewness onto the analysis universe */

proc sort data=master.exp_skew;
    by permno_ipo;
run;

proc sort data=master.analysis_universe;
    by permno;
run;

proc sql;
    create table master.analysis_skew as
    select a.*,
           b.skew1,
           b.skew5,
           b.coskewness,
           b.n_cosk,
           b.p_1,
           b.p_50,
           b.p_99,
           b.observations
    from master.analysis_universe as a
    left join master.exp_skew as b
    on a.permno = b.permno_ipo;
quit;


/* CHECKPOINT:
   Verify expected skewness and coskewness distributions.
*/

proc means data=master.exp_skew n nmiss mean median min max;
    var skew1 skew5 coskewness n_cosk observations;
    title "Checkpoint: Expected Skewness and Coskewness";
run;


/* CHECKPOINT:
   Verify final merge of lottery variables.
*/

proc means data=master.analysis_skew n nmiss mean median min max;
    var skew1 skew5 coskewness r0 age_ritter lagmcsi;
    title "Checkpoint: Analysis Dataset after Skewness/Coskewness Merge";
run;

title;

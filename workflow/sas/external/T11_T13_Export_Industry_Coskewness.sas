%include "%sysget(IPO_CONFIG)";
/* T11-T13 industry-quarter coskewness export, 22 September 2026.
   Run in local SAS with SAS/CONNECT and existing WRDS CRSP/FF permissions.
   Credentials are entered only in SAS's own sign-on prompt.
   Reuses the current project's stock-month model, FF30 mapping,
   1975-2024 estimation universe and global 1/99 winsorisation.
   It does not use IPO-level coskewness averages or alter master datasets.
   If already signed on as WRDS, omit the SIGNON line below.
   Large CRSP daily data remain on WRDS; only quarterly aggregates download.
*/
%wrds_signon;
rsubmit;
options compress=binary;
%macro t1113_assign_ff30;
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
%mend t1113_assign_ff30;


/* 3.2 Pull CRSP daily returns, daily market returns, and risk-free rates */

data work.t1113_names;
    set crsp.msenames
        (keep = permno namedt nameendt shrcd exchcd siccd);
run;

data work.t1113_dsf_raw;
    set crsp.dsf
        (keep = permno date ret);
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;
run;

proc sql;
    create table work.t1113_dsf_named as
    select a.*,
           b.shrcd,
           b.exchcd,
           b.siccd
    from work.t1113_dsf_raw as a
    left join work.t1113_names as b
    on  a.permno = b.permno
    and a.date between b.namedt and b.nameendt;
quit;

proc datasets lib=work nolist;
    delete dsf_raw;
quit;

proc sort data=work.t1113_dsf_named;
    by permno date;
run;

data work.t1113_dsf_named;
    set work.t1113_dsf_named;
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

data work.t1113_dsf_named;
    set work.t1113_dsf_named;

    if shrcd in (10, 11);
    if exchcd in (1, 2, 3);

    %t1113_assign_ff30;

    if missing(ff30) then delete;
    if missing(ret)  then delete;

    keep permno date ret ff30;
run;

data work.t1113_dsi;
    set crsp.dsi
        (keep = date vwretd);
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;

    if missing(vwretd) then delete;
run;

data work.t1113_ff_rf;
    set ff.factors_daily
        (keep = date rf);
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;

    if missing(rf) then delete;
run;


/* 3.3 Estimate stock-month coskewness exposure */

proc sort data=work.t1113_dsf_named; by date; run;
proc sort data=work.t1113_dsi;       by date; run;
proc sort data=work.t1113_ff_rf;     by date; run;

data work.t1113_d3;
    merge work.t1113_dsf_named (in=a)
          work.t1113_dsi       (in=b)
          work.t1113_ff_rf     (in=c);
    by date;

    if a and b and c;

    yearmonth = mdy(month(date), 1, year(date));
    format yearmonth yymmn6.;

    retrf    = ret - rf;
    mktrf    = vwretd - rf;
    mktrf_sq = mktrf ** 2;

    keep permno yearmonth ff30 retrf mktrf mktrf_sq;
run;

proc sort data=work.t1113_d3;
    by permno yearmonth;
run;

proc reg data=work.t1113_d3 noprint outest=work.t1113_est;
    by permno yearmonth;
    model retrf = mktrf mktrf_sq;
quit;

data work.t1113_est;
    set work.t1113_est;

    rename mktrf_sq = coskew_pm;
    keep permno yearmonth mktrf_sq;
run;

proc sort data=work.t1113_d3
          (keep=permno yearmonth ff30)
          nodupkey
          out=work.t1113_pm_ff30;
    by permno yearmonth;
run;

proc sort data=work.t1113_est;
    by permno yearmonth;
run;

data work.t1113_est_ff30;
    merge work.t1113_est     (in=a)
          work.t1113_pm_ff30 (in=b);
    by permno yearmonth;

    if a and b;
run;


/* 3.4 Winsorise stock-month coskewness before IPO-level pooling */

proc means data=work.t1113_est_ff30 noprint;
    var coskew_pm;
    output out=work.t1113__cosk_pctl
        p1=p1_cosk
        p99=p99_cosk;
run;

data _null_;
    set work.t1113__cosk_pctl;

    call symputx('p1_cosk',  p1_cosk);
    call symputx('p99_cosk', p99_cosk);
run;

data work.t1113_est_ff30;
    set work.t1113_est_ff30;

    coskew_pm_raw = coskew_pm;

    if coskew_pm < &p1_cosk then
        coskew_pm = &p1_cosk;
    else if coskew_pm > &p99_cosk then
        coskew_pm = &p99_cosk;
run;



/* Aggregate individual stock-month observations, not monthly means.
   SAS missing-value handling in the source winsorisation is retained exactly. */
data work.t1113_cosk_quarter_input;
    set work.t1113_est_ff30;
    time_id = (year(yearmonth)-1960)*4 + qtr(yearmonth)-1;
    if ff30 >= 1 and ff30 <= 29;
    if time_id >= 91 and time_id <= 259;
run;
proc summary data=work.t1113_cosk_quarter_input nway;
    class ff30 time_id;
    var coskew_pm;
    output out=work.t1113_cosk_quarter(drop=_type_ _freq_)
        mean=cosk n=n_stock_months;
run;
proc sort data=work.t1113_cosk_quarter;
    by ff30 time_id;
run;
proc download data=work.t1113_cosk_quarter
    out=work.t1113_cosk_quarter_local;
run;
endrsubmit;
proc export data=work.t1113_cosk_quarter_local
    outfile="&ext.\sep21_25\industry_quarter_coskewness.csv"
    dbms=csv replace;
run;
proc means data=work.t1113_cosk_quarter_local n nmiss min max;
    var ff30 time_id cosk n_stock_months;
run;
/* Keep the connection available for troubleshooting; no SIGNOFF. */

%wrds_signoff;

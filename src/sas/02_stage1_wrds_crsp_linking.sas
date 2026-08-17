/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
02_stage1_wrds_crsp_linking.sas

Stage:
Stage 1 - Sample Construction

Purpose:
Link the cleaned SDC IPO sample with CRSP, construct required CRSP
daily/monthly and index datasets, assign FF30 industries, and extract
market return information for later analysis.

Inputs:
- master.sdc_clean
- WRDS CRSP daily/monthly files
- WRDS CRSP index files
- WRDS Compustat fundamentals

Outputs:
- master.sdc_crsp
- master.crsp_monthly
- master.crsp_index_daily
- master.mktret_15day
- master.compustat_be

Notes:
Missing CRSP SIC codes are supplemented using Compustat CUSIP-based
matching before FF30 assignment.

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";

/*---------------------------------------------------------------------------
  CONNECT TO WRDS
---------------------------------------------------------------------------*/
%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

rsubmit;

/*---------------------------------------------------------------------------
  UPLOAD CLEANED SDC SAMPLE TO WRDS WORK
---------------------------------------------------------------------------*/
proc upload data=master.sdc_clean
            out=work.sdc_clean;
run;

options compress=binary;

/*---------------------------------------------------------------------------
  FF30 MACRO DEFINITION
---------------------------------------------------------------------------*/
%macro assign_ff30;
    if siccd > 99 then do;
        if      (100  le siccd le  299) or
                (700  le siccd le  799) or
                (910  le siccd le  919) or
                (2000 le siccd le 2046) or
                (2048 le siccd le 2048) or
                (2050 le siccd le 2063) or
                (2064 le siccd le 2068) or
                (2070 le siccd le 2079) or
                (2086 le siccd le 2087) or
                (2090 le siccd le 2092) or
                (2095 le siccd le 2099)
            then ff30 = 1;
        else if siccd in (2080,2082,2083,2084,2085) then ff30 = 2;
        else if (2100 le siccd le 2199) then ff30 = 3;
        else if (920  le siccd le  999) or
                (3650 le siccd le 3652) or
                siccd = 3732 or
                (3930 le siccd le 3931) or
                (3940 le siccd le 3949) or
                (7800 le siccd le 7841) or
                (7900 le siccd le 7933) or
                (7940 le siccd le 7949) or
                siccd in (7980,7990,7999)
            then ff30 = 4;
        else if (2700 le siccd le 2799) or siccd = 3993 then ff30 = 5;
        else if siccd = 2047 or
                (2391 le siccd le 2392) or
                (2510 le siccd le 2519) or
                (2590 le siccd le 2599) or
                (2840 le siccd le 2844) or
                (3160 le siccd le 3172) or
                (3190 le siccd le 3199) or
                siccd in (3229,3260,3262,3263,3269,3230,3231) or
                (3630 le siccd le 3639) or
                (3750 le siccd le 3751) or
                siccd in (3800,3860,3861) or
                (3870 le siccd le 3873) or
                siccd in (3910,3911,3914,3915) or
                (3960 le siccd le 3962) or
                siccd in (3991,3995)
            then ff30 = 6;
        else if (2300 le siccd le 2390) or
                (3020 le siccd le 3021) or
                (3100 le siccd le 3111) or
                (3130 le siccd le 3131) or
                (3140 le siccd le 3151) or
                (3963 le siccd le 3965)
            then ff30 = 7;
        else if siccd in (2830,2831,2833,2834,2835,2836,3693) or
                (3840 le siccd le 3851) or
                (8000 le siccd le 8099)
            then ff30 = 8;
        else if (2800 le siccd le 2829) or
                (2850 le siccd le 2899)
            then ff30 = 9;
        else if (2200 le siccd le 2284) or
                (2290 le siccd le 2299) or
                (2393 le siccd le 2395) or
                (2397 le siccd le 2399)
            then ff30 = 10;
        else if (800  le siccd le  899) or
                (1500 le siccd le 1549) or
                (1600 le siccd le 1799) or
                (2400 le siccd le 2439) or
                (2450 le siccd le 2459) or
                (2490 le siccd le 2499) or
                (2660 le siccd le 2661) or
                (2950 le siccd le 2952) or
                (3200 le siccd le 3200) or
                (3210 le siccd le 3211) or
                (3240 le siccd le 3275) or
                (3280 le siccd le 3281) or
                (3290 le siccd le 3299) or
                (3420 le siccd le 3452) or
                (3490 le siccd le 3499) or
                siccd = 3996
            then ff30 = 11;
        else if (3300 le siccd le 3399) then ff30 = 12;
        else if siccd = 3400 or
                siccd in (3443,3444) or
                (3460 le siccd le 3479) or
                (3510 le siccd le 3599)
            then ff30 = 13;
        else if (3600 le siccd le 3600) or
                (3610 le siccd le 3613) or
                (3620 le siccd le 3621) or
                (3623 le siccd le 3629) or
                (3640 le siccd le 3646) or
                (3648 le siccd le 3649) or
                siccd = 3660 or
                (3690 le siccd le 3692) or
                siccd = 3699
            then ff30 = 14;
        else if siccd in (2296,2396) or
                (3010 le siccd le 3011) or
                siccd in (3537,3647,3694) or
                (3700 le siccd le 3716) or
                (3790 le siccd le 3792) or
                siccd = 3799
            then ff30 = 15;
        else if (3720 le siccd le 3721) or
                (3723 le siccd le 3725) or
                (3728 le siccd le 3731) or
                (3740 le siccd le 3743)
            then ff30 = 16;
        else if (1000 le siccd le 1119) or
                (1400 le siccd le 1499)
            then ff30 = 17;
        else if (1200 le siccd le 1299) then ff30 = 18;
        else if (1300 le siccd le 1339) or
                (1370 le siccd le 1389) or
                (2900 le siccd le 2912) or
                (2990 le siccd le 2999)
            then ff30 = 19;
        else if (4900 le siccd le 4942) then ff30 = 20;
        else if (4800 le siccd le 4899) then ff30 = 21;
        else if (7020 le siccd le 7021) or
                (7030 le siccd le 7033) or
                (7200 le siccd le 7299) or
                (7300 le siccd le 7399) or
                (7500 le siccd le 7549) or
                (7600 le siccd le 7641) or
                (7690 le siccd le 7699) or
                (8100 le siccd le 8499) or
                (8600 le siccd le 8748) or
                (8800 le siccd le 8999)
            then ff30 = 22;
        else if (3570 le siccd le 3579) or
                siccd = 3622 or
                (3661 le siccd le 3669) or
                (3670 le siccd le 3695) or
                (3810 le siccd le 3812) or
                (3820 le siccd le 3827) or
                siccd = 3829 or
                (3830 le siccd le 3839) or
                siccd = 7373
            then ff30 = 23;
        else if (2440 le siccd le 2449) or
                (2520 le siccd le 2549) or
                (2600 le siccd le 2699) or
                (2760 le siccd le 2761) or
                (3220 le siccd le 3221) or
                (3410 le siccd le 3412) or
                (3950 le siccd le 3955)
            then ff30 = 24;
        else if (4000 le siccd le 4013) or
                (4040 le siccd le 4049) or
                (4100 le siccd le 4199) or
                (4200 le siccd le 4231) or
                (4240 le siccd le 4249) or
                (4400 le siccd le 4789)
            then ff30 = 25;
        else if (5000 le siccd le 5199) then ff30 = 26;
        else if (5200 le siccd le 5799) or
                (5900 le siccd le 5999) then ff30 = 27;
        else if (5800 le siccd le 5819) or
                (5820 le siccd le 5829) or
                (5890 le siccd le 5899) or
                (7000 le siccd le 7019) or
                (7040 le siccd le 7049) or
                siccd = 7213
            then ff30 = 28;
        else if (6000 le siccd le 6799) then ff30 = 29;
        else if (4950 le siccd le 4961) or
                siccd in (4970,4971,4990,4991)
            then ff30 = 30;
        else ff30 = .;
    end;
    else ff30 = .;
%mend assign_ff30;

/*===========================================================================
  STEP 1: CRSP DAILY
===========================================================================*/

data work.names;
    set crsp.msenames (keep = permno namedt nameendt shrcd exchcd siccd ncusip);
run;

data work.crsp_daily_raw;
    set crsp.dsf (keep = permno date prc ret vol shrout);
    where date between '01Jan1970'd and '31Dec2024'd;
run;

proc sql;
    create table work.daily_named as
    select a.*, b.shrcd, b.exchcd, b.siccd, b.ncusip
    from work.crsp_daily_raw as a
    left join work.names as b
    on a.permno = b.permno
    and a.date between b.namedt and b.nameendt;
quit;

proc datasets lib=work nolist; delete crsp_daily_raw; quit;

proc sort data=work.daily_named; by permno date; run;

data work.daily_named;
    set work.daily_named;
    by permno date;
    retain _shrcd _exchcd _siccd _ncusip;
    if first.permno then do;
        _shrcd = shrcd; _exchcd = exchcd;
        _siccd = siccd; _ncusip = ncusip;
    end;
    else do;
        if missing(shrcd)  then shrcd  = _shrcd;  else _shrcd  = shrcd;
        if missing(exchcd) then exchcd = _exchcd; else _exchcd = exchcd;
        if missing(siccd)  then siccd  = _siccd;  else _siccd  = siccd;
        if missing(ncusip) then ncusip = _ncusip; else _ncusip = ncusip;
    end;
    drop _shrcd _exchcd _siccd _ncusip;
run;

data work.daily_named;
    set work.daily_named;
    if shrcd in (10, 11);
run;

data work.daily_named;
    set work.daily_named;
    if prc = -99 then prc = .;
    absprc = abs(prc);
run;

data work.daily_named;
    set work.daily_named;
    by permno;
    retain _absprc;
    if first.permno then _absprc = .;
    if absprc ne . then _absprc = absprc;
    else absprc = _absprc;
    drop _absprc;
run;

data work.daily_named;
    set work.daily_named;
    by permno;
    n + 1;
    if first.permno then n = 1;
    lagabsprc = lag(absprc);
    if n = 1 then lagabsprc = .;
run;

data work.daily_named;
    set work.daily_named;
    if missing(ret) then ret = (absprc - lagabsprc) / lagabsprc;
    drop lagabsprc n;
run;

data work.crsp_daily;
    set work.daily_named;
    yearmonth = mdy(month(date), 1, year(date));
    format yearmonth yymmn6.;
    %assign_ff30;
    keep permno date prc ret vol shrout
         exchcd shrcd siccd ncusip
         absprc yearmonth ff30;
    label ff30 = "Fama-French 30 industry";
run;

proc datasets lib=work nolist; delete daily_named; quit;

/*===========================================================================
  STEP 2: CRSP MONTHLY
===========================================================================*/

data work.crsp_monthly_raw;
    set crsp.msf (keep = permno date ret altprc shrout vol);
    where date between '01Jan1970'd and '31Dec2024'd;
run;

proc sql;
    create table work.monthly_named as
    select a.*, b.shrcd, b.exchcd, b.siccd, b.ncusip
    from work.crsp_monthly_raw as a
    left join work.names as b
    on a.permno = b.permno
    and a.date between b.namedt and b.nameendt;
quit;

proc datasets lib=work nolist; delete crsp_monthly_raw; quit;

proc sort data=work.monthly_named; by permno date; run;

data work.monthly_named;
    set work.monthly_named;
    by permno;
    retain _shrcd _exchcd _siccd _ncusip;
    if first.permno then do;
        _shrcd = shrcd; _exchcd = exchcd;
        _siccd = siccd; _ncusip = ncusip;
    end;
    else do;
        if missing(shrcd)  then shrcd  = _shrcd;  else _shrcd  = shrcd;
        if missing(exchcd) then exchcd = _exchcd; else _exchcd = exchcd;
        if missing(siccd)  then siccd  = _siccd;  else _siccd  = siccd;
        if missing(ncusip) then ncusip = _ncusip; else _ncusip = ncusip;
    end;
    drop _shrcd _exchcd _siccd _ncusip;
run;

data work.monthly_named;
    set work.monthly_named;
    if shrcd in (10, 11);
    if altprc = -99 then altprc = .;
    absmprc = abs(altprc);
    rename ret = mret;
run;

data work.monthly_named;
    set work.monthly_named;
    by permno;
    retain _absmprc;
    if first.permno then _absmprc = .;
    if absmprc ne . then _absmprc = absmprc;
    else absmprc = _absmprc;
    drop _absmprc;
run;

data work.monthly_named;
    set work.monthly_named;
    by permno;
    n + 1;
    if first.permno then n = 1;
    lagabsmprc = lag(absmprc);
    lagshrout  = lag(shrout);
    if n = 1 then do; lagabsmprc = .; lagshrout = .; end;
run;

data work.crsp_monthly;
    set work.monthly_named;
    if missing(mret) then mret = (absmprc - lagabsmprc) / lagabsmprc;
    mktcap    = shrout    * absmprc / 1000;
    lagmktcap = lagshrout * lagabsmprc / 1000;
    yearmonth = mdy(month(date), 1, year(date));
    format yearmonth yymmn6.;
    %assign_ff30;
    drop lagabsmprc lagshrout n;
    label
        mktcap    = "Market cap end of month (millions)"
        lagmktcap = "Lagged market cap (millions)"
        ff30      = "Fama-French 30 industry"
    ;
run;

proc datasets lib=work nolist; delete monthly_named; quit;

/*===========================================================================
  STEP 3: CRSP INDEX
===========================================================================*/

data work.crsp_index_daily;
    set crsp.dsi (keep = date ewretd vwretd);
    where date between '01Jan1970'd and '31Dec2024'd;
    if missing(ewretd) then delete;
    logewretd = log(1 + ewretd);
    logvwretd = log(1 + vwretd);
run;

/*===========================================================================
  STEP 4: COMPUSTAT
===========================================================================*/

data work.compustat_be;
    set comp.funda (keep = gvkey cusip datadate ceq);
    where not missing(ceq) and ceq > 0;
    if not missing(cusip) and length(strip(cusip)) >= 8 then
        cusip8 = substr(strip(cusip), 1, 8);
    else cusip8 = "";
    if cusip8 = "" then delete;
    format datadate yymmddn8.;
run;

proc sort data=work.compustat_be; by cusip8 datadate; run;
proc sort data=work.compustat_be nodupkey; by cusip8; run;

/*===========================================================================
  STEP 5: SDC + CRSP MERGE
===========================================================================*/

proc sort data=work.crsp_daily; by permno date; run;

data work.crsp_first;
    set work.crsp_daily;
    by permno;
    if first.permno;
    keep permno date ncusip exchcd shrcd siccd absprc ret shrout ff30;
    rename date = crsp_first_date;
run;

proc sort data=work.sdc_clean; by cusip_new; run;
proc sort data=work.crsp_first; by ncusip; run;

proc sql;
    create table work.sdc_crsp_raw as
    select a.*, b.permno, b.crsp_first_date,
           b.exchcd, b.shrcd, b.siccd, b.absprc, b.ret as ret_first,
           b.shrout, b.ff30
    from work.sdc_clean as a
    left join work.crsp_first as b
    on a.cusip_new = b.ncusip;
quit;

data work.sdc_crsp_raw;
    set work.sdc_crsp_raw;
    if missing(permno) then delete;
run;

data work.sdc_crsp_raw;
    set work.sdc_crsp_raw;
    date_diff = crsp_first_date - idate;
run;

data work.sdc_crsp;
    set work.sdc_crsp_raw;
    if date_diff in (0, 1);

    if absprc > . and oprc > . then r0 = (absprc - oprc) / oprc;

    total_offered = primary_shares;
    if shrout > . and total_offered > . then do;
        retained = (shrout * 1000) - total_offered;
        if total_offered > 0 then
            share_overhang = log(1 + retained / total_offered);
    end;

    if exchcd in (1, 31) then NYSE_crsp   = 1; else NYSE_crsp   = 0;
    if exchcd in (3, 33) then NASDAQ_crsp = 1; else NASDAQ_crsp = 0;

    label
        r0             = "First-day return"
        share_overhang = "ln(1 + retained/offered)"
        NYSE_crsp      = "NYSE listing dummy - crsp"
        NASDAQ_crsp    = "NASDAQ listing dummy - crsp"
    ;
run;

proc datasets lib=work nolist; delete sdc_crsp_raw crsp_first; quit;

/* Identify cases needing SIC patch */
data work.sic_missing;
    set work.sdc_crsp;
    where siccd = 9999 or missing(siccd);
    keep permno cusip_new idate ipo_year;
run;


/* Pull SIC from Compustat 6-digit CUSIP match */
proc sql;
    create table work.sic_from_comp as
    select a.permno,
           b.sich    as siccd_comp,
           b.datadate
    from work.sic_missing as a
    inner join comp.funda as b
    on substr(a.cusip_new, 1, 6) = substr(b.cusip, 1, 6)
    and b.indfmt  = 'INDL'
    and b.datafmt = 'STD'
    and b.popsrc  = 'D'
    and b.consol  = 'C'
    where not missing(b.sich)
    and b.sich not in (0, 9999);
quit;

/* Keep most recent Compustat SIC per permno */
proc sort data=work.sic_from_comp;
    by permno descending datadate;
run;

proc sort data=work.sic_from_comp nodupkey;
    by permno;
run;


/* Merge patch into sdc_crsp and re-assign ff30 */
proc sort data=work.sdc_crsp;      by permno; run;
proc sort data=work.sic_from_comp; by permno; run;

data work.sdc_crsp;
    merge work.sdc_crsp (in=a)
          work.sic_from_comp (keep=permno siccd_comp);
    by permno;
    if a;

    /* Patch siccd */
    if (siccd = 9999 or missing(siccd)) and not missing(siccd_comp) then
        siccd = siccd_comp;

    /* Re-assign ff30 using patched siccd */
    if missing(ff30) then do;
        %assign_ff30;
    end;

    drop siccd_comp datadate;
run;

/* Verify patch results */
proc means data=work.sdc_crsp n nmiss;
    var ff30 siccd;
    title "After SIC patch: ff30 and siccd coverage";
run;


proc datasets lib=work nolist; delete sic_missing sic_from_comp; quit;

/*===========================================================================
  STEP 6: 15-DAY MARKET RETURN
===========================================================================*/

proc sort data=work.sdc_crsp (keep=idate) nodupkey out=work.ipo_dates;
    by idate;
run;

proc sql;
    create table work.mkt_window as
    select a.idate, b.date, b.logewretd
    from work.ipo_dates as a
    inner join work.crsp_index_daily as b
    on b.date < a.idate
    order by a.idate, b.date desc;
quit;

data work.mkt_window;
    set work.mkt_window;
    by idate;
    n + 1;
    if first.idate then n = 1;
run;

data work.mkt_window;
    set work.mkt_window;
    if n le 15;
run;

proc sql;
    create table work.mktret_15day as
    select idate,
           exp(sum(logewretd)) - 1 as lagcummktret
               label="15-day compounded EW market return"
    from work.mkt_window
    group by idate
    having count(*) = 15;
quit;

proc datasets lib=work nolist; delete mkt_window ipo_dates; quit;

/*===========================================================================
  STEP 7: DOWNLOAD TO LOCAL
===========================================================================*/

proc download data=work.sdc_crsp
              out=master.sdc_crsp;
run;

proc download data=work.crsp_monthly
              out=master.crsp_monthly;
run;

proc download data=work.crsp_index_daily
              out=master.crsp_index_daily;
run;

proc download data=work.mktret_15day
              out=master.mktret_15day;
run;

proc download data=work.compustat_be
              out=master.compustat_be;
run;

endrsubmit;

signoff;

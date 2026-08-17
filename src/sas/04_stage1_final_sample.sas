/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
04_stage1_final_sample.sas

Stage:
Stage 1 - Sample Construction

Purpose:
Merge external IPO characteristics, sentiment measures, deflated
proceeds, and underwriter information with the SDC-CRSP-underwriter
sample to construct the final IPO analysis universe.

Inputs:
- master.sdc_crsp_uw
- master.crsp_monthly
- raw.ipo_age_clean.csv
- raw.UMCSENT.csv
- raw.sentiment_clean.csv

Outputs:
- master.analysis_universe
- master.sample_attrition

Key variables:
- Firm age
- Internet dummy
- Investor sentiment
- Inflation-adjusted proceeds
- Exchange indicators
- Main sample flag

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";


/* 1. Import external files */

/* 1.1 Jay Ritter IPO age and internet dummy */
proc import
    datafile = "&raw\ipo_age_clean.csv"
    dbms     = csv
    out      = raw.ipo_age
    replace;
    getnames = yes;
    guessingrows = 1000;
run;

/* 1.2 Michigan Consumer Sentiment Index */
proc import
    datafile = "&raw\UMCSENT.csv"
    dbms     = csv
    out      = raw.umcsent_raw
    replace;
    getnames = yes;
run;

/* 1.3 Baker-Wurgler sentiment */
data raw.sentiment_raw;
    infile "&raw\sentiment_clean.csv" delimiter=',' DSD MISSOVER firstobs=2;

    informat yearmo 6.
             SENT best32.
             SENT_ORTH best32.
             pdnd best32.
             ripo best32.
             nipo best32.
             cefd best32.
             s best32.
             indpro best32.
             consdur best32.
             consnon best32.
             consserv best32.
             recess best32.
             employ best32.
             cpi best32.;

    format yearmo 6.
           SENT best12.
           SENT_ORTH best12.;

    input yearmo SENT SENT_ORTH pdnd ripo nipo cefd s
          indpro consdur consnon consserv recess employ cpi;
run;


/* 2. Clean external files */

/* 2.1 Ritter IPO age file */
data raw.ipo_age2;
    set raw.ipo_age;

    rename
        IPO_name    = ipo_name
        CRSP_Perm   = permno_ritter
        ADR__2_ADR_ = adr_flag
    ;
run;

data raw.ipo_age2;
    set raw.ipo_age2;

    /* Ritter file uses mixed CUSIP formats.
       9-digit: issuer(6) + issue(2) + check digit -> first 8 digits.
       8-digit: already CUSIP8.
       6-digit: base issuer code only -> append '10'.
       7-digit: rare edge case -> append '0'. */
    cusip_len = length(strip(CUSIP));

    if      cusip_len = 9 then cusip8_ritter = substr(strip(CUSIP), 1, 8);
    else if cusip_len = 8 then cusip8_ritter = strip(CUSIP);
    else if cusip_len = 6 then cusip8_ritter = cat(strip(CUSIP), '10');
    else if cusip_len = 7 then cusip8_ritter = cat(strip(CUSIP), '0');
    else                       cusip8_ritter = "";

    drop cusip_len;

    /* 6-digit base CUSIP for matching */
    if length(strip(cusip8_ritter)) >= 6 then
        cusip6_ritter = substr(strip(cusip8_ritter), 1, 6);
    else
        cusip6_ritter = "";

    idate_ritter = input(put(offer_date, 8.), yymmdd8.);
    format idate_ritter yymmddn8.;

    ipo_year = year(idate_ritter);

    if Founding > 0 and ipo_year > . then
        age_ritter = ipo_year - Founding;
    else age_ritter = .;

    if Internet = 1 then internet = 1;
    else if Internet = . then internet = .;
    else internet = 0;

    if adr_flag = 2 then adr = 1;
    else adr = 0;

    keep cusip8_ritter cusip6_ritter idate_ritter permno_ritter ipo_name
         Founding ipo_year age_ritter internet VC adr;
run;

data raw.ipo_age2;
    set raw.ipo_age2;
    if adr = 1 then delete;
    drop adr;
run;

proc sort data=raw.ipo_age2;
    by cusip6_ritter idate_ritter;
run;


/* 2.2 Michigan Consumer Sentiment Index */
data raw.umcsent2;
    set raw.umcsent_raw;

    yearmonth = mdy(month(observation_date), 1, year(observation_date));
    format yearmonth yymmn6.;

    rename UMCSENT = mcsi;
    drop observation_date;
run;

proc sort data=raw.umcsent2;
    by yearmonth;
run;

data raw.umcsent2;
    set raw.umcsent2;

    retain _mcsi;
    if mcsi ne . then _mcsi = mcsi;
    else mcsi = _mcsi;

    drop _mcsi;
run;

data raw.umcsent2;
    set raw.umcsent2;
    lagmcsi = lag(mcsi);
run;


/* 2.3 Baker-Wurgler sentiment */
data raw.sentiment2;
    set raw.sentiment_raw;

    yr = int(yearmo / 100);
    mo = mod(yearmo, 100);

    yearmonth = mdy(mo, 1, yr);
    format yearmonth yymmn6.;

    drop yr mo;
    keep yearmonth yearmo SENT SENT_ORTH;
run;

proc sort data=raw.sentiment2;
    by yearmonth;
run;


/* 3. Construct inflation-adjusted proceeds */

/* Method:
   Following the original IPO_reg_new.sas approach, proceeds are deflated
   using CRSP total market capitalisation relative to the 1975 base year.
*/

data work.crsp_mktcap;
    set master.crsp_monthly;

    year = year(yearmonth);
    if missing(mktcap) then delete;

    keep permno year mktcap;
run;

proc sql;
    create table work.mktcap_year as
    select year,
           sum(mktcap) as mktcap_year
    from work.crsp_mktcap
    where not missing(mktcap)
    group by year
    order by year;
quit;

proc sql noprint;
    select mktcap_year into :mktcap_1975 trimmed
    from work.mktcap_year
    where year = 1975;
quit;

data work.mktcap_year;
    set work.mktcap_year;

    if mktcap_year > 0 then
        index1975 = &mktcap_1975 / mktcap_year;
    else index1975 = .;
run;

data work.mktcap_year;
    set work.mktcap_year;

    lag_index1975 = lag(index1975);
    if year = 1975 then lag_index1975 = 1;
run;


/* 4. Prepare SDC-CRSP-underwriter base dataset */

data work.sdc_crsp;
    set master.sdc_crsp_uw;

    drop date_diff;

    if oprc <= 0 then do;
        oprc = .;
        r0   = .;
    end;

    ipo_year  = year(idate);
    ipo_month = month(idate);
    yearmonth = mdy(ipo_month, 1, ipo_year);
    format yearmonth yymmn6.;

    if length(strip(cusip_new)) >= 6 then
        cusip6 = substr(strip(cusip_new), 1, 6);
    else
        cusip6 = "";
run;

proc sort data=work.sdc_crsp;
    by ipo_year;
run;

proc sort data=work.mktcap_year;
    by year;
run;

proc sql;
    create table work.sdc_crsp2 as
    select a.*,
           b.lag_index1975
    from work.sdc_crsp as a
    left join work.mktcap_year as b
    on a.ipo_year = b.year;
quit;

data work.sdc_crsp2;
    set work.sdc_crsp2;

    if proceeds_mil > 0 and lag_index1975 > . then do;
        proceeds_adj1975   = proceeds_mil * lag_index1975;
        lnproceeds_adj1975 = log(proceeds_adj1975);
    end;
    else do;
        proceeds_adj1975   = .;
        lnproceeds_adj1975 = .;
    end;

    label
        proceeds_adj1975   = "Proceeds deflated to 1975 prices (USD millions)"
        lnproceeds_adj1975 = "Log proceeds in 1975 prices"
    ;

    drop lag_index1975;
run;


/* 5. Merge Ritter founding date and internet dummy */

/* Match on 6-digit base CUSIP and keep the closest Ritter IPO date
   for each CRSP PERMNO. This handles suffix differences between SDC
   and Ritter CUSIP records while avoiding fan-out duplicates. */

proc sql;
    create table work.merged1_candidate as
    select a.*,
           b.age_ritter,
           b.internet as internet_ritter,
           b.Founding,
           b.ipo_name,
           abs(a.idate - b.idate_ritter) as date_diff
    from work.sdc_crsp2 as a
    left join raw.ipo_age2 as b
    on a.cusip6 = b.cusip6_ritter;
quit;

data work.merged1_candidate;
    set work.merged1_candidate;

    if missing(date_diff) then date_diff_sort = 99999;
    else date_diff_sort = date_diff;
run;

proc sort data=work.merged1_candidate;
    by permno date_diff_sort;
run;

proc sort data=work.merged1_candidate nodupkey;
    by permno;
run;

data work.merged1;
    set work.merged1_candidate;
    drop date_diff date_diff_sort cusip6;
run;


/* 6. Merge Michigan Consumer Sentiment */

proc sort data=work.merged1;
    by yearmonth;
run;

proc sort data=raw.umcsent2;
    by yearmonth;
run;

data work.merged2;
    merge work.merged1 (in=a)
          raw.umcsent2 (keep=yearmonth lagmcsi
                        rename=(lagmcsi=lagmcsi_merge));
    by yearmonth;

    if a;

    lagmcsi = lagmcsi_merge;
    drop lagmcsi_merge;
run;


/* 7. Merge Baker-Wurgler sentiment */

proc sort data=work.merged2;
    by yearmonth;
run;

proc sort data=raw.sentiment2;
    by yearmonth;
run;

data work.merged3;
    merge work.merged2 (in=a)
          raw.sentiment2 (keep=yearmonth SENT SENT_ORTH);
    by yearmonth;

    if a;
run;


/* 8. Construct final analysis universe */

data master.analysis_universe;
    set work.merged3;

    /* Exchange dummies based on SDC exchange strings */
    if exchange in ('Nasdaq', 'Sm Cap Mkt', 'OTC')
        then NASDAQ = 1;
    else NASDAQ = 0;

    if exchange in ('New York Stock Exchange')
        then NYSE = 1;
    else NYSE = 0;

    if exchange in ('American', 'NYSE Amex', 'NYSE MKT', 'NYSE Arca')
        then AMEX = 1;
    else AMEX = 0;

    internet = internet_ritter;

    if age_ritter > 0 then lnage = log(age_ritter);
    else lnage = .;

    /* Universe-defining filters */
    if ff30 = 30          then delete;
    if missing(ff30)      then delete;
    if year(idate) < 1975 then delete;

    /* Baseline estimation sample flag.
       This flags the main exchange/non-SPAC sample without deleting rows. */
    if (NASDAQ = 1 or NYSE = 1 or AMEX = 1)
       and upcase(strip(spac_flag)) ne "TRUE"
        then main_sample_flag = 1;
    else main_sample_flag = 0;

    label
        age_ritter         = "Firm age at IPO (years)"
        lnage              = "Log firm age at IPO"
        internet           = "Internet company dummy"
        lagmcsi            = "Lagged MCSI (t-1)"
        SENT               = "Baker-Wurgler sentiment index"
        SENT_ORTH          = "Baker-Wurgler orthogonalized sentiment"
        TT                 = "Top-tier underwriter dummy (rank >= 8)"
        lnproceeds_adj1975 = "Log proceeds deflated to 1975 prices"
        lnproceeds         = "Log proceeds"
        NASDAQ             = "NASDAQ listing dummy (incl. OTC, Sm Cap Mkt)"
        NYSE               = "NYSE listing dummy"
        AMEX               = "AMEX listing dummy"
        main_sample_flag   = "Main estimation sample flag"
    ;
run;


/* 9. Sample attrition table */

proc sql;
    create table master.sample_attrition as
    select step, n
        from master.attrition_stage1

    union all

    select "CRSP matched" as step length=50,
           count(*) as n
        from master.sdc_crsp

    union all

    select "Underwriter information merged",
           count(*)
        from master.sdc_crsp_uw

    union all

    select "Analysis universe (FF30 1-29, year>=1975)",
           count(*)
        from master.analysis_universe

    union all

    select "Main estimation sample (exchange + non-SPAC)",
           count(*)
        from master.analysis_universe
        where main_sample_flag = 1

    union all

    select "Exchange-listed sample before SPAC exclusion",
           count(*)
        from master.analysis_universe
        where NASDAQ = 1 or NYSE = 1 or AMEX = 1
    ;
quit;

proc print data=master.sample_attrition noobs;
    title "Sample Attrition from SDC Raw to Main Estimation Sample";
run;

/********************************************************************
Program: WRDS_Recovered61.sas (bridge step 'recovery')
Purpose: Daily returns (R1/R2 horizons) and industry coskewness for IPOs
         recovered by the filing-link rule (role 'recovered61'), plus a
         validation recomputation for already-constructed IPOs (role
         'baseline_validation').

Inputs:  &ext.\recovery\recovery_targets.csv, written by
         workflow/bridge/recovery/make_recovery_targets.py:
         permno, idate, oprc, r0, ff30, role, and for validation rows the
         stored values old_coskewness, old_r2_bhar_1y ... old_r3_bhar_5y.
         The label 'recovered61' names the role in the paper's run; the
         number of recovered IPOs depends on the sample.
WRDS:    crsp.dsf, dsedelist, msenames, dsi; ff.factors_daily. Runs in the
         session opened by %wrds_signon (local copy or WRDS server).
Calculations follow Stages 05 and 06. Coskewness uses the full
@SKEW_START_DATE@-@DATA_END_DATE@ stock-month universe for its cutoffs.

Local outputs: <run_root>\ext\recovered61-wrds\run_<unique tag>\
Server staging: recovered61_<unique tag> under the remote SAS WORK.
********************************************************************/

/* 1. School configuration and local output folder */
%let syscc=0;
%include "%sysget(IPO_CONFIG)";
%global school_out;
%let school_out=;
%let school_tag=%sysfunc(datetime(),hex16.);

data _null_;
    length parent folder $1024;
    parent=cats(symget('ext'),'\recovered61-wrds');
    if not fileexist(parent) then
        folder=dcreate('recovered61-wrds',strip(symget('ext')));
    folder=dcreate("run_&school_tag.",parent);
    call symputx('school_out',folder,'G');
run;

%macro school_checkpoint(label);
    %if &syscc > 4 %then %do;
        proc printto; run;
        %put ERROR: School run stopped at &label.. Inspect client_run.log and run.log.;
        %abort cancel;
    %end;
%mend;

%macro school_folder_check;
    %if %length(%superq(school_out))=0 %then %do;
        %put ERROR: Cannot create local output under &ext.\recovered61-wrds.;
        %abort cancel;
    %end;
%mend;
%school_folder_check;
libname rec61 "&school_out.";
filename recvdir "&school_out.";
%school_checkpoint(local_folder);
%put NOTE: LOCAL OUTPUT FOLDER = &school_out.;
proc printto log="&school_out.\client_run.log" new; run;

/* 2. Recovery targets written by the workflow, then WRDS sign-on */
data work.recovery_targets_all;
    infile "&ext.\recovery\recovery_targets.csv" dsd firstobs=2 truncover;
    length role $24;
    informat idate yymmdd10.;
    format idate yymmdd10.;
    input permno idate oprc r0 ff30 role $
          old_coskewness old_r2_bhar_1y old_r2_bhar_3y old_r2_bhar_5y
          old_r3_bhar_1y old_r3_bhar_3y old_r3_bhar_5y;
run;
%school_checkpoint(read_targets);
%wrds_signon;
%school_checkpoint(signon);

/* 3. Original calculation and validation code executes on WRDS */
rsubmit;
proc upload data=work.recovery_targets_all out=work.recovery_targets_all; run;

options compress=binary mprint;
%let syscc=0;
/* Use SAS-managed scratch; HOME may be unavailable or non-writable. */
%let audit_parent=%sysfunc(pathname(work));
%let audit_tag=%sysfunc(datetime(),hex16.);
%global audit_out;
%let audit_out=;
data _null_;
 length folder parent detail $1024;
 parent=symget('audit_parent');
 folder=dcreate("recovered61_&audit_tag.",parent);
 if missing(folder) then do;
  detail=sysmsg();
  put 'ERROR: Cannot create staging folder under remote SAS WORK.';
  put parent= detail=;
 end;
 call symputx('audit_out',folder,'G');
run;
%macro require_folder;
 %if %length(%superq(audit_out))=0 %then %do;
  %put ERROR: Cannot create output folder under SAS WORK. See parent/detail above.;
  %abort cancel;
 %end;
%mend;
%require_folder;
%put NOTE: DOWNLOAD FOLDER = &audit_out.;
proc printto log="&audit_out./run.log" new;run;
libname audit "&audit_out.";
%macro checkpoint(label);
 %if &syscc > 4 %then %do;
  proc printto;run;
  %put ERROR: Stopped at &label.. Download run.log from &audit_out.;
  %abort cancel;
 %end;
%mend;
%macro check_source(ds);
 %if not %sysfunc(exist(&ds)) and not %sysfunc(exist(&ds,VIEW)) %then %do;
  proc printto;run;
  %put ERROR: Required dataset &ds unavailable. Check WRDS subscription/library.;
  %abort cancel;
 %end;
%mend;
%check_source(crsp.dsf);
%check_source(crsp.dsedelist);
%check_source(crsp.msenames);
%check_source(crsp.dsi);
%check_source(ff.factors_daily);
%checkpoint(library_preflight);

/* PART 1: RETURNS */
options compress=binary;
data work.recovery_targets;
 set work.recovery_targets_all;
 keep permno idate oprc r0 ff30;
run;
data work.ipo_list_slim; set work.recovery_targets;keep permno idate oprc r0;run;
proc sort data=work.ipo_list_slim;
    by permno idate;
run;

data work.ipo_list;
    set work.ipo_list_slim;
    by permno;
    if first.permno;

    keep permno idate oprc r0;
run;

proc sql noprint;
    select min(idate) format=8.,
           max(idate) format=8.
    into :min_idate trimmed,
         :max_idate trimmed
    from work.ipo_list;
quit;

proc sql;
    create table work.crsp_daily_raw as
    select a.permno,
           a.date,
           a.ret
    from crsp.dsf as a
    inner join work.ipo_list as b
    on a.permno = b.permno
    where a.date between &min_idate and (&max_idate + 1826)
    order by a.permno, a.date;
quit;

proc sql;
    create table work.crsp_delist as
    select a.permno,
           a.dlstdt as date,
           a.dlret
    from crsp.dsedelist as a
    inner join work.ipo_list as b
    on a.permno = b.permno
    where a.dlstdt between &min_idate and (&max_idate + 1826)
    order by a.permno, date;
quit;

proc sql;
    create table work.crsp_ipo_daily as
    select coalesce(a.permno, b.permno) as permno,
           coalesce(a.date, b.date)     as date,
           a.ret,
           b.dlret
    from work.crsp_daily_raw as a
    full join work.crsp_delist as b
    on  a.permno = b.permno
    and a.date   = b.date
    order by permno, date;
quit;


/* 3. Construct delisting-adjusted event-time returns */

proc sort data=work.crsp_ipo_daily;
    by permno date;
run;

proc sort data=work.ipo_list;
    by permno;
run;

data work.d6;
    merge work.crsp_ipo_daily (in=a)
          work.ipo_list       (in=b keep=permno idate oprc r0);
    by permno;

    if a and b;
    if date >= idate;

    diff = date - idate;
run;

proc sort data=work.d6;
    by permno date;
run;

data work.d6;
    set work.d6;
    by permno;

    n + 1;
    if first.permno then n = 1;
run;

data work.d6;
    set work.d6;

    /* Replace the first missing CRSP return with the IPO first-day return. */
    if n = 1 and missing(ret) then ret = r0;

    ret_adj = ret;

    /* Incorporate CRSP delisting returns. */
    if not missing(dlret) then do;
        if not missing(ret) then
            ret_adj = (1 + ret) * (1 + dlret) - 1;
        else
            ret_adj = dlret;
    end;
run;


/* 4. Construct R1: return from IPO closing price */

/* R1 starts from n=2, excluding the first-day return. */
data work.d6_r2;
    set work.d6;

    if  2 <= n <=  22 then emonth = 1;
    if 23 <= n <=  43 then emonth = 2;
    if 44 <= n <=  64 then emonth = 3;
    if 65 <= n <=  85 then emonth = 4;
    if 86 <= n <= 106 then emonth = 5;
    if 107 <= n <= 127 then emonth = 6;
    if 128 <= n <= 148 then emonth = 7;
    if 149 <= n <= 169 then emonth = 8;
    if 170 <= n <= 190 then emonth = 9;
    if 191 <= n <= 211 then emonth = 10;
    if 212 <= n <= 232 then emonth = 11;
    if 233 <= n <= 253 then emonth = 12;
    if 254 <= n <= 274 then emonth = 13;
    if 275 <= n <= 295 then emonth = 14;
    if 296 <= n <= 316 then emonth = 15;
    if 317 <= n <= 337 then emonth = 16;
    if 338 <= n <= 358 then emonth = 17;
    if 359 <= n <= 379 then emonth = 18;
    if 380 <= n <= 400 then emonth = 19;
    if 401 <= n <= 421 then emonth = 20;
    if 422 <= n <= 442 then emonth = 21;
    if 443 <= n <= 463 then emonth = 22;
    if 464 <= n <= 484 then emonth = 23;
    if 485 <= n <= 505 then emonth = 24;
    if 506 <= n <= 526 then emonth = 25;
    if 527 <= n <= 547 then emonth = 26;
    if 548 <= n <= 568 then emonth = 27;
    if 569 <= n <= 589 then emonth = 28;
    if 590 <= n <= 610 then emonth = 29;
    if 611 <= n <= 631 then emonth = 30;
    if 632 <= n <= 652 then emonth = 31;
    if 653 <= n <= 673 then emonth = 32;
    if 674 <= n <= 694 then emonth = 33;
    if 695 <= n <= 715 then emonth = 34;
    if 716 <= n <= 736 then emonth = 35;
    if 737 <= n <= 757 then emonth = 36;
    if 758 <= n <= 778 then emonth = 37;
    if 779 <= n <= 799 then emonth = 38;
    if 800 <= n <= 820 then emonth = 39;
    if 821 <= n <= 841 then emonth = 40;
    if 842 <= n <= 862 then emonth = 41;
    if 863 <= n <= 883 then emonth = 42;
    if 884 <= n <= 904 then emonth = 43;
    if 905 <= n <= 925 then emonth = 44;
    if 926 <= n <= 946 then emonth = 45;
    if 947 <= n <= 967 then emonth = 46;
    if 968 <= n <= 988 then emonth = 47;
    if 989 <= n <= 1009 then emonth = 48;
    if 1010 <= n <= 1030 then emonth = 49;
    if 1031 <= n <= 1051 then emonth = 50;
    if 1052 <= n <= 1072 then emonth = 51;
    if 1073 <= n <= 1093 then emonth = 52;
    if 1094 <= n <= 1114 then emonth = 53;
    if 1115 <= n <= 1135 then emonth = 54;
    if 1136 <= n <= 1156 then emonth = 55;
    if 1157 <= n <= 1177 then emonth = 56;
    if 1178 <= n <= 1198 then emonth = 57;
    if 1199 <= n <= 1219 then emonth = 58;
    if 1220 <= n <= 1240 then emonth = 59;
    if 1241 <= n <= 1261 then emonth = 60;
run;

/* R1: 1-year */
data work.c;
    set work.d6_r2;
    if emonth <= 12;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r2_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_1y,
           sum(ret_adj) as car_1y
    from work.c
    group by permno;
quit;

proc sort data=work.r2_return;
    by permno;
run;

data work.r2_1y;
    set work.r2_return;
    by permno;
    if first.permno;

    keep permno idate bhar_1y car_1y;
    rename bhar_1y = r2_bhar_1y
           car_1y  = r2_car_1y;
run;

/* R1: 3-year */
data work.c;
    set work.d6_r2;
    if emonth <= 36;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r2_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_3y,
           sum(ret_adj) as car_3y
    from work.c
    group by permno;
quit;

proc sort data=work.r2_return;
    by permno;
run;

data work.r2_3y;
    set work.r2_return;
    by permno;
    if first.permno;

    keep permno idate bhar_3y car_3y;
    rename bhar_3y = r2_bhar_3y
           car_3y  = r2_car_3y;
run;

/* R1: 5-year */
data work.c;
    set work.d6_r2;
    if emonth <= 60;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r2_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_5y,
           sum(ret_adj) as car_5y
    from work.c
    group by permno;
quit;

proc sort data=work.r2_return;
    by permno;
run;

data work.r2_5y;
    set work.r2_return;
    by permno;
    if first.permno;

    keep permno idate bhar_5y car_5y;
    rename bhar_5y = r2_bhar_5y
           car_5y  = r2_car_5y;
run;

proc sql;
    create table work.r2_all as
    select a.permno,
           a.idate,
           a.r2_bhar_1y,
           a.r2_car_1y,
           b.r2_bhar_3y,
           b.r2_car_3y,
           c.r2_bhar_5y,
           c.r2_car_5y
    from work.r2_1y as a
    left join work.r2_3y as b
    on  a.permno = b.permno
    and a.idate  = b.idate
    left join work.r2_5y as c
    on  a.permno = c.permno
    and a.idate  = c.idate;
quit;


/* 5. Construct R2: return from IPO offer price */

/* R2 starts from n=1, including the first-day return. */
data work.d6_r3;
    set work.d6;

    if  1 <= n <=  21 then emonth = 1;
    if 22 <= n <=  42 then emonth = 2;
    if 43 <= n <=  63 then emonth = 3;
    if 64 <= n <=  84 then emonth = 4;
    if 85 <= n <= 105 then emonth = 5;
    if 106 <= n <= 126 then emonth = 6;
    if 127 <= n <= 147 then emonth = 7;
    if 148 <= n <= 168 then emonth = 8;
    if 169 <= n <= 189 then emonth = 9;
    if 190 <= n <= 210 then emonth = 10;
    if 211 <= n <= 231 then emonth = 11;
    if 232 <= n <= 252 then emonth = 12;
    if 253 <= n <= 273 then emonth = 13;
    if 274 <= n <= 294 then emonth = 14;
    if 295 <= n <= 315 then emonth = 15;
    if 316 <= n <= 336 then emonth = 16;
    if 337 <= n <= 357 then emonth = 17;
    if 358 <= n <= 378 then emonth = 18;
    if 379 <= n <= 399 then emonth = 19;
    if 400 <= n <= 420 then emonth = 20;
    if 421 <= n <= 441 then emonth = 21;
    if 442 <= n <= 462 then emonth = 22;
    if 463 <= n <= 483 then emonth = 23;
    if 484 <= n <= 504 then emonth = 24;
    if 505 <= n <= 525 then emonth = 25;
    if 526 <= n <= 546 then emonth = 26;
    if 547 <= n <= 567 then emonth = 27;
    if 568 <= n <= 588 then emonth = 28;
    if 589 <= n <= 609 then emonth = 29;
    if 610 <= n <= 630 then emonth = 30;
    if 631 <= n <= 651 then emonth = 31;
    if 652 <= n <= 672 then emonth = 32;
    if 673 <= n <= 693 then emonth = 33;
    if 694 <= n <= 714 then emonth = 34;
    if 715 <= n <= 735 then emonth = 35;
    if 736 <= n <= 756 then emonth = 36;
    if 757 <= n <= 777 then emonth = 37;
    if 778 <= n <= 798 then emonth = 38;
    if 799 <= n <= 819 then emonth = 39;
    if 820 <= n <= 840 then emonth = 40;
    if 841 <= n <= 861 then emonth = 41;
    if 862 <= n <= 882 then emonth = 42;
    if 883 <= n <= 903 then emonth = 43;
    if 904 <= n <= 924 then emonth = 44;
    if 925 <= n <= 945 then emonth = 45;
    if 946 <= n <= 966 then emonth = 46;
    if 967 <= n <= 987 then emonth = 47;
    if 988 <= n <= 1008 then emonth = 48;
    if 1009 <= n <= 1029 then emonth = 49;
    if 1030 <= n <= 1050 then emonth = 50;
    if 1051 <= n <= 1071 then emonth = 51;
    if 1072 <= n <= 1092 then emonth = 52;
    if 1093 <= n <= 1113 then emonth = 53;
    if 1114 <= n <= 1134 then emonth = 54;
    if 1135 <= n <= 1155 then emonth = 55;
    if 1156 <= n <= 1176 then emonth = 56;
    if 1177 <= n <= 1197 then emonth = 57;
    if 1198 <= n <= 1218 then emonth = 58;
    if 1219 <= n <= 1239 then emonth = 59;
    if 1240 <= n <= 1260 then emonth = 60;
run;

/* R2: 1-year */
data work.c;
    set work.d6_r3;
    if emonth <= 12;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r3_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_1y,
           sum(ret_adj) as car_1y
    from work.c
    group by permno;
quit;

proc sort data=work.r3_return;
    by permno;
run;

data work.r3_1y;
    set work.r3_return;
    by permno;
    if first.permno;

    keep permno idate bhar_1y car_1y;
    rename bhar_1y = r3_bhar_1y
           car_1y  = r3_car_1y;
run;

/* R2: 3-year */
data work.c;
    set work.d6_r3;
    if emonth <= 36;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r3_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_3y,
           sum(ret_adj) as car_3y
    from work.c
    group by permno;
quit;

proc sort data=work.r3_return;
    by permno;
run;

data work.r3_3y;
    set work.r3_return;
    by permno;
    if first.permno;

    keep permno idate bhar_3y car_3y;
    rename bhar_3y = r3_bhar_3y
           car_3y  = r3_car_3y;
run;

/* R2: 5-year */
data work.c;
    set work.d6_r3;
    if emonth <= 60;
    if missing(emonth) then delete;
    if missing(ret_adj) then delete;
run;

proc sql;
    create table work.r3_return as
    select permno,
           idate,
           exp(sum(log(1 + ret_adj))) - 1 as bhar_5y,
           sum(ret_adj) as car_5y
    from work.c
    group by permno;
quit;

proc sort data=work.r3_return;
    by permno;
run;

data work.r3_5y;
    set work.r3_return;
    by permno;
    if first.permno;

    keep permno idate bhar_5y car_5y;
    rename bhar_5y = r3_bhar_5y
           car_5y  = r3_car_5y;
run;

proc sql;
    create table work.r3_all as
    select a.permno,
           a.idate,
           a.r3_bhar_1y,
           a.r3_car_1y,
           b.r3_bhar_3y,
           b.r3_car_3y,
           c.r3_bhar_5y,
           c.r3_car_5y
    from work.r3_1y as a
    left join work.r3_3y as b
    on  a.permno = b.permno
    and a.idate  = b.idate
    left join work.r3_5y as c
    on  a.permno = c.permno
    and a.idate  = c.idate;
quit;


/* 6. Combine return measures */

proc sort data=work.r2_all;
    by permno idate;
run;

proc sort data=work.r3_all;
    by permno idate;
run;

proc sql;
    create table work.bhar as
    select a.*,
           b.r3_bhar_1y,
           b.r3_car_1y,
           b.r3_bhar_3y,
           b.r3_car_3y,
           b.r3_bhar_5y,
           b.r3_car_5y
    from work.r2_all as a
    left join work.r3_all as b
    on  a.permno = b.permno
    and a.idate  = b.idate;
quit;


proc export data=work.bhar outfile="&audit_out./ipo_returns.csv" dbms=csv replace;run;
proc export data=work.crsp_ipo_daily outfile="&audit_out./crsp_ipo_daily.csv" dbms=csv replace;run;
proc sql;create table work.return_coverage as select permno,count(*) as rows,min(date) as first_date format=yymmdd10.,max(date) as last_date format=yymmdd10.,sum(not missing(ret)) as n_ret,sum(not missing(dlret)) as n_dlret from work.crsp_ipo_daily group by permno;quit;
proc export data=work.return_coverage outfile="&audit_out./return_coverage.csv" dbms=csv replace;run;

data audit.targets;
 set work.recovery_targets_all;
 keep permno idate oprc r0 ff30 role;
run;
proc export data=audit.targets outfile="&audit_out./targets.csv" dbms=csv replace;run;

%checkpoint(return_stage);
/* PART 2: COSKEWNESS */
options compress=binary;
data work.recovery_targets;
 set work.recovery_targets_all;
 keep permno idate oprc r0 ff30;
run;
data work.list;set work.recovery_targets;permno_ipo=permno;ff30_ipo=ff30;start_date=intnx('month',idate,-3,'beginning');end_date=intnx('month',idate,-1,'beginning');keep permno_ipo ff30_ipo start_date end_date;run;
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
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;
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
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;

    if missing(vwretd) then delete;
run;

data work.ff_rf;
    set ff.factors_daily
        (keep = date rf);
    where date between '@SKEW_START_DATE@'d and '@DATA_END_DATE@'d;

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



proc export data=work.cosk_ipo outfile="&audit_out./ipo_coskewness.csv" dbms=csv replace;run;
proc export data=work._cosk_pctl outfile="&audit_out./coskewness_global_cutoffs.csv" dbms=csv replace;run;
proc sql;create table work.cosk_monthly_summary as select ff30,yearmonth,sum(coskew_pm) as sum_cosk,count(coskew_pm) as n_cosk from work.est_ff30 group by ff30,yearmonth;quit;
proc export data=work.cosk_monthly_summary outfile="&audit_out./coskewness_monthly_sums.csv" dbms=csv replace;run;

%checkpoint(calculations);
data work.baseline_expected;
 set work.recovery_targets_all(where=(role='baseline_validation'));
 keep permno old_coskewness old_r2_bhar_1y old_r2_bhar_3y old_r2_bhar_5y old_r3_bhar_1y old_r3_bhar_3y old_r3_bhar_5y;
run;

proc export data=work.baseline_expected outfile="&audit_out./baseline_expected.csv" dbms=csv replace;run;
proc sql;
 create table audit.complete_results as
 select t.*, b.r2_bhar_1y,b.r2_bhar_3y,b.r2_bhar_5y,
 b.r3_bhar_1y,b.r3_bhar_3y,b.r3_bhar_5y,c.coskewness,c.n_cosk
 from audit.targets t
 left join work.bhar b on t.permno=b.permno and t.idate=b.idate
 left join work.cosk_ipo c on t.permno=c.permno_ipo;
 create table work.baseline_wide as
 select a.*,b.coskewness,b.r2_bhar_1y,b.r2_bhar_3y,b.r2_bhar_5y,
 b.r3_bhar_1y,b.r3_bhar_3y,b.r3_bhar_5y
 from work.baseline_expected a left join audit.complete_results b on a.permno=b.permno;
quit;
data audit.baseline_comparison;
 set work.baseline_wide;
 length variable $32;
 array oldv {*} old_coskewness old_r2_bhar_1y old_r2_bhar_3y old_r2_bhar_5y old_r3_bhar_1y old_r3_bhar_3y old_r3_bhar_5y;
 array newv {*} coskewness r2_bhar_1y r2_bhar_3y r2_bhar_5y r3_bhar_1y r3_bhar_3y r3_bhar_5y;
 do i=1 to dim(newv);
  variable=vname(newv[i]);stored=oldv[i];recalculated=newv[i];
  if missing(stored) and missing(recalculated) then passed=1;
  else if missing(stored) or missing(recalculated) then passed=0;
  else passed=(abs(stored-recalculated)<=1e-8+1e-8*abs(stored));
  output;
 end;
 keep permno variable stored recalculated passed;
run;
proc export data=audit.baseline_comparison outfile="&audit_out./baseline_comparison.csv" dbms=csv replace;run;
proc export data=audit.complete_results outfile="&audit_out./complete_results.csv" dbms=csv replace;run;
proc sql;
 create table audit.coverage as
 select role,count(*) as n_targets,
 count(coskewness) as n_coskewness,
 count(r2_bhar_1y) as n_R1_1y,count(r2_bhar_3y) as n_R1_3y,count(r2_bhar_5y) as n_R1_5y,
 count(r3_bhar_1y) as n_R2_1y,count(r3_bhar_3y) as n_R2_3y,count(r3_bhar_5y) as n_R2_5y
 from audit.complete_results group by role;
 select count(*),sum(passed) into :qa_n trimmed,:qa_pass trimmed from audit.baseline_comparison;
quit;
proc export data=audit.coverage outfile="&audit_out./coverage.csv" dbms=csv replace;run;
%checkpoint(exports);
/* Structural validation before marking the server calculation complete. */
proc sql noprint;
 select count(*),count(distinct permno),
        sum(role='recovered61'),sum(role='baseline_validation')
 into :school_rows trimmed,:school_unique trimmed,
      :school_new trimmed,:school_old trimmed
 from audit.complete_results;
 select count(*) into :school_bench_unique trimmed
 from (select distinct permno,variable from audit.baseline_comparison) as checks;
quit;
%macro school_structure_check;
 %if &school_unique ne &school_rows or %eval(&school_new + &school_old) ne &school_rows or
     &qa_n ne %eval(7 * &school_old) or &school_bench_unique ne &qa_n or
     (@PAPER_CHECKS@ = 1 and (&school_rows ne 71 or &school_new ne 61 or &school_old ne 10)) %then %do;
  proc printto; run;
  %put ERROR: Unexpected target rows or baseline comparison keys.;
  %abort cancel;
 %end;
%mend;
%school_structure_check;
%checkpoint(structure);

data _null_;
 file "&audit_out./STATUS.txt";
 put "SAS PROGRAM COMPLETED";
 put "Output folder: &audit_out.";
 put "Baseline checks: &qa_pass. / &qa_n.";
 if &qa_pass.=&qa_n. then put "BENCHMARK_PASS - inspect coverage and original data cutoff before adoption.";
 else put "REVIEW_REQUIRED - saved and current CRSP/SAS results differ; do not replace production tables.";
 run_date=date();
 put "CRSP extract date: " run_date yymmdd10.;
 put "Coskewness source window: @SKEW_START_DATE@ to @DATA_END_DATE@.";
 put "Return series observation dates: see return_coverage.csv.";
 put "Production files were not modified.";
run;
%checkpoint(status_file);
proc printto;run;
title "Recovered61 execution completed - download output files";
proc print data=audit.coverage noobs;run;
proc print data=audit.baseline_comparison noobs;where passed=0;run;
title;
%put NOTE: REMOTE CALCULATIONS COMPLETED. SERVER FOLDER = &audit_out.;
%put NOTE: BASELINE CHECKS = &qa_pass. / &qa_n.;


/* 4. Download only target data and summaries, not the global stock panel.
   REC61 and RECVDIR refer to the Windows libraries/fileref set above.
   SAS datasets use native PROC DOWNLOAD conversion across platforms. */
proc download data=audit.targets out=rec61.targets; run;
%checkpoint(download_targets);
proc download data=audit.complete_results out=rec61.complete_results; run;
%checkpoint(download_complete_results);
proc download data=audit.baseline_comparison out=rec61.baseline_comparison; run;
%checkpoint(download_baseline_comparison);
proc download data=audit.coverage out=rec61.coverage; run;
%checkpoint(download_coverage);
proc download data=work.bhar out=rec61.ipo_returns; run;
%checkpoint(download_returns);
proc download data=work.crsp_ipo_daily out=rec61.crsp_ipo_daily; run;
%checkpoint(download_daily);
proc download data=work.return_coverage out=rec61.return_coverage; run;
%checkpoint(download_return_coverage);
proc download data=work.cosk_ipo out=rec61.ipo_coskewness; run;
%checkpoint(download_coskewness);
proc download data=work._cosk_pctl out=rec61.coskewness_global_cutoffs; run;
%checkpoint(download_cutoffs);
proc download data=work.cosk_monthly_summary out=rec61.coskewness_monthly_sums; run;
%checkpoint(download_monthly_sums);
proc download data=work.baseline_expected out=rec61.baseline_expected; run;
%checkpoint(download_expected);

/* Exact copies of CSVs, server log, and server status.
   The original remote PRINTTO was closed above, so run.log is flushed. */
filename senddir "&audit_out.";
proc download infile=senddir('*.csv') outfile=recvdir binary; run;
%checkpoint(download_csv);
proc download infile=senddir('*.txt') outfile=recvdir binary; run;
%checkpoint(download_status);
proc download infile=senddir('*.log') outfile=recvdir binary; run;
%checkpoint(download_log);

/* Download the completion marker LAST, only after all transfers succeed. */
data work.school_transfer_status;
    length server_folder $1024;
    server_folder="&audit_out.";
    completed=1;
    baseline_checks=&qa_n.;
    baseline_passed=&qa_pass.;
    target_rows=&school_rows.;
    extracted_at=datetime();
    format extracted_at datetime20.;
run;
proc download data=work.school_transfer_status out=rec61.transfer_status; run;
%checkpoint(download_marker);
endrsubmit;

/* 5. Verify local receipt before reporting completion */
%school_checkpoint(remote_execution_and_transfer);
%macro school_receipt_check;
    %local i member fname members files;
    %let members=targets complete_results baseline_comparison coverage
        ipo_returns crsp_ipo_daily return_coverage ipo_coskewness
        coskewness_global_cutoffs coskewness_monthly_sums baseline_expected
        transfer_status;
    %do i=1 %to %sysfunc(countw(&members));
        %let member=%scan(&members,&i);
        %if not %sysfunc(exist(rec61.&member)) %then %do;
            proc printto; run;
            %put ERROR: Missing local dataset rec61.&member.. Download is incomplete.;
            %abort cancel;
        %end;
    %end;
    %let files=targets.csv complete_results.csv baseline_comparison.csv
        coverage.csv ipo_returns.csv crsp_ipo_daily.csv return_coverage.csv
        ipo_coskewness.csv coskewness_global_cutoffs.csv
        coskewness_monthly_sums.csv baseline_expected.csv STATUS.txt run.log;
    %do i=1 %to %sysfunc(countw(&files,%str( )));
        %let fname=%scan(&files,&i,%str( ));
        %if not %sysfunc(fileexist(&school_out.\&fname)) %then %do;
            proc printto; run;
            %put ERROR: Missing local file &fname.. Download is incomplete.;
            %abort cancel;
        %end;
    %end;
%mend;
%school_receipt_check;

proc sql noprint;
 select count(*),count(distinct permno) into
     :school_local_n trimmed,:school_local_unique trimmed
 from rec61.complete_results;
 select count(*),sum(passed) into
     :school_local_checks trimmed,:school_local_pass trimmed
 from rec61.baseline_comparison;
 select count(*) into :school_local_marker trimmed
 from rec61.transfer_status
 where completed=1 and target_rows=71 and baseline_checks=70;
quit;
%school_checkpoint(local_counts);
%macro school_final_check;
 %if &school_local_n ne 71 or &school_local_unique ne 71 or
     &school_local_checks ne 70 or &school_local_marker ne 1 %then %do;
    proc printto; run;
    %put ERROR: Local target/comparison/marker counts are invalid.;
    %abort cancel;
 %end;
%mend;
%school_final_check;

data _null_;
    file "&school_out.\LOCAL_STATUS.txt";
    put "SCHOOL_DOWNLOAD_COMPLETED";
    put "Local folder: &school_out.";
    put "Targets: &school_local_n. (61 recovered + 10 benchmark)";
    put "Baseline checks: &school_local_pass. / &school_local_checks.";
    if &school_local_pass.=70 then
        put "BENCHMARK_PASS - review coverage and observation dates before adoption.";
    else
        put "REVIEW_REQUIRED - inspect baseline_comparison.csv; do not adopt yet.";
    put "See run.log (server) and client_run.log (connection/download).";
run;
%school_checkpoint(local_status);
signoff;
proc printto; run;

title "Recovered61: school download completed";
proc print data=rec61.coverage noobs; run;
proc print data=rec61.baseline_comparison noobs; where passed=0; run;
title;
%put NOTE: SCHOOL_DOWNLOAD_COMPLETED;
%put NOTE: LOCAL OUTPUT FOLDER = &school_out.;
%put NOTE: BASELINE CHECKS = &school_local_pass. / &school_local_checks.;

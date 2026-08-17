/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
06_stage2_ipo_returns.sas

Stage:
Stage 2 - Variable Construction

Purpose:
Construct IPO aftermarket return measures using CRSP daily returns
and merge return variables into the final analysis dataset.

Inputs:
- master.analysis_skew
- master.mktret_15day
- WRDS CRSP daily returns
- WRDS CRSP delisting returns

Outputs:
- master.bhar
- master.analysis_full

Key variables:
- r2_bhar_3y: R1, buy-and-hold return from IPO closing price
- r3_bhar_3y: R2, buy-and-hold return from IPO offer price
- lagcummktret: pre-IPO market return

Notes:
Return calculations follow the original IPO replication methodology
using available CRSP return windows. Delisting returns are incorporated
to reduce survivorship bias.

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";

%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;


/* 1. Prepare IPO list */

data work.ipo_list_slim;
    set master.analysis_skew;
    keep permno idate oprc r0;
run;


/* 2. Retrieve CRSP daily returns and delisting returns */

rsubmit;

options compress=binary;

proc upload data=work.ipo_list_slim out=work.ipo_list_slim; run;

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

proc download data=work.bhar
              out=master.bhar;
run;

endrsubmit;

signoff;


/* 7. Merge IPO return variables with analysis dataset */

proc sort data=master.bhar;
    by permno idate;
run;

proc sort data=master.analysis_skew;
    by permno idate;
run;

proc sort data=master.mktret_15day;
    by idate;
run;

proc sql;
    create table master.analysis_full as
    select a.*,
           b.r2_bhar_1y,
           b.r2_bhar_3y,
           b.r2_bhar_5y,
           b.r2_car_1y,
           b.r2_car_3y,
           b.r2_car_5y,
           b.r3_bhar_1y,
           b.r3_bhar_3y,
           b.r3_bhar_5y,
           b.r3_car_1y,
           b.r3_car_3y,
           b.r3_car_5y,
           c.lagcummktret
    from master.analysis_skew as a
    left join master.bhar as b
    on  a.permno = b.permno
    and a.idate  = b.idate
    left join master.mktret_15day as c
    on a.idate = c.idate;
quit;


/* CHECKPOINT:
   Verify IPO return variables in the final analysis dataset.
*/

proc means data=master.analysis_full n nmiss mean median min max;
    var r0
        r2_bhar_1y r2_bhar_3y r2_bhar_5y
        r3_bhar_1y r3_bhar_3y r3_bhar_5y
        lagcummktret;
    title "Checkpoint: IPO Return Variables";
run;

title;

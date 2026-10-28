/********************************************************************
Project: IPO Lottery Demand Replication and Extension
Program: 02b_refresh_crsp_monthly_ret.sas
Purpose: Refresh raw CRSP monthly RET from WRDS and rebuild the FF30
         return and momentum controls without price-return substitution.

Security:
- Uses signon username=_prompt_.
- Credentials are entered only in the SAS/CONNECT prompt and are never
  stored in this program or a project dataset.

Inputs:
- WRDS crsp.msf (PERMNO, DATE, RET), 1970-2024
- local master.crsp_monthly (existing identifiers, names and FF30)

Outputs (new files; existing master.crsp_monthly is not overwritten):
- master.crsp_monthly_ret_refresh
- master.ff30_ret_refresh
- master.ff30_mom_refresh
- master.crsp_ret_refresh_qa
- output.crsp_ret_refresh_qa.csv
********************************************************************/

%include "%sysget(IPO_CONFIG)";

/* Interactive WRDS authentication, following the existing Stage 02. */
%wrds_signon;

rsubmit;
    options compress=binary;

    data work.crsp_msf_ret_refresh;
        set crsp.msf(keep=permno date ret);
        where date between '@LINK_START_DATE@'d and '@DATA_END_DATE@'d;
        ret_missing_raw = missing(ret);
        label
          ret = "Raw CRSP monthly RET; never price-imputed"
          ret_missing_raw = "Raw CRSP monthly RET is missing";
    run;

    proc sort data=work.crsp_msf_ret_refresh nodupkey;
        by permno date;
    run;

    /* PROC DOWNLOAD must execute inside the active RSUBMIT block.  OUT=
       identifies the local client WORK library, as in existing Stage 02. */
    proc download data=work.crsp_msf_ret_refresh
                  out=work.crsp_msf_ret_refresh;
    run;
endrsubmit;

%wrds_signoff;

/* Join raw RET to the existing local CRSP identifier/FF30 universe. */
proc sql;
    create table master.crsp_monthly_ret_refresh as
    select a.permno, a.date, a.yearmonth, a.ff30,
           a.shrcd, a.exchcd, a.siccd, a.ncUSIP,
           a.altprc, a.shrout, a.vol,
           b.ret as ret_raw,
           coalesce(b.ret_missing_raw,1) as ret_missing_raw,
           (b.permno is not null) as wrds_row_matched
    from master.crsp_monthly as a
    left join work.crsp_msf_ret_refresh as b
      on a.permno=b.permno and a.date=b.date;
quit;

/* Strict analysis universe: common stocks on NYSE/AMEX/NASDAQ. */
data work.stock_month_raw;
    set master.crsp_monthly_ret_refresh;
    where 1 <= ff30 <= 29 and shrcd in (10,11) and exchcd in (1,2,3);
run;

proc sort data=work.stock_month_raw;
    by permno yearmonth;
run;

/* Continuous-month lag. Missing RET remains missing. */
data work.stock_month_raw;
    set work.stock_month_raw;
    by permno;
    prior_ym = lag(yearmonth);
    lag_ret_raw = lag(ret_raw);
    if first.permno or intck('month',prior_ym,yearmonth) ne 1 then
        lag_ret_raw = .;
    drop prior_ym;
run;

/* EW lagged FF30 return at month t = mean raw RET at month t-1. */
proc sql;
    create table master.ff30_ret_refresh as
    select ff30, yearmonth,
           mean(lag_ret_raw) as in_ewlagmret_refresh,
           count(lag_ret_raw) as n_stocks_ret_refresh
    from work.stock_month_raw
    where not missing(lag_ret_raw)
    group by ff30, yearmonth;

    /* EW FF30 contemporaneous return used to form momentum. */
    create table work.industry_month_refresh as
    select ff30, yearmonth,
           mean(ret_raw) as in_mret_refresh,
           count(ret_raw) as n_stocks_mom_refresh
    from work.stock_month_raw
    where not missing(ret_raw)
    group by ff30, yearmonth;
quit;

/* 12-month compounded FF30 return with a 2-month skip. */
proc sql;
    create table work.momentum_signal_refresh as
    select a.ff30, a.yearmonth as form_ym,
           exp(sum(log(1+b.in_mret_refresh)))-1 as cum_return_refresh
    from work.industry_month_refresh as a
    inner join work.industry_month_refresh as b
      on a.ff30=b.ff30
     and 0 <= intck('month',b.yearmonth,a.yearmonth) < 12
    group by a.ff30, a.yearmonth
    having count(b.in_mret_refresh)=12;

    create table master.ff30_mom_refresh as
    select a.ff30, b.yearmonth,
           a.cum_return_refresh as ind_mom_refresh
    from work.momentum_signal_refresh as a
    inner join work.industry_month_refresh as b
      on a.ff30=b.ff30
     and intck('month',a.form_ym,b.yearmonth)=2;
quit;

/* Machine-readable audit record. */
proc sql;
    create table master.crsp_ret_refresh_qa as
    select "Local CRSP monthly rows" as metric length=52,
           count(*) as value
      from master.crsp_monthly_ret_refresh
    union all
    select "Rows matched to refreshed WRDS MSF",
           sum(wrds_row_matched)
      from master.crsp_monthly_ret_refresh
    union all
    select "Rows with raw RET missing",
           sum(ret_missing_raw)
      from master.crsp_monthly_ret_refresh
    union all
    select "FF30 common-stock rows",
           count(*)
      from work.stock_month_raw
    union all
    select "FF30 common-stock rows with raw RET",
           sum(not missing(ret_raw))
      from work.stock_month_raw;
quit;

proc export data=master.crsp_ret_refresh_qa
    outfile="&output.\crsp_ret_refresh_qa.csv"
    dbms=csv replace;
run;

proc print data=master.crsp_ret_refresh_qa noobs;
    title "CRSP raw RET refresh QA";
run;

proc means data=master.crsp_monthly_ret_refresh n nmiss mean std min p1 p50 p99 max;
    where wrds_row_matched=1;
    var ret_raw;
    title "Raw CRSP monthly RET distribution";
run;

proc means data=master.ff30_ret_refresh n nmiss mean std min p1 p50 p99 max;
    var in_ewlagmret_refresh;
    title "Refreshed FF30 monthly return control";
run;

proc means data=master.ff30_mom_refresh n nmiss mean std min p1 p50 p99 max;
    var ind_mom_refresh;
    title "Refreshed FF30 momentum control";
run;

title;

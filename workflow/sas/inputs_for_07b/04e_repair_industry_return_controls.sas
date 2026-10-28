/********************************************************************
Project: IPO Lottery Demand Replication and Extension
Program: 04e_repair_industry_return_controls.sas
Purpose: Local repair of FF30 return and momentum controls.

Background:
Stage 02 replaced missing CRSP mret with an unadjusted price change.
Stock splits can therefore create mechanical extreme returns.  The raw
missing-return flag is not retained locally, so this repair applies a
conventional monthly stock-return cross-sectional 1%/99% winsorization,
requires ordinary shares/exchanges, and requires a continuous calendar
month before creating a lag.  A future WRDS rebuild should instead retain
raw CRSP RET and a missing-return flag.

Outputs:
- master.ff30_ret_clean
- master.ff30_mom_clean
********************************************************************/

%include "%sysget(IPO_CONFIG)";

data work.stock_month;
    set master.crsp_monthly(keep=permno ff30 yearmonth mret shrcd exchcd);
    where 1 <= ff30 <= 29 and shrcd in (10,11) and exchcd in (1,2,3)
          and not missing(mret) and mret >= -1;
run;

proc sort data=work.stock_month;
    by yearmonth;
run;

proc univariate data=work.stock_month noprint;
    by yearmonth;
    var mret;
    output out=work.monthly_bounds pctlpts=1 99 pctlpre=p_;
run;

data work.stock_month_clean;
    merge work.stock_month(in=a) work.monthly_bounds(keep=yearmonth p_1 p_99);
    by yearmonth;
    if a;
    mret_clean = min(max(mret,p_1),p_99);
run;

/* Continuous-month lagged EW return. */
proc sort data=work.stock_month_clean;
    by permno yearmonth;
run;

data work.stock_month_clean;
    set work.stock_month_clean;
    by permno;
    prior_ym = lag(yearmonth);
    lagmret_clean = lag(mret_clean);
    if first.permno or intck('month',prior_ym,yearmonth) ne 1 then
        lagmret_clean = .;
    drop prior_ym;
run;

proc sql;
    create table master.ff30_ret_clean as
    select ff30, yearmonth,
           mean(lagmret_clean) as in_ewlagmret_clean,
           count(lagmret_clean) as n_stocks_ret_clean
    from work.stock_month_clean
    where not missing(lagmret_clean)
    group by ff30, yearmonth;

    create table work.industry_month_clean as
    select ff30, yearmonth,
           mean(mret_clean) as in_mret_clean
    from work.stock_month_clean
    where not missing(mret_clean)
    group by ff30, yearmonth;
quit;

/* 12-month compounded EW industry return, assigned after a 2-month skip. */
proc sql;
    create table work.momentum_signal as
    select a.ff30, a.yearmonth as form_ym,
           exp(sum(log(1+b.in_mret_clean)))-1 as cum_return_clean
    from work.industry_month_clean as a
    inner join work.industry_month_clean as b
      on a.ff30=b.ff30
     and 0 <= intck('month',b.yearmonth,a.yearmonth) < 12
    group by a.ff30, a.yearmonth
    having count(b.in_mret_clean)=12;

    create table master.ff30_mom_clean as
    select a.ff30, b.yearmonth, a.cum_return_clean as ind_mom_clean
    from work.momentum_signal as a
    inner join work.industry_month_clean as b
      on a.ff30=b.ff30
     and intck('month',a.form_ym,b.yearmonth)=2;
quit;

proc means data=master.ff30_ret_clean n nmiss mean std min p1 p50 p99 max;
    var in_ewlagmret_clean;
    title "Repaired FF30 monthly return control";
run;

proc means data=master.ff30_mom_clean n nmiss mean std min p1 p50 p99 max;
    var ind_mom_clean;
    title "Repaired FF30 momentum control";
run;

title;

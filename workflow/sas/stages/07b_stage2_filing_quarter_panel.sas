/********************************************************************
Project: IPO Lottery Demand Replication and Extension
Program: 07b_stage2_filing_quarter_panel.sas
Purpose: Build the Workstream 2A FF30 x filing-quarter panel.

Design:
- Complete FF30 (1-29) x quarter panel, 1975Q1-2024Q4.
- Completed IPOs are assigned by SDC filing date, not issue date.
- Filing outcomes are not treated as observed before 1983Q1 because
  the current SDC filing-date field begins in 1983.
- Actual proceeds are inflation adjusted to 1975 dollars before
  aggregation.  The amount-filed field is not used as realized capital.
- Expected skewness and existing industry controls are aggregated from
  monthly FF30 panels.  Calendar-quarter lags are generated after the
  complete panel is assembled.

Inputs:
- master.analysis_full2
- master.exp_skew_panel
- master.ff30_ret, master.ff30_mom, master.ff30_ivol,
  master.ff30_turnover, master.crsp_monthly
- master.ff30_ret_refresh, master.ff30_mom_refresh
- raw.umcsent2, raw.sentiment2

Outputs:
- master.filing_quarter_panel
- master.filing_quarter_qa
- output.filing_quarter_qa.csv
********************************************************************/

%include "%sysget(IPO_CONFIG)";

%let start_q = %sysfunc(intnx(qtr,%sysfunc(mdy(1,1,@SAMPLE_START_YEAR@)),0,b));
%let end_q   = %sysfunc(intnx(qtr,%sysfunc(mdy(10,1,@SAMPLE_END_YEAR@)),0,b));
%let observed_start_q = %sysfunc(intnx(qtr,%sysfunc(mdy(1,1,@FILING_START_YEAR@)),0,b));

/* 1. Complete panel skeleton: 29 industries x 200 quarters = 5,800. */
data work.ff30_list;
    do ff30 = 1 to 29;
        output;
    end;
run;

data work.quarter_list;
    format quarter yyq6.;
    do quarter = &start_q. to &end_q.;
        if quarter = intnx('qtr', quarter, 0, 'b') then output;
    end;
run;

proc sql;
    create table work.panel_base as
    select a.ff30, b.quarter
    from work.ff30_list as a, work.quarter_list as b
    order by a.ff30, b.quarter;
quit;

/* 2. IPO-level filing-date QA and valid filing-quarter assignments. */
data work.ipo_filing;
    set master.analysis_full2;
    where 1 <= ff30 <= 29 and @SAMPLE_START_YEAR@ <= year(idate) <= @SAMPLE_END_YEAR@;

    issue_quarter = intnx('qtr', idate, 0, 'b');
    filing_date_known = not missing(fdate);
    filing_equals_issue = (filing_date_known and fdate = idate);
    filing_after_issue = (filing_date_known and fdate > idate);
    filing_in_panel = (filing_date_known and
                       &start_q. <= intnx('qtr', fdate, 0, 'b') <= &end_q.);
    if filing_date_known then filing_quarter = intnx('qtr', fdate, 0, 'b');

    format issue_quarter filing_quarter yyq6.;
    keep deal_num permno ff30 idate fdate issue_quarter filing_quarter
         filing_date_known filing_equals_issue filing_after_issue
         filing_in_panel proceeds_mil proceeds_adj1975;
run;

proc sql;
    create table work.filing_industry as
    select ff30,
           filing_quarter as quarter format=yyq6.,
           count(*) as filings,
           sum(proceeds_adj1975) as real_proceeds,
           sum(proceeds_mil) as nominal_proceeds,
           sum(filing_equals_issue) as filings_equal_issue
    from work.ipo_filing
    where filing_in_panel = 1
    group by ff30, filing_quarter;

    create table work.filing_market as
    select filing_quarter as quarter format=yyq6.,
           count(*) as total_filings,
           sum(proceeds_adj1975) as total_real_proceeds,
           sum(proceeds_mil) as total_nominal_proceeds,
           sum(filing_equals_issue) as total_filings_equal_issue
    from work.ipo_filing
    where filing_in_panel = 1
    group by filing_quarter;

    create table work.issue_date_coverage as
    select issue_quarter as quarter format=yyq6.,
           count(*) as issue_count,
           sum(filing_date_known) as issue_count_fdate_known,
           mean(filing_date_known) as issue_fdate_known_share
    from work.ipo_filing
    group by issue_quarter;
quit;

/* 3. Quarterly expected skewness. */
data work.skew_monthly;
    set master.exp_skew_panel;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

proc sql;
    create table work.skew_quarter as
    select ff30, quarter,
           mean(skew1) as industry_skew,
           median(skew1) as industry_skew_median,
           mean(skew5) as industry_skew5,
           count(skew1) as n_months_skew
    from work.skew_monthly
    where &start_q. - 1000 <= quarter <= &end_q.
    group by ff30, quarter;
quit;

/* 4. Quarterly industry controls from existing monthly panels. */
data work.ret_monthly;
    set master.ff30_ret;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.mom_monthly;
    set master.ff30_mom;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.ivol_monthly;
    set master.ff30_ivol;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.turn_monthly;
    set master.ff30_turnover;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.ret_clean_monthly;
    set master.ff30_ret_clean;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.mom_clean_monthly;
    set master.ff30_mom_clean;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.ret_refresh_monthly;
    set master.ff30_ret_refresh;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.mom_refresh_monthly;
    set master.ff30_mom_refresh;
    where 1 <= ff30 <= 29;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

proc sql;
    create table work.industry_controls_q as
    select a.ff30, a.quarter,
           mean(a.in_ewlagmret) as industry_return,
           mean(b.ind_mom) as industry_momentum,
           mean(c.lagin_ivol) as industry_ivol,
           mean(d.in_lagturnover) as industry_turnover,
           mean(e.in_ewlagmret_clean) as industry_return_clean,
           mean(g.ind_mom_clean) as industry_momentum_clean,
           mean(h.in_ewlagmret_refresh) as industry_return_refresh,
           mean(j.ind_mom_refresh) as industry_momentum_refresh,
           count(a.in_ewlagmret) as n_months_return,
           count(b.ind_mom) as n_months_momentum,
           count(c.lagin_ivol) as n_months_ivol,
           count(d.in_lagturnover) as n_months_turnover
    from work.ret_monthly as a
    left join work.mom_monthly as b
      on a.ff30=b.ff30 and a.yearmonth=b.yearmonth
    left join work.ivol_monthly as c
      on a.ff30=c.ff30 and a.yearmonth=c.yearmonth
    left join work.turn_monthly as d
      on a.ff30=d.ff30 and a.yearmonth=d.yearmonth
    left join work.ret_clean_monthly as e
      on a.ff30=e.ff30 and a.yearmonth=e.yearmonth
    left join work.mom_clean_monthly as g
      on a.ff30=g.ff30 and a.yearmonth=g.yearmonth
    left join work.ret_refresh_monthly as h
      on a.ff30=h.ff30 and a.yearmonth=h.yearmonth
    left join work.mom_refresh_monthly as j
      on a.ff30=j.ff30 and a.yearmonth=j.yearmonth
    where &start_q. <= a.quarter <= &end_q.
    group by a.ff30, a.quarter;
quit;

/* Listed-firm count: unique CRSP common-stock permnos in each quarter. */
data work.crsp_firm_q;
    set master.crsp_monthly(keep=permno ff30 yearmonth shrcd exchcd);
    where 1 <= ff30 <= 29 and shrcd in (10,11) and exchcd in (1,2,3);
    quarter = intnx('qtr', yearmonth, 0, 'b');
    if &start_q. <= quarter <= &end_q.;
    keep permno ff30 quarter;
run;

proc sort data=work.crsp_firm_q nodupkey;
    by ff30 quarter permno;
run;

proc sql;
    create table work.firm_count_q as
    select ff30, quarter, count(*) as listed_firms
    from work.crsp_firm_q
    group by ff30, quarter;
quit;

/* 5. Quarterly market sentiment. */
data work.mcsi_monthly;
    set raw.umcsent2;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

data work.bw_monthly;
    set raw.sentiment2;
    quarter = intnx('qtr', yearmonth, 0, 'b');
    format quarter yyq6.;
run;

proc sql;
    create table work.sentiment_q as
    select a.quarter,
           mean(a.mcsi) as mcsi,
           mean(b.sent) as bw_sentiment,
           mean(b.sent_orth) as bw_sentiment_orth
    from work.mcsi_monthly as a
    left join work.bw_monthly as b
      on a.yearmonth=b.yearmonth
    where &start_q. <= a.quarter <= &end_q.
    group by a.quarter;
quit;

/* 6. Merge the complete panel and create dependent variables. */
proc sql;
    create table work.panel_merged as
    select p.*,
           coalesce(i.filings,0) as filings_raw,
           coalesce(i.real_proceeds,0) as real_proceeds_raw,
           coalesce(i.nominal_proceeds,0) as nominal_proceeds_raw,
           coalesce(i.filings_equal_issue,0) as filings_equal_issue,
           coalesce(m.total_filings,0) as total_filings_raw,
           coalesce(m.total_real_proceeds,0) as total_real_proceeds_raw,
           coalesce(m.total_nominal_proceeds,0) as total_nominal_proceeds_raw,
           coalesce(m.total_filings_equal_issue,0) as total_filings_equal_issue,
           c.issue_count, c.issue_count_fdate_known, c.issue_fdate_known_share,
           s.industry_skew, s.industry_skew_median, s.industry_skew5,
           s.n_months_skew,
           x.industry_return, x.industry_momentum, x.industry_ivol,
           x.industry_turnover, x.n_months_return, x.n_months_momentum,
           x.industry_return_clean, x.industry_momentum_clean,
           x.industry_return_refresh, x.industry_momentum_refresh,
           x.n_months_ivol, x.n_months_turnover,
           f.listed_firms,
           t.mcsi, t.bw_sentiment, t.bw_sentiment_orth
    from work.panel_base as p
    left join work.filing_industry as i
      on p.ff30=i.ff30 and p.quarter=i.quarter
    left join work.filing_market as m
      on p.quarter=m.quarter
    left join work.issue_date_coverage as c
      on p.quarter=c.quarter
    left join work.skew_quarter as s
      on p.ff30=s.ff30 and p.quarter=s.quarter
    left join work.industry_controls_q as x
      on p.ff30=x.ff30 and p.quarter=x.quarter
    left join work.firm_count_q as f
      on p.ff30=f.ff30 and p.quarter=f.quarter
    left join work.sentiment_q as t
      on p.quarter=t.quarter
    order by p.ff30, p.quarter;
quit;

data work.panel_merged;
    set work.panel_merged;
    by ff30 quarter;

    year = year(quarter);
    calendar_quarter = qtr(quarter);
    quarter_id = intck('qtr','01JAN1975'd,quarter);
    filing_coverage = (quarter >= &observed_start_q.);

    if filing_coverage then do;
        filings = filings_raw;
        real_proceeds = real_proceeds_raw;
        nominal_proceeds = nominal_proceeds_raw;
        total_filings = total_filings_raw;
        total_real_proceeds = total_real_proceeds_raw;
        total_nominal_proceeds = total_nominal_proceeds_raw;
        ln_proceeds = log(1 + real_proceeds);
        ln_total_filings = log(1 + total_filings);
        if total_real_proceeds > 0 then
            proceeds_share = real_proceeds / total_real_proceeds;
        else proceeds_share = 0;
    end;
    else call missing(filings, real_proceeds, nominal_proceeds,
                      total_filings, total_real_proceeds,
                      total_nominal_proceeds, ln_proceeds,
                      ln_total_filings, proceeds_share);

    /* Lags are valid only when the preceding row is the prior quarter. */
    prior_quarter = lag(quarter);
    l1_industry_skew = lag(industry_skew);
    l1_industry_return = lag(industry_return);
    l1_industry_momentum = lag(industry_momentum);
    l1_industry_ivol = lag(industry_ivol);
    l1_industry_turnover = lag(industry_turnover);
    l1_industry_return_clean = lag(industry_return_clean);
    l1_industry_momentum_clean = lag(industry_momentum_clean);
    l1_industry_return_refresh = lag(industry_return_refresh);
    l1_industry_momentum_refresh = lag(industry_momentum_refresh);
    l1_listed_firms = lag(listed_firms);
    l1_mcsi = lag(mcsi);
    l1_bw_sentiment = lag(bw_sentiment);
    l1_bw_sentiment_orth = lag(bw_sentiment_orth);

    if first.ff30 or intck('qtr',prior_quarter,quarter) ne 1 then
        call missing(l1_industry_skew, l1_industry_return,
                     l1_industry_momentum, l1_industry_ivol,
                     l1_industry_turnover, l1_listed_firms,
                     l1_industry_return_clean,
                     l1_industry_momentum_clean,
                     l1_industry_return_refresh,
                     l1_industry_momentum_refresh,
                     l1_mcsi, l1_bw_sentiment,
                     l1_bw_sentiment_orth);

    label
      filings = "Completed IPO filings assigned by filing quarter"
      real_proceeds = "Aggregate actual proceeds, 1975 USD millions"
      ln_proceeds = "Log(1 + aggregate real proceeds)"
      proceeds_share = "FF30 share of quarterly real IPO proceeds"
      l1_industry_skew = "Prior-quarter FF30 expected skewness"
      listed_firms = "Unique listed common-stock firms in FF30-quarter"
      filing_coverage = "Filing outcomes observed (1983Q1 onward)";

    format quarter prior_quarter yyq6.;
    drop prior_quarter;
run;

data master.filing_quarter_panel;
    set work.panel_merged;
run;

/* 7. Machine-readable QA summary. */
proc sql;
    create table master.filing_quarter_qa as
    select "Panel cells" as metric length=48, count(*) as value
      from master.filing_quarter_panel
    union all
    select "Observed-window cells", sum(filing_coverage) as value
      from master.filing_quarter_panel
    union all
    select "Observed-window zero-filing cells",
           sum(filing_coverage=1 and filings=0) as value
      from master.filing_quarter_panel
    union all
    select "Observed-window cells with L1 skew",
           sum(filing_coverage=1 and not missing(l1_industry_skew)) as value
      from master.filing_quarter_panel
    union all
    select "IPO records", count(*) as value from work.ipo_filing
    union all
    select "IPO records with filing date", sum(filing_date_known) as value
      from work.ipo_filing
    union all
    select "IPO records with filing date in panel", sum(filing_in_panel) as value
      from work.ipo_filing
    union all
    select "Filing date equals issue date", sum(filing_equals_issue) as value
      from work.ipo_filing
    union all
    select "Filing date after issue date", sum(filing_after_issue) as value
      from work.ipo_filing;
quit;

proc export data=master.filing_quarter_qa
    outfile="&output.\filing_quarter_qa.csv"
    dbms=csv replace;
run;

/* Checkpoints. */
proc print data=master.filing_quarter_qa noobs;
    title "Workstream 2A filing-quarter QA";
run;

proc means data=master.filing_quarter_panel n nmiss mean std min p50 max;
    where filing_coverage=1;
    var filings real_proceeds ln_proceeds proceeds_share
        l1_industry_skew l1_industry_return l1_industry_momentum
        l1_industry_ivol l1_industry_turnover l1_listed_firms
        l1_industry_return_clean l1_industry_momentum_clean
        l1_industry_return_refresh l1_industry_momentum_refresh
        l1_mcsi l1_bw_sentiment;
    title "Workstream 2A observed-window summary";
run;

proc sql;
    title "Quarterly aggregation identity checks";
    select quarter,
           sum(filings) as industry_filings,
           max(total_filings) as market_filings,
           sum(real_proceeds) as industry_real_proceeds,
           max(total_real_proceeds) as market_real_proceeds,
           sum(proceeds_share) as sum_share
    from master.filing_quarter_panel
    where filing_coverage=1
    group by quarter
    having abs(calculated industry_filings-calculated market_filings)>1e-8
        or abs(calculated industry_real_proceeds-calculated market_real_proceeds)>1e-8
        or (calculated market_real_proceeds>0 and
            abs(calculated sum_share-1)>1e-8);
quit;

title;

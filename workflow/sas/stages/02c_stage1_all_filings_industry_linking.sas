/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
02c_stage1_all_filings_industry_linking.sas

Stage:
Workstream 2B - filing completion and withdrawal

Purpose:
Link the all-filings sample to CRSP by the established exact CUSIP8
method, supplement missing CRSP SIC with filing-time Compustat SICH,
assign FF30 industries, and retain every filing with explicit link QA.

Inputs:
- master.filing_outcomes_prelim
- master.sdc_crsp (completed-IPO validation benchmark)
- WRDS CRSP DSF/MSENAMES
- WRDS Compustat FUNDA

Outputs:
- master.filing_outcomes_linked
- master.all_filings_link_qa
- output\sdc_all_filings_link_qa.csv
- output\sdc_all_filings_link_exceptions.csv
- output\sdc_live_industry_validation.csv

Design rules:
- Preserve Deal ID and all input rows; never deduplicate by CUSIP.
- Exact CUSIP8 only. SDC does not provide a separate numeric SIC field.
- For Live filings, only first-trade minus issue-date = 0 or 1 is a
  validated CRSP link. Other exact links remain visible but unvalidated.
- For non-Live filings, a CRSP link is auxiliary evidence only and never
  changes the SDC outcome classification.
- Compustat patch uses the latest SICH dated on/before filing date.
  The earliest post-filing SICH is retained for QA but not used in FF30.

Created:
12 August 2026
********************************************************************/

%include "%sysget(IPO_CONFIG)";
%include "&src.\sas\common\ff30_mapping.sas";

proc printto log="&output.\02c_stage1_all_filings_industry_linking.log" new;
run;

/*------------------------------------------------------------------
  1. Reproduce the established SDC CUSIP8 construction without drops
------------------------------------------------------------------*/

data work.filing_link_input;
    set master.filing_outcomes_prelim;
    length cusip_new $8;

    /* SAS does not guarantee short-circuit evaluation of AND.  Nest the
       length check so SUBSTR is never called on a short/missing CUSIP9. */
    if not missing(cusip9) then do;
        if length(strip(cusip9)) = 9 then do;
            if substr(strip(cusip9), 1, 6) = strip(cusip6) then
                cusip_new = substr(strip(cusip9), 1, 8);
        end;
    end;

    if missing(cusip_new) then do;
        _cusip_len = length(strip(cusip6));
        if      _cusip_len = 6 then cusip_new = cats(strip(cusip6), '10');
        else if _cusip_len = 8 then cusip_new = strip(cusip6);
        else if _cusip_len = 9 then cusip_new = substr(strip(cusip6), 1, 8);
        else                         cusip_new = '';
    end;

    label cusip_new = '8-digit CUSIP for exact CRSP match';
    drop _cusip_len;
run;

proc sql noprint;
    select count(*), count(distinct deal_key)
      into :input_n trimmed, :input_deals trimmed
    from work.filing_link_input;
quit;

/*------------------------------------------------------------------
  2. Connect to WRDS and retrieve exact-CUSIP CRSP candidates
------------------------------------------------------------------*/

filename ff30loc "&src.\sas\common\ff30_mapping.sas";
%wrds_signon;

rsubmit;

options compress=binary;

/* The remote SAS session cannot read C:\ directly.  Transfer the shared
   macro source to a remote TEMP fileref before compiling it on WRDS. */
filename ff30r temp;
proc upload infile=ff30loc outfile=ff30r;
run;
%include ff30r;

proc upload data=work.filing_link_input out=work.filing_link_input;
run;

proc sql;
    create table work.candidate_cusips as
    select distinct cusip_new
    from work.filing_link_input
    where not missing(cusip_new);

    create table work.candidate_names as
    select n.permno, n.namedt, n.nameendt, n.shrcd, n.exchcd,
           n.siccd, n.ncusip
    from crsp.msenames as n
    inner join work.candidate_cusips as c
      on n.ncusip = c.cusip_new
    where n.shrcd in (10, 11);

    create table work.candidate_daily as
    select d.permno, d.date, d.prc, d.ret, d.shrout,
           n.shrcd, n.exchcd, n.siccd, n.ncusip
    from crsp.dsf as d
    inner join work.candidate_names as n
      on d.permno = n.permno
     and d.date between n.namedt and n.nameendt
    where d.date between '@LINK_START_DATE@'d and '@DATA_END_DATE@'d;
quit;

proc sort data=work.candidate_daily;
    by permno ncusip date;
run;

data work.crsp_first_by_cusip;
    set work.candidate_daily;
    by permno ncusip date;
    if first.ncusip;
    crsp_first_date = date;
    absprc = abs(prc);
    keep permno ncusip crsp_first_date shrcd exchcd siccd
         absprc ret shrout;
    format crsp_first_date yymmdd10.;
run;

/* Join may yield several historical PERMNOs for one exact CUSIP.
   Rank within Deal ID so there is exactly one retained candidate. */
proc sql;
    create table work.link_candidates as
    select a.*,
           b.permno, b.ncusip, b.crsp_first_date,
           b.shrcd, b.exchcd, b.siccd as siccd_crsp,
           b.absprc, b.ret as ret_first, b.shrout
    from work.filing_link_input as a
    left join work.crsp_first_by_cusip as b
      on a.cusip_new = b.ncusip;
quit;

data work.link_candidates;
    set work.link_candidates;
    issue_date_diff = crsp_first_date - idate;
    filing_date_diff = crsp_first_date - fdate;

    if missing(permno) then do;
        _link_priority = 9;
        _link_gap = 999999;
    end;
    else if status_harmonised = 'completed_live' then do;
        if issue_date_diff in (0, 1) then _link_priority = 1;
        else _link_priority = 2;
        _link_gap = abs(issue_date_diff);
        if missing(_link_gap) then _link_gap = 999999;
    end;
    else do;
        if not missing(fdate) and crsp_first_date >= fdate then
            _link_priority = 3;
        else _link_priority = 4;
        _link_gap = abs(filing_date_diff);
        if missing(_link_gap) then _link_gap = 999999;
    end;
run;

proc sort data=work.link_candidates;
    by deal_key _link_priority _link_gap permno;
run;

proc sort data=work.link_candidates nodupkey
          out=work.link_selected;
    by deal_key;
run;

/*------------------------------------------------------------------
  3. Compustat SICH patch, keyed by CUSIP6 and dated at filing
------------------------------------------------------------------*/

data work.sic_needs_patch;
    set work.link_selected;
    if missing(siccd_crsp) or siccd_crsp in (0, 9999);
    keep deal_key cusip6 fdate;
run;

proc sql;
    create table work.comp_candidates as
    select a.deal_key, a.fdate,
           b.sich as siccd_comp, b.datadate
    from work.sic_needs_patch as a
    inner join comp.funda as b
      on strip(a.cusip6) = substr(strip(b.cusip), 1, 6)
    where b.indfmt = 'INDL'
      and b.datafmt = 'STD'
      and b.popsrc = 'D'
      and b.consol = 'C'
      and not missing(b.sich)
      and b.sich not in (0, 9999);
quit;

data work.comp_prior work.comp_post;
    set work.comp_candidates;
    if not missing(fdate) and datadate <= fdate then output work.comp_prior;
    else if not missing(fdate) and datadate > fdate then output work.comp_post;
run;

proc sort data=work.comp_prior;
    by deal_key descending datadate;
run;
proc sort data=work.comp_prior nodupkey;
    by deal_key;
run;

proc sort data=work.comp_post;
    by deal_key datadate;
run;
proc sort data=work.comp_post nodupkey;
    by deal_key;
run;

data work.comp_patch;
    merge work.comp_prior(
              rename=(siccd_comp=siccd_comp_prior
                      datadate=comp_prior_datadate))
          work.comp_post(
              rename=(siccd_comp=siccd_comp_post
                      datadate=comp_post_datadate));
    by deal_key;
    format comp_prior_datadate comp_post_datadate yymmdd10.;
run;

proc sort data=work.link_selected; by deal_key; run;
proc sort data=work.comp_patch;    by deal_key; run;

data work.filing_outcomes_linked;
    merge work.link_selected(in=a) work.comp_patch;
    by deal_key;
    if a;

    length crsp_link_route $30 sic_source $20;
    crsp_live_validated = 0;

    if missing(cusip_new) then crsp_link_route = 'no_usable_cusip';
    else if missing(permno) then crsp_link_route = 'cusip_unmatched';
    else if status_harmonised = 'completed_live' and
            issue_date_diff in (0, 1) then do;
        crsp_link_route = 'crsp_live_validated';
        crsp_live_validated = 1;
    end;
    else if status_harmonised = 'completed_live' then
        crsp_link_route = 'crsp_live_unvalidated';
    else if not missing(filing_date_diff) and filing_date_diff < 0 then
        crsp_link_route = 'crsp_exact_prefiling';
    else crsp_link_route = 'crsp_exact_postfiling';

    siccd = .;
    if not missing(siccd_crsp) and siccd_crsp not in (0, 9999) then do;
        siccd = siccd_crsp;
        sic_source = 'CRSP';
    end;
    else if not missing(siccd_comp_prior) then do;
        siccd = siccd_comp_prior;
        sic_source = 'COMPUSTAT_PRIOR';
    end;
    else sic_source = 'MISSING';

    %assign_ff30;

    label
        crsp_link_route = 'Exact-CUSIP CRSP link and timing classification'
        crsp_live_validated = 'Live exact-CUSIP link validated at issue date +0/+1'
        issue_date_diff = 'CRSP first trade date minus SDC issue date'
        filing_date_diff = 'CRSP first trade date minus SDC filing date'
        siccd_crsp = 'CRSP SIC before Compustat patch'
        siccd = 'Analysis SIC using CRSP then pre-filing Compustat'
        sic_source = 'Source of analysis SIC'
        siccd_comp_post = 'Earliest post-filing Compustat SIC, QA only'
        ff30 = 'Fama-French 30 industry from analysis SIC';

    drop _link_priority _link_gap;
run;

proc download data=work.filing_outcomes_linked
              out=master.filing_outcomes_linked;
run;

endrsubmit;
%wrds_signoff;
filename ff30loc clear;

/*------------------------------------------------------------------
  4. Local invariants and status-level QA
------------------------------------------------------------------*/

proc sort data=master.filing_outcomes_linked
          out=work.linked_deal_check nodupkey
          dupout=work.linked_deal_duplicates;
    by deal_key;
run;

proc sql;
    create table master.all_filings_link_qa as
    select status_harmonised,
           crsp_link_route,
           sic_source,
           count(*) as n,
           sum(not missing(cusip_new)) as usable_cusip_n,
           sum(not missing(permno)) as exact_crsp_n,
           sum(crsp_live_validated) as live_validated_n,
           sum(not missing(siccd)) as analysis_sic_n,
           sum(ff30 between 1 and 29) as ff30_nonutility_n,
           sum(ff30 = 30) as ff30_utility_n,
           sum(missing(ff30)) as ff30_missing_n
    from master.filing_outcomes_linked
    group by status_harmonised, crsp_link_route, sic_source
    order by status_harmonised, crsp_link_route, sic_source;

    create table work.link_exceptions as
    select deal_key, deal_num, issuer_name, status_harmonised,
           fdate, idate, cusip6, cusip9, cusip_new,
           crsp_link_route, permno, crsp_first_date,
           issue_date_diff, filing_date_diff,
           siccd_crsp, siccd_comp_prior, comp_prior_datadate,
           siccd_comp_post, comp_post_datadate,
           siccd, sic_source, ff30
    from master.filing_outcomes_linked
    where crsp_link_route in ('no_usable_cusip', 'cusip_unmatched',
                              'crsp_live_unvalidated')
       or missing(ff30);
quit;

/*------------------------------------------------------------------
  5. Validate Live links against the original completed-IPO link file
------------------------------------------------------------------*/

data work.existing_crsp_keys;
    set master.sdc_crsp(keep=deal_num permno siccd ff30 cusip_new idate);
    length deal_key $32;
    deal_key = strip(vvalue(deal_num));
    rename permno=old_permno siccd=old_siccd ff30=old_ff30
           cusip_new=old_cusip8 idate=old_idate;
run;

proc sort data=work.existing_crsp_keys nodupkey;
    by deal_key;
run;

proc sql;
    create table work.live_industry_validation as
    select a.deal_key, a.deal_num, a.issuer_name,
           a.cusip_new, a.idate, a.permno,
           a.siccd_crsp, a.siccd_comp_prior, a.comp_prior_datadate,
           a.siccd, a.sic_source, a.ff30,
           a.crsp_link_route, a.crsp_live_validated, a.issue_date_diff,
           b.old_cusip8, b.old_idate, b.old_permno, b.old_siccd, b.old_ff30,
           (not missing(b.deal_key)) as found_in_old_link,
           case when not missing(b.deal_key)
                     and not missing(a.permno) and not missing(b.old_permno)
                then (a.permno = b.old_permno) else . end as permno_agrees,
           case when not missing(b.deal_key)
                     and not missing(a.ff30) and not missing(b.old_ff30)
                then (a.ff30 = b.old_ff30) else . end as ff30_agrees
    from master.filing_outcomes_linked as a
    left join work.existing_crsp_keys as b
      on a.deal_key = b.deal_key
    where a.status_harmonised = 'completed_live';
quit;

proc export data=master.all_filings_link_qa
    outfile="&output.\sdc_all_filings_link_qa.csv"
    dbms=csv replace;
run;

proc export data=work.link_exceptions
    outfile="&output.\sdc_all_filings_link_exceptions.csv"
    dbms=csv replace;
run;

proc export data=work.live_industry_validation
    outfile="&output.\sdc_live_industry_validation.csv"
    dbms=csv replace;
run;

title 'All-filings CRSP and industry link QA';
proc print data=master.all_filings_link_qa noobs;
run;

title 'All-filings link invariants';
proc sql;
    select &input_n as input_n,
           count(*) as output_n,
           count(distinct deal_key) as output_deals,
           (select count(*) from work.linked_deal_duplicates)
               as duplicate_deal_rows
    from master.filing_outcomes_linked;

    select count(*) as live_n,
           sum(case when crsp_live_validated = 1 then 1 else 0 end)
               as live_validated_n,
           sum(case when found_in_old_link = 1 then 1 else 0 end)
               as found_in_old_link_n,
           sum(case when found_in_old_link = 1 and permno_agrees = 1
                    then 1 else 0 end) as permno_agrees_n,
           sum(case when found_in_old_link = 1 and ff30_agrees = 1
                    then 1 else 0 end) as ff30_agrees_n
    from work.live_industry_validation;
quit;

title;
proc printto;
run;

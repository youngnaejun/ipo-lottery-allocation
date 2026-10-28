/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
01b_stage1_sdc_all_filings_cleaning.sas

Stage:
Workstream 2B - Filing completion and withdrawal

Purpose:
Import the SDC all-filings extract, harmonise transaction outcomes,
apply the established U.S./common-equity/USD restrictions without a
CUSIP requirement, construct 18-month outcome/censoring variables, and
compare completed observations with the existing completed-IPO sample.

Input:
- raw\@SDC_ALL_FILINGS_FILE@ (SDC_ALL_FILINGS_FILE in the workflow configuration)

Outputs:
- master.sdc_all_filings
- master.filing_outcomes_prelim
- master.attrition_all_filings
- output\sdc_all_filings_attrition.csv
- output\sdc_all_filings_status.csv
- output\sdc_all_filings_missingness.csv
- output\sdc_completed_match_summary.csv
- output\sdc_completed_match_detail.csv

Important:
- Do not require CUSIP. Cancelled/postponed registrations frequently
  lack a usable security identifier.
- SDC Issue Date is populated for pipeline observations and is not, by
  itself, evidence that an IPO was completed. Transaction Status is the
  outcome source of truth.

Created:
12 August 2026
********************************************************************/

%include "%sysget(IPO_CONFIG)";

options validvarname=v7;

%let all_filings_xlsx = &raw.\@SDC_ALL_FILINGS_FILE@;
%let extraction_date  = '@SDC_EXTRACTION_DATE@'d;
%let filing_end_date  = '31DEC@SAMPLE_END_YEAR@'d;
%let resolution_months = 18;

/* Persist the complete run log so warnings and errors can be audited
   without relying on the interactive SAS log window. */
proc printto log="&output.\01b_stage1_sdc_all_filings_cleaning.log" new;
run;

/*------------------------------------------------------------------
  1. Import the final SDC pipeline-inclusive extract
------------------------------------------------------------------*/

proc import
    datafile = "&all_filings_xlsx."
    dbms     = xlsx
    out      = work.sdc_all_raw
    replace;
    /* SDC writes two title rows above the true variable header, so the import
       range starts at row 3 (header) and runs to the last worksheet row; SAS
       stops at the last record. Columns A-AQ hold the 43 exported fields
       (docs/data_acquisition.md). For the paper's export this reads the same
       26,168 records as the original fixed range A3:AQ26171. */
    sheet    = "@SDC_ALL_FILINGS_SHEET@";
    range    = "A3:AQ1048576";
    getnames = yes;
run;

/* Standardise source names. Names follow SAS V7 conversion used by the
   existing Stage 1 import. */
data work.sdc_all_standard;
    set work.sdc_all_raw;

    rename
        Dates__Filing_Date               = _fdate_raw
        Dates__Issue_Date                = _idate_raw
        Listing_Date                     = _ldate_raw
        Date_of_Lockup_Expiration        = _lockup_exp_date_raw
        Issuer_Borrower_Name_Full        = issuer_name
        Issuer_Borrower_State            = issuer_state
        Issuer_Borrower_Nation           = nation
        Issuer_Borrower_Ticker_Symbol    = ticker
        Issuer_Borrower_6_digit_CUSIP    = cusip6
        Issuer_Borrower_9_digit_CUSIP    = cusip9
        SDC_Deal_Number                  = deal_num
        IPO_Flag                         = ipo_flag
        Original_IPO_Flag                = original_ipo_flag
        Security_Type_This_Market        = security_type
        Primary_Exchange_Listing_Of_Issu = exchange
        Tranche_Currency                 = currency
        Offer_Price__USD_                = oprc
        VAR19                            = file_price_low
        VAR20                            = file_price_high
        Amended_Low_File_Price__USD_     = amended_low
        Amended_High_File_Price__USD_    = amended_high
        Proceeds_Amount_This_Market__USD = proceeds_mil
        Primary_Shares_Offered_This_Mark = primary_shares
        Secondary_Shares_Offered_This_Ma = secondary_shares
        Full_History_Amount_Filed_This_M = _initial_amount_mil_raw
        Venture_Capital_Backed_IPO_Issue = venture_backed
        New_Issues_Fees__Gross_Spread_as = gross_spread_pct
        All_New_Issues_Manager_Roles     = manager_roles
        Number_of_Shares_Subject_to_Lock = lockup_shares
        Over_Subscription_Flag           = oversubscription_flag
        Not_Underwritten_Issue_Flag      = not_underwritten
        Lead_Managers                    = lead_managers_raw
        Lead_Managers_Code               = lead_manager_codes_raw
        Blank_Check__SPAC__Involvement_Y = spac_flag
        Issuer_Borrower_Public_Status    = issuer_public_status
        Transaction_Status               = transaction_status
        Financials__Shares_Outstanding_A = shares_out_after_offer
        Shares_Outstanding_After_Offer_f = shares_out_after_offer_prosp
        Lockup__Lockup_Shares_as_Percent = lockup_pct
        Postponed_Date                   = _withdrawn_postponed_date_raw
        Additional_Comments              = additional_comments
        Date_Deal_was_Last_Updated       = _deal_last_updated_raw
    ;
run;

/*------------------------------------------------------------------
  2. Harmonise statuses and construct outcome/censoring variables
------------------------------------------------------------------*/

data master.sdc_all_filings;
    set work.sdc_all_standard;

    length status_harmonised $22 deal_key $32;

    /* PROC IMPORT can expose Excel dates as character or numeric values,
       depending on the column's mixed/missing cells. VVALUE plus ANYDTDTE
       provides one reproducible conversion path for either source type. */
    /* SDC's Excel export renders dates as MM/DD/YYYY. An explicit informat
       avoids locale-dependent day/month reversal for ambiguous dates. */
    fdate = input(strip(vvalue(_fdate_raw)), ?? mmddyy10.);
    idate = input(strip(vvalue(_idate_raw)), ?? mmddyy10.);
    ldate = input(strip(vvalue(_ldate_raw)), ?? mmddyy10.);
    lockup_exp_date = input(strip(vvalue(_lockup_exp_date_raw)), ?? mmddyy10.);
    withdrawn_postponed_date =
        input(strip(vvalue(_withdrawn_postponed_date_raw)), ?? mmddyy10.);
    deal_last_updated =
        input(strip(vvalue(_deal_last_updated_raw)), ?? mmddyy10.);
    /* Full-history amount may contain semicolon-delimited revision history.
       The first token is the amount stated at the original full-history filing. */
    initial_amount_mil = input(
        compress(scan(strip(vvalue(_initial_amount_mil_raw)), 1, ';', 'm'), ','),
        ?? best32.);

    format fdate idate ldate lockup_exp_date withdrawn_postponed_date
           deal_last_updated resolution_date resolution_due_date
           extraction_date filing_end_date yymmdd10.;

    extraction_date = &extraction_date.;
    filing_end_date = &filing_end_date.;
    resolution_due_date = intnx('month', fdate, &resolution_months., 'same');
    deal_key = strip(vvalue(deal_num));

    select (upcase(compress(strip(transaction_status), ' _-')));
        when ('LIVE')       status_harmonised = 'completed_live';
        when ('CANCELLED')  status_harmonised = 'withdrawn_cancelled';
        when ('POSTPONED')  status_harmonised = 'postponed';
        when ('INPROGRESS', 'ANNOUNCED', 'MANDATED', 'RUMOURED')
                           status_harmonised = 'open_pipeline';
        when ('UNKNOWN')    status_harmonised = 'status_unknown';
        otherwise           status_harmonised = 'other_unmapped';
    end;

    completed_live      = (status_harmonised = 'completed_live');
    withdrawn_cancelled = (status_harmonised = 'withdrawn_cancelled');
    postponed           = (status_harmonised = 'postponed');
    open_pipeline       = (status_harmonised = 'open_pipeline');
    status_unknown      = (status_harmonised = 'status_unknown');
    resolved_status     = (status_harmonised in
                          ('completed_live', 'withdrawn_cancelled', 'postponed'));

    /* Main binary status outcome: retain only currently resolved filings. */
    if status_harmonised = 'completed_live' then completed = 1;
    else if status_harmonised in ('withdrawn_cancelled', 'postponed') then completed = 0;
    else completed = .;

    /* Resolution date is status-specific. Issue Date is used only after
       Transaction Status establishes that the filing is Live. */
    if status_harmonised = 'completed_live' then resolution_date = idate;
    else if status_harmonised in ('withdrawn_cancelled', 'postponed') then
        resolution_date = withdrawn_postponed_date;
    else resolution_date = .;

    if not missing(fdate) and not missing(resolution_date) then
        resolution_days = resolution_date - fdate;
    else resolution_days = .;

    /* 18-month completion outcome.
       1: completed within 18 months.
       0: not completed by 18 months, including cancellation/postponement
          or an unresolved filing whose full 18-month window has elapsed.
       .: insufficient follow-up at extraction date. */
    if missing(fdate) then completed_by_18m = .;
    else if status_harmonised = 'completed_live'
            and not missing(idate)
            and 0 <= (idate - fdate) <= (resolution_due_date - fdate)
        then completed_by_18m = 1;
    else if extraction_date >= resolution_due_date then completed_by_18m = 0;
    else if status_harmonised in ('withdrawn_cancelled', 'postponed')
            and not missing(resolution_date)
            and resolution_date <= resolution_due_date
        then completed_by_18m = 0;
    else completed_by_18m = .;

    right_censored_18m = (not missing(fdate)
                           and extraction_date < resolution_due_date
                           and completed_by_18m = .);

    /* Competing-risk event coding for later survival analysis. */
    if status_harmonised = 'completed_live' then resolution_event = 1;
    else if status_harmonised = 'withdrawn_cancelled' then resolution_event = 2;
    else if status_harmonised = 'postponed' then resolution_event = 3;
    else resolution_event = 0;

    label
        status_harmonised   = 'Harmonised SDC transaction status'
        completed           = 'Current resolved outcome: 1=Live, 0=Cancelled/Postponed'
        completed_by_18m    = 'IPO completed within 18 months of filing'
        right_censored_18m  = 'Insufficient 18-month follow-up as of extraction'
        resolution_event    = '0=open/unknown, 1=Live, 2=Cancelled, 3=Postponed'
        resolution_date     = 'Status-specific resolution date'
        resolution_days     = 'Days from filing to status-specific resolution'
        resolution_due_date = 'Filing date plus 18 months'
        deal_key            = 'Character SDC Deal Number match key'
        initial_amount_mil  = 'Domestic amount filed at full-history filing (USD millions)'
    ;

    drop _fdate_raw _idate_raw _ldate_raw _lockup_exp_date_raw
         _withdrawn_postponed_date_raw _deal_last_updated_raw
         _initial_amount_mil_raw;
run;

/* Check the raw extract invariants before applying downstream filters. */
proc sort data=master.sdc_all_filings out=work.sdc_deal_check nodupkey
          dupout=work.sdc_deal_duplicates;
    by deal_key;
run;

/*------------------------------------------------------------------
  3. Apply established sample restrictions, deliberately without CUSIP
------------------------------------------------------------------*/

data work.all_f1;
    set master.sdc_all_filings;
    if upcase(strip(original_ipo_flag)) = 'TRUE';
run;

data work.all_f2;
    set work.all_f1;
    if nation = 'United States';
run;

data work.all_f3;
    set work.all_f2;
    if security_type in (
        'Common Stock',
        'Class A Common Shares',
        'Class B Common Shares',
        'Class C Common Stock',
        'Class D Common Stock',
        'Ordinary Or Common Shares',
        'Ordinary Shares',
        'Class A Ordinary Shares',
        'Class B Ordinary Shares',
        'Non Voting Shares',
        'Non Voting Class A Shares',
        'Non Voting Class B Shares',
        'Subordinate Voting Shares',
        'Class A Subordinate Voting Shares',
        'Class B Subordinate Voting Shares'
    );
run;

data master.filing_outcomes_prelim;
    set work.all_f3;
    if currency = 'US Dollar';
run;

/*------------------------------------------------------------------
  4. Attrition and status QA
------------------------------------------------------------------*/

proc sql;
    create table master.attrition_all_filings as
    select 1 as step, 'Raw pipeline-inclusive extract' as criterion length=80,
           count(*) as n from master.sdc_all_filings
    union all
    select 2, 'Original IPO Flag=True', count(*) from work.all_f1
    union all
    select 3, 'Issuer nation=United States', count(*) from work.all_f2
    union all
    select 4, 'Existing common-equity security allowlist', count(*) from work.all_f3
    union all
    select 5, 'Tranche currency=US Dollar; no CUSIP requirement', count(*)
           from master.filing_outcomes_prelim;
quit;

data master.attrition_all_filings;
    set master.attrition_all_filings;
    previous_n = lag(n);
    if step = 1 then dropped = .;
    else dropped = previous_n - n;
    drop previous_n;
run;

proc freq data=master.sdc_all_filings noprint;
    tables transaction_status * status_harmonised / out=work.status_all;
run;

proc freq data=master.filing_outcomes_prelim noprint;
    tables transaction_status * status_harmonised / out=work.status_target;
run;

data work.status_qa;
    length sample $20;
    set work.status_all(in=a) work.status_target(in=b);
    if a then sample = 'All Original IPOs';
    else if b then sample = 'US-USD common equity';
run;

/* Status-specific variable availability. Missingness is recorded rather
   than used as a selection filter. */
proc sql;
    create table work.missingness_qa as
    select status_harmonised,
           count(*) as n,
           sum(missing(cusip6)) as miss_cusip6,
           sum(missing(file_price_low) or missing(file_price_high)) as miss_initial_range,
           sum(missing(proceeds_mil)) as miss_proceeds,
           sum(missing(primary_shares)) as miss_primary_shares,
           sum(missing(lead_managers_raw)) as miss_lead_manager,
           sum(missing(venture_backed)) as miss_vc_flag,
           sum(missing(withdrawn_postponed_date)) as miss_withdrawn_postponed_date,
           sum(missing(deal_last_updated)) as miss_last_updated,
           sum(missing(additional_comments)) as miss_comments
    from master.filing_outcomes_prelim
    group by status_harmonised
    order by status_harmonised;
quit;

/*------------------------------------------------------------------
  5. Compare Live observations with the existing completed-IPO sample
------------------------------------------------------------------*/

data work.existing_completed_keys;
    set master.analysis_full(keep=deal_num issuer_name fdate idate cusip_new);
    length deal_key $32;
    deal_key = strip(vvalue(deal_num));
    existing_completed = 1;
    rename issuer_name = existing_issuer_name
           fdate       = existing_fdate
           idate       = existing_idate;
run;

proc sort data=work.existing_completed_keys nodupkey;
    by deal_key;
run;

proc sql;
    create table work.completed_match_detail as
    select a.deal_key,
           a.deal_num,
           a.issuer_name,
           a.fdate,
           a.idate,
           a.cusip6,
           a.cusip9,
           a.transaction_status,
           a.status_harmonised,
           (not missing(b.deal_key)) as matched_existing,
           b.cusip_new as existing_cusip8,
           b.existing_issuer_name,
           b.existing_fdate,
           b.existing_idate
    from master.filing_outcomes_prelim as a
    left join work.existing_completed_keys as b
      on a.deal_key = b.deal_key
    where a.status_harmonised = 'completed_live';

    create table work.completed_match_summary as
    select count(*) as live_target_n,
           sum(matched_existing) as matched_existing_n,
           sum(not matched_existing) as unmatched_existing_n,
           calculated matched_existing_n / calculated live_target_n
                as target_match_rate format=percent8.2
    from work.completed_match_detail;

    create table work.existing_coverage_summary as
    select count(*) as existing_analysis_n,
           sum(not missing(a.deal_key)) as found_in_all_filings_n,
           calculated found_in_all_filings_n / calculated existing_analysis_n
                as existing_coverage_rate format=percent8.2
    from work.existing_completed_keys as b
    left join master.sdc_all_filings as a
      on a.deal_key = b.deal_key;
quit;

data work.completed_match_summary;
    merge work.completed_match_summary work.existing_coverage_summary;
run;

/*------------------------------------------------------------------
  6. Persist compact QA files
------------------------------------------------------------------*/

proc export data=master.attrition_all_filings
    outfile="&output.\sdc_all_filings_attrition.csv"
    dbms=csv replace;
run;

proc export data=work.status_qa
    outfile="&output.\sdc_all_filings_status.csv"
    dbms=csv replace;
run;

proc export data=work.missingness_qa
    outfile="&output.\sdc_all_filings_missingness.csv"
    dbms=csv replace;
run;

proc export data=work.completed_match_summary
    outfile="&output.\sdc_completed_match_summary.csv"
    dbms=csv replace;
run;

proc export data=work.completed_match_detail
    outfile="&output.\sdc_completed_match_detail.csv"
    dbms=csv replace;
run;

/*------------------------------------------------------------------
  7. Execution checks printed to the SAS output/log
------------------------------------------------------------------*/

title 'Workstream 2B all-filings attrition';
proc print data=master.attrition_all_filings noobs;
run;

title 'Workstream 2B harmonised status frequencies';
proc print data=work.status_qa noobs;
run;

title 'Workstream 2B status-specific missingness';
proc print data=work.missingness_qa noobs;
run;

title 'Existing completed-IPO match summary';
proc print data=work.completed_match_summary noobs;
run;

title 'Invariant checks';
proc sql;
    select count(*) as raw_n from master.sdc_all_filings;
    select count(*) as target_n from master.filing_outcomes_prelim;
    select count(*) as duplicate_deal_rows from work.sdc_deal_duplicates;
    select sum(right_censored_18m) as right_censored_18m,
           sum(completed_by_18m=1) as completed_by_18m,
           sum(completed_by_18m=0) as not_completed_by_18m,
           sum(missing(completed_by_18m)) as missing_18m_outcome
    from master.filing_outcomes_prelim;
quit;

title;

proc printto;
run;

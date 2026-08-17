/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
01_stage1_sdc_cleaning.sas

Stage:
Stage 1 - Sample Construction

Purpose:
Import the SDC/LSEG IPO spreadsheet, standardise source variable names,
apply initial IPO eligibility filters, and create the cleaned SDC base
sample for downstream CRSP linking and variable construction.

Inputs:
RAW:
- &raw\IPO project.xlsx

Outputs:
MASTER:
- master.sdc_clean
- master.attrition_stage1

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";

/* 1. Import SDC/LSEG IPO spreadsheet */
proc import
    datafile = "&raw/IPO project.xlsx"
    dbms     = xlsx
    out      = raw.sdc_raw
	replace;
    getnames = yes;
run;

/* 2. Rename SDC variables to standard project variable names */
data raw.sdc_raw2;
    set raw.sdc_raw;

    rename

    /* Dates */
    Dates__Filing_Date              = fdate
    Dates__Issue_Date               = idate
    Listing_Date                    = ldate
    Date_of_Lockup_Expiration       = lockup_exp_date


    /* Issuer identifiers */
    Issuer_Borrower_Name_Full       = issuer_name
    Issuer_Borrower_State           = issuer_state
    Issuer_Borrower_Nation          = nation
    Issuer_Borrower_Ticker_Symbol   = ticker
    Issuer_Borrower_6_digit_CUSIP   = cusip6
    Issuer_Borrower_9_digit_CUSIP   = cusip9
    SDC_Deal_Number                 = deal_num


    /* IPO identifiers and filters */
    IPO_Flag                        = ipo_flag
    Original_IPO_Flag               = original_ipo_flag
    Security_Type_This_Market       = security_type
    Primary_Exchange_Listing_Of_Issu= exchange
    Tranche_Currency                = currency
    Blank_Check__SPAC__Involvement_Y= spac_flag
    Issuer_Borrower_Public_Status   = issuer_public_status
    Transaction_Status              = transaction_status


    /* Offer characteristics */
    Offer_Price__USD_               = oprc
    VAR19                           = file_price_low
    VAR20                           = file_price_high
    Amended_Low_File_Price__USD_    = amended_low
    Amended_High_File_Price__USD_   = amended_high
    Proceeds_Amount_This_Market__USD= proceeds_mil


    /* Shares */
    Primary_Shares_Offered_This_Mark   = primary_shares
    Secondary_Shares_Offered_This_Ma   = secondary_shares

    Financials__Shares_Outstanding_A   = shares_out_after_offer
    Shares_Outstanding_After_Offer_f   = shares_out_after_offer_prosp


    /* IPO characteristics */
    Venture_Capital_Backed_IPO_Issue = venture_backed
    New_Issues_Fees__Gross_Spread_as = gross_spread_pct
    Over_Subscription_Flag           = oversubscription_flag
    Not_Underwritten_Issue_Flag      = not_underwritten


    /* Underwriter information */
    Lead_Managers                    = lead_managers_raw
    Lead_Managers_Code               = lead_manager_codes_raw
    All_New_Issues_Manager_Roles     = manager_roles


    /* Lockup */
    Number_of_Shares_Subject_to_Lock = lockup_shares
    Lockup__Lockup_Shares_as_Percent = lockup_pct

    ;

run;

/* 3. Apply standard date formats */
data raw.sdc_raw2;
    set raw.sdc_raw2;
    format idate fdate ldate YYMMDDN8.;
run;

/* 4. Apply initial SDC sample filters */
/* Filter 1: Completed original IPOs only */
data sdc_f1;
    set raw.sdc_raw2;

    if original_ipo_flag = "True";
    if transaction_status = "Live";

run;


/* Filter 2: US IPOs only */
data sdc_f2;
    set sdc_f1;

    if nation = "United States";

run;


/* Filter 3: Common equity offerings only */
data sdc_f3;
    set sdc_f2;

    if security_type in (

        "Common Stock",

        "Class A Common Shares",
        "Class B Common Shares",
        "Class C Common Stock",
        "Class D Common Stock",

        "Ordinary Or Common Shares",
        "Ordinary Shares",

        "Class A Ordinary Shares",
        "Class B Ordinary Shares",

        "Non Voting Shares",
        "Non Voting Class A Shares",
        "Non Voting Class B Shares",

        "Subordinate Voting Shares",
        "Class A Subordinate Voting Shares",
        "Class B Subordinate Voting Shares"
    );

run;


/* Filter 4: USD denominated IPOs */
data sdc_f4;
    set sdc_f3;

    if currency = "US Dollar";

run;


/* Filter 5: Valid identifier */
data sdc_f5;
    set sdc_f4;

    if missing(cusip6) then delete;

run;

/* 5. Standardise CUSIP to 8 digits */
data sdc_f6;
    set sdc_f5;

    len = length(strip(cusip6));

    if len = 6 then cusip_new = cats(strip(cusip6), "10");
    else if len = 8 then cusip_new = strip(cusip6);
    else if len = 9 then cusip_new = substr(strip(cusip6), 1, 8);
    else cusip_new = "";

    drop len;
run;

/* Remove observations without usable CUSIP */
data sdc_f7;
    set sdc_f6;
    if cusip_new = "" then delete;
run;

/* 6. Drop duplicates - keep earliest issue date per CUSIP */
proc sort data=sdc_f7;
    by cusip_new idate;
run;

proc sort data=sdc_f7 nodupkey out=sdc_f8;
    by cusip_new;
run;

/* 7. Construct preliminary SDC variables */
data master.sdc_clean;
    set sdc_f8;

    /* IPO year */
    ipo_year = year(idate);

    /* ln(proceeds), nominal USD millions */
    if proceeds_mil > 0 then lnproceeds = log(proceeds_mil);
    else lnproceeds = .;

    /* Filing range midpoint and absolute offer price adjustment */
    avg_filing = mean(file_price_low, file_price_high);

    if avg_filing > 0 then prcadj = abs((oprc - avg_filing) / avg_filing);
    else prcadj = .;

    /* Venture-backed dummy */
    if upcase(strip(venture_backed)) in ("TRUE", "YES") then VB = 1;
    else if upcase(strip(venture_backed)) in ("FALSE", "NO") then VB = 0;
    else VB = .;

    /* Pure primary dummy(Habib & Ljungqvist 2001; Ljungqvist &
       Wilhelm 2003): missing secondary_shares => no secondary tranche reported => pure
       primary issue (=1). SDC's reporting convention for "no secondary
       shares" shifted from explicit 0 (pre-1988) to NULL (1988 onward) -
       see pipeline diagnostics. */
    if missing(secondary_shares) then pure_primary = 1;
    else if secondary_shares = 0 then pure_primary = 1;
    else pure_primary = 0;

    /* Gross spread percentage */
    if upcase(strip(gross_spread_pct)) in ("", "NA", "N/A") then udfee = .;
    else udfee = input(strip(gross_spread_pct), best32.);

    /* Total shares offered.
       Use observed values only. Missing secondary shares are not forced to zero. */
    if not missing(primary_shares) and not missing(secondary_shares) then
        total_shares_offered = primary_shares + secondary_shares;
    else total_shares_offered = .;

    /* Shares outstanding after offer.
       Prefer prospectus value where available. */
    shares_out_after_offer_final =
        coalesce(shares_out_after_offer_prosp, shares_out_after_offer);

    
    /* New capital raised.
       Gross spread is a percentage of offer price, so divide by 100. */
    if oprc > 0 and not missing(udfee) and primary_shares > 0 then
        newcap = oprc * primary_shares * (1 - udfee / 100);
    else newcap = .;

    label
        cusip_new                    = "8-digit CUSIP for CRSP match"
        ipo_year                     = "IPO issue year"
        lnproceeds                   = "Log proceeds, nominal USD millions"
        prcadj                       = "Absolute offer price adjustment from filing range midpoint"
        VB                           = "Venture-backed dummy"
        pure_primary                 = "Pure primary offering dummy"
        total_shares_offered         = "Primary plus secondary shares offered"
        shares_out_after_offer_final = "Shares outstanding after offer, prospectus value preferred"
        udfee                        = "Gross spread as percent of offer price"
        newcap                       = "Net new capital raised, USD"
    ;
run;

/*---------------------------------------------------------------------------
  Checkpoints
---------------------------------------------------------------------------*/
/* CHECKPOINT: sample count after staged SDC filters */
proc sql;
    create table work.stage1_sample_counts as
    select "Initial SDC import" as step length=50, count(*) as n from raw.sdc_raw2
    union all
    select "Original IPO and live", count(*) from sdc_f1
    union all
    select "US IPOs only", count(*) from sdc_f2
    union all
    select "Common equity offerings only", count(*) from sdc_f3
    union all
    select "USD-denominated offers only", count(*) from sdc_f4
    union all
    select "Non-missing 6-digit CUSIP", count(*) from sdc_f5
    union all
    select "Usable 8-digit CUSIP", count(*) from sdc_f7
    union all
    select "Deduplicated by CUSIP", count(*) from sdc_f8
    union all
    select "Cleaned SDC base", count(*) from master.sdc_clean;
quit;

proc print data=work.stage1_sample_counts noobs;
run;

/* Persist Stage 1 attrition counts for combination in later stages */
data master.attrition_stage1;
    set work.stage1_sample_counts;
run;

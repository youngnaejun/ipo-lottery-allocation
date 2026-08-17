/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
03_stage1_underwriter_matching.sas

Stage:
Stage 1 - Sample Construction

Purpose:
Merge IPO lead manager information with Jay Ritter's underwriter
reputation rankings and construct top-tier underwriter measures.

Inputs:
- master.sdc_crsp
- raw.underwriter_clean.csv

Outputs:
- master.sdc_crsp_uw

Key variables:
- TT: maximum reputation rank among lead managers
- TT_lead1: first-listed lead manager reputation
- TT_ave: average reputation rank across lead managers

Notes:
Underwriter names are standardised using confirmed aliases to account
for historical name changes and SDC/Ritter naming differences.

Last updated:
June 2026
********************************************************************/

%include "00_config.sas";

/* 1. Import Ritter underwriter ranking file */

proc import
    datafile = "&raw\underwriter_clean.csv"
    dbms     = csv
    out      = raw.underwriter
    replace;
    getnames = yes;
    guessingrows = max;
run;

/* Rank2122 sometimes imports as character due to text notes */
data raw.underwriter;
    set raw.underwriter;
    Rank2122_num = input(strip(Rank2122), ?? best32.);
    drop Rank2122;
    rename Rank2122_num = Rank2122;
run;

/* Convert unavailable rank values (-9) to missing */
data work.underwriter_rank;
    set raw.underwriter;

    array ranks(*) Rank8084 Rank8591 Rank9200 Rank0104 Rank0507
                   Rank0809 Rank1011 Rank1217 Rank1820 Rank2122
                   Rank23 Rank24 Rank25 Rank26;

    do i = 1 to dim(ranks);
        if ranks(i) = -9 then ranks(i) = .;
    end;

    drop i;
run;


/* 2. Standardise Ritter underwriter names */

%macro clean_uw_name(var);
    &var = upcase(strip(&var));
    &var = compress(&var, ".,'");

    &var = tranwrd(&var, " INCORPORATED", "");
    &var = tranwrd(&var, " INC",          "");
    &var = tranwrd(&var, " LLC",          "");
    &var = tranwrd(&var, " LTD",          "");
    &var = tranwrd(&var, " LP",           "");
    &var = tranwrd(&var, " CORPORATION",  "");
    &var = tranwrd(&var, " CORP",         "");
    &var = tranwrd(&var, " COMPANY",      "");
    &var = tranwrd(&var, " CO",           "");
    &var = tranwrd(&var, "&",             "AND");
    &var = tranwrd(&var, " SECURITIES",          "");
    &var = tranwrd(&var, " CAPITAL MARKETS",     "");
    &var = tranwrd(&var, " INVESTMENT BANKING",  "");

    /* Remove parenthetical content */
    &var = prxchange('s/\(.*?\)//', -1, &var);

    &var = compbl(strip(&var));
%mend;

data work.underwriter_rank;
    set work.underwriter_rank;
    length uw_name_clean $200;
    uw_name_clean = Underwriter_Name;
    %clean_uw_name(uw_name_clean);
run;

/* Sort by rank coverage so the richest Ritter record survives deduplication */
data work.underwriter_rank;
    set work.underwriter_rank;
    rank_sum = sum(of Rank8084 Rank8591 Rank9200 Rank0104 Rank0507
                      Rank0809 Rank1011 Rank1217 Rank1820 Rank2122
                      Rank23 Rank24 Rank25 Rank26);
run;

proc sort data=work.underwriter_rank;
    by uw_name_clean descending rank_sum;
run;

proc sort data=work.underwriter_rank nodupkey;
    by uw_name_clean;
run;

/* 3. Define confirmed SDC-to-Ritter name bridge */
data work.uw_bridge_table;
    length sdc_name $200 ritter_name $200;

    sdc_name = "CREDIT SUISSE";                     ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;
    sdc_name = "CREDIT SUISSE FIRST BOSTON";        ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;
    sdc_name = "CREDIT SUISSE USA";                 ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;
    sdc_name = "CREDIT SUISSE GROUP";               ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;
    sdc_name = "CS FIRST BOSTON";                   ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;
    sdc_name = "CREDIT SUISSE FIRST BOSTON INT";    ritter_name = "CREDIT SUISSE FIRST BOSTON"; output;

    sdc_name = "BOFA";                              ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "BANK OF AMERICA MERRILL LYNCH";     ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "BANK OF AMERICA-MERRILL LYNCH";     ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "BOA-MERRILL";                       ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH";                     ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH PIERCE FENNER AND SMITH"; ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH PIERCE FENNER";       ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH PIERCE FENNER AND";   ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH CAPITAL MARKETS";     ritter_name = "MERRILL LYNCH AND"; output;
    sdc_name = "MERRILL LYNCH WHITE WELD GROUP";    ritter_name = "MERRILL LYNCH WHITE WELD CPTL"; output;

    sdc_name = "JP MORGAN";                         ritter_name = "JP MORGAN"; output;
    sdc_name = "JP MORGAN AND";                     ritter_name = "JP MORGAN"; output;
    sdc_name = "MORGAN STANLEY";                    ritter_name = "MORGAN STANLEY AND"; output;
    sdc_name = "MORGAN STANLEY DEAN WITTER AND";    ritter_name = "MORGAN STANLEY AND"; output;
    sdc_name = "MORGAN STANLEY DEAN WITTER";        ritter_name = "MORGAN STANLEY AND"; output;
    sdc_name = "MORGAN STANLEY INTERNATIONAL";      ritter_name = "MORGAN STANLEY AND"; output;
    sdc_name = "GOLDMAN SACHS INTERNATIONAL";       ritter_name = "GOLDMAN SACHS AND"; output;

    sdc_name = "CITI";                              ritter_name = "CITIGROUP"; output;
    sdc_name = "CITIGROUP GLOBAL MARKETS";          ritter_name = "CITIGROUP"; output;
    sdc_name = "SMITH BARNEY HARRIS UPHAM AND";     ritter_name = "SMITH BARNEY HARRIS UPHAM"; output;
    sdc_name = "SMITH BARNEY HARRIS UPHAM";         ritter_name = "SMITH BARNEY HARRIS UPHAM"; output;
    sdc_name = "SMITH BARNEY SHEARSON AND";         ritter_name = "SMITH BARNEY SHEARSON"; output;
    sdc_name = "SMITH BARNEY SHEARSON";             ritter_name = "SMITH BARNEY SHEARSON"; output;
    sdc_name = "SHEARSON LEHMAN BROTHERS HOLDINGS"; ritter_name = "SHEARSON LEHMAN BROTHERS"; output;
    sdc_name = "SHEARSON LEHMAN HUTTON INTERNATIONAL"; ritter_name = "SHEARSON LEHMAN HUTTON"; output;
    sdc_name = "EF HUTTON";                         ritter_name = "EF HUTTON AND"; output;
    sdc_name = "COWEN AND";                         ritter_name = "COWEN"; output;
    sdc_name = "D H BLAIR AND";                     ritter_name = "D H BLAIR"; output;

    sdc_name = "UBS";                               ritter_name = "UBS INVESTMENT BANK"; output;
    sdc_name = "UBS INVESTMENT BANK";               ritter_name = "UBS INVESTMENT BANK"; output;
    sdc_name = "UBS SECURITIES LLC";                ritter_name = "UBS INVESTMENT BANK"; output;
    sdc_name = "BARCLAYS";                          ritter_name = "BARCLAYS CAPITAL"; output;
    sdc_name = "BARCLAYS PLC";                      ritter_name = "BARCLAYS CAPITAL"; output;
    sdc_name = "BARCLAYS CAPITAL GROUP";            ritter_name = "BARCLAYS CAPITAL"; output;
    sdc_name = "LEERINK PARTNERS";                  ritter_name = "LEERINK PARTNERS"; output;
    sdc_name = "LEERINK PARTNER";                   ritter_name = "LEERINK PARTNERS"; output;
    sdc_name = "SVB LEERINK";                       ritter_name = "LEERINK PARTNERS"; output;
    sdc_name = "EVERCORE GROUP";                    ritter_name = "EVERCORE"; output;
    sdc_name = "JEFFERIES";                         ritter_name = "JEFFERIES AND"; output;
    sdc_name = "PIPER SANDLER AND";                 ritter_name = "PIPER-SANDLER"; output;
    sdc_name = "PIPER-SANDLER";                     ritter_name = "PIPER-SANDLER"; output;
    sdc_name = "PIPER JAFFRAY";                     ritter_name = "PIPER JAFFRAY"; output;
    sdc_name = "PIPER JAFFRAY S";                   ritter_name = "PIPER JAFFRAY"; output;
    sdc_name = "PIPER JAFFRAY AND";                 ritter_name = "PIPER JAFFRAY"; output;
    sdc_name = "NOMURA INTERNATIONAL";              ritter_name = "NOMURA"; output;
    sdc_name = "NATWEST LIMITED";                   ritter_name = "NATWEST"; output;
    sdc_name = "SALOMON BROTHERS INTERNATIONAL";    ritter_name = "SALOMON BROTHERS"; output;
    sdc_name = "NATIONSBANC MONTGOMERY";            ritter_name = "NATIONSBANC MONTGOMERY SEC"; output;
    sdc_name = "MACQUARIE CAPITAL";                 ritter_name = "MACQUARIE CAPITAL"; output;

    sdc_name = "BOETTCHER AND";                     ritter_name = "BOETTCHER"; output;
    sdc_name = "F N WOLF AND";                      ritter_name = "F N WOLF"; output;
    sdc_name = "FLEET BOSTON BOSTONMASSACHUSETTS";  ritter_name = "FLEET BOSTON"; output;
    sdc_name = "FURMAN SELZ MAGER DIETZ AND BIRNEY"; ritter_name = "FURMAN SELZ MAGER DIETZ"; output;
    sdc_name = "JAMES J DUANE AND";                 ritter_name = "JAMES J DUANE"; output;
    sdc_name = "JMP";                               ritter_name = "JMP-SEC"; output;
    sdc_name = "JOHN MUIR AND";                     ritter_name = "JOHN MUIR"; output;
    sdc_name = "MOSELEY HALLGARTEN ESTABROOK AND WEEDEN"; ritter_name = "MOSELEY HALLGARTEN ESTABROOK"; output;
    sdc_name = "R G DICKINSON AND";                 ritter_name = "R G DICKINSON"; output;
    sdc_name = "R J STEICHEN AND";                  ritter_name = "R J STEICHEN"; output;
    sdc_name = "REICH AND";                         ritter_name = "REICH"; output;
    sdc_name = "ROSENKRANTZ EHRENKRANTZ LYON AND ROSS"; ritter_name = "ROSENKRANTZ EHRENKRANTZ LYON"; output;
    sdc_name = "THE STUART-JAMES";                  ritter_name = "STUART-JAMES"; output;
    sdc_name = "WEDBUSH";                           ritter_name = "WEDBUSH MORGAN"; output;
    sdc_name = "WELLS FARGO BANK NA";               ritter_name = "WELLS FARGO"; output;
    sdc_name = "WERTHEIM SCHRODER AND";             ritter_name = "WERTHEIM SCHRODER"; output;
run;

/* 4. Convert SDC lead manager strings to manager-level observations */
data work.ipo_manager_long;
    set master.sdc_crsp;
    length manager_raw $300 manager_clean $300 manager_code $100;

    n_managers = countw(lead_managers_raw, ";");
    if n_managers = 0 then n_managers = 1;

    do manager_order = 1 to n_managers;
        manager_raw  = strip(scan(lead_managers_raw,      manager_order, ";"));
        manager_code = strip(scan(lead_manager_codes_raw, manager_order, ";"));

        if upcase(strip(manager_raw)) in ("", "NOT APPLICABLE", "NA", "N/A", "UNKNOWN") then continue;

        manager_clean = upcase(strip(manager_raw));
        manager_clean = compress(manager_clean, ".,'");

        /* Standardise whitespace, including tab and non-breaking space */
        manager_clean = translate(manager_clean, ' ', '09'x);
        manager_clean = translate(manager_clean, ' ', 'A0'x);

        manager_clean = tranwrd(manager_clean, " INCORPORATED", "");
        manager_clean = tranwrd(manager_clean, " INC",          "");
        manager_clean = tranwrd(manager_clean, " LLC",          "");
        manager_clean = tranwrd(manager_clean, " LTD",          "");
        manager_clean = tranwrd(manager_clean, " LP",           "");
        manager_clean = tranwrd(manager_clean, " CORPORATION",  "");
        manager_clean = tranwrd(manager_clean, " CORP",         "");
        manager_clean = tranwrd(manager_clean, " COMPANY",      "");
        manager_clean = tranwrd(manager_clean, " CO",           "");
        manager_clean = tranwrd(manager_clean, "&",             "AND");
        manager_clean = tranwrd(manager_clean, " SECURITIES",          "");
        manager_clean = tranwrd(manager_clean, " CAPITAL MARKETS",     "");
        manager_clean = tranwrd(manager_clean, " INVESTMENT BANKING",  "");

        manager_clean = prxchange('s/\(.*?\)//', -1, manager_clean);
        manager_clean = compbl(strip(manager_clean));

        output;
    end;

    keep deal_num cusip_new idate ipo_year lead_managers_raw lead_manager_codes_raw
         manager_order manager_raw manager_code manager_clean;
run;

/* 5. Apply confirmed name bridge */
proc sql;
    create table work.ipo_manager_mapped as
    select
        a.*,
        strip(coalesce(b.ritter_name, a.manager_clean)) as manager_lookup_key
    from work.ipo_manager_long as a
    left join work.uw_bridge_table as b
    on strip(a.manager_clean) = strip(b.sdc_name);
quit;

/* 6. Match SDC managers to Ritter ranking file */
proc sql;
    create table work.ipo_manager_ranked as
    select
        a.*,
        b.Underwriter_Name      as ritter_underwriter_name,
        b.uw_name_clean         as ritter_name_clean,
        b.Rank8084, b.Rank8591, b.Rank9200, b.Rank0104,
        b.Rank0507, b.Rank0809, b.Rank1011, b.Rank1217,
        b.Rank1820, b.Rank2122, b.Rank23,   b.Rank24,
        b.Rank25,   b.Rank26
    from work.ipo_manager_mapped as a
    left join work.underwriter_rank as b
    on strip(a.manager_lookup_key) = strip(b.uw_name_clean);
quit;

/* 7. Select year-specific underwriter rank */
data work.ipo_manager_ranked;
    set work.ipo_manager_ranked;

    if      1975 <= ipo_year <= 1984 then uw_rank_i = Rank8084;
    else if 1985 <= ipo_year <= 1991 then uw_rank_i = Rank8591;
    else if 1992 <= ipo_year <= 2000 then uw_rank_i = Rank9200;
    else if 2001 <= ipo_year <= 2004 then uw_rank_i = Rank0104;
    else if 2005 <= ipo_year <= 2007 then uw_rank_i = Rank0507;
    else if 2008 <= ipo_year <= 2009 then uw_rank_i = Rank0809;
    else if 2010 <= ipo_year <= 2011 then uw_rank_i = Rank1011;
    else if 2012 <= ipo_year <= 2017 then uw_rank_i = Rank1217;
    else if 2018 <= ipo_year <= 2020 then uw_rank_i = Rank1820;
    else if 2021 <= ipo_year <= 2022 then uw_rank_i = Rank2122;
    else if ipo_year = 2023          then uw_rank_i = Rank23;
    else if ipo_year = 2024          then uw_rank_i = Rank24;
    else if ipo_year = 2025          then uw_rank_i = Rank25;
    else if ipo_year = 2026          then uw_rank_i = Rank26;
    else uw_rank_i = .;

    match_flag_i = not missing(uw_rank_i);
run;

/* 8. Collapse manager-level ranks to IPO-level measures */
proc sql;
    create table work.ipo_uw_rank1 as
    select
        deal_num,
        cusip_new,
        idate,
        count(*)                                             as n_lead_managers,
        sum(match_flag_i)                                    as n_matched_managers,

        /* TT: maximum rank across lead managers */
        max(uw_rank_i)                                       as uw_rank,
        max(case when uw_rank_i >= 8 then 1 else 0 end)      as TT,

        /* TT_ave: average rank across non-missing lead managers */
        mean(uw_rank_i)                                      as uw_rank_ave,
        case when calculated uw_rank_ave >= 8 then 1
             when calculated uw_rank_ave <  8 then 0
             else .
        end                                                  as TT_ave

    from work.ipo_manager_ranked
    group by deal_num, cusip_new, idate;
quit;

/* 9. Attach top-ranked underwriter name */
proc sort data=work.ipo_manager_ranked
          out=work.top_uw_candidates;
    by deal_num cusip_new idate descending uw_rank_i manager_order;
run;

data work.top_uw_name;
    set work.top_uw_candidates;
    by deal_num cusip_new idate;
    if first.idate;

    keep deal_num cusip_new idate manager_raw ritter_underwriter_name;

    rename
        manager_raw             = top_underwriter_name
        ritter_underwriter_name = top_underwriter_ritter;
run;

/* 10. Construct first-listed lead manager measure */
proc sql;
    create table work.ipo_uw_lead1 as
    select deal_num, cusip_new, idate,
           uw_rank_i                                  as uw_rank_lead1,
           case when uw_rank_i >= 8 then 1
                when uw_rank_i is not missing then 0
                else .
           end                                        as TT_lead1
    from work.ipo_manager_ranked
    where manager_order = 1;
quit;

/* 11. Combine underwriter reputation measures */
proc sort data=work.ipo_uw_rank1; by deal_num cusip_new idate; run;
proc sort data=work.ipo_uw_lead1; by deal_num cusip_new idate; run;

proc sql;
    create table work.tt_all as
    select a.*,
           b.uw_rank_lead1,
           b.TT_lead1
    from work.ipo_uw_rank1 as a
    left join work.ipo_uw_lead1 as b
    on  a.deal_num  = b.deal_num
    and a.cusip_new = b.cusip_new
    and a.idate     = b.idate;
quit;

/* 12. Attach top underwriter name */
proc sort data=work.tt_all;      by deal_num cusip_new idate; run;
proc sort data=work.top_uw_name; by deal_num cusip_new idate; run;

proc sql;
    create table work.ipo_uw_rank as
    select
        a.*,
        b.top_underwriter_name,
        b.top_underwriter_ritter
    from work.tt_all as a
    left join work.top_uw_name as b
    on  a.deal_num   = b.deal_num
    and a.cusip_new  = b.cusip_new
    and a.idate      = b.idate;
quit;

/* 13. Merge underwriter reputation measures back to IPO sample */
proc sort data=master.sdc_crsp;  by deal_num cusip_new idate; run;
proc sort data=work.ipo_uw_rank; by deal_num cusip_new idate; run;

data master.sdc_crsp_uw;
    merge master.sdc_crsp  (in=a)
          work.ipo_uw_rank (in=b);
    by deal_num cusip_new idate;
    if a;

    /* Missing rank remains missing rather than being recoded to zero */
    if missing(uw_rank)       then TT       = .;
    if missing(uw_rank_lead1) then TT_lead1 = .;
    if missing(uw_rank_ave)   then TT_ave   = .;

    label
        uw_rank      = "Maximum CM/Ritter rank among lead managers"
        TT           = "Top-tier dummy: max across lead managers, rank >= 8"
        uw_rank_ave  = "Average CM/Ritter rank across lead managers (non-missing only)"
        TT_ave       = "Top-tier dummy: average across lead managers, rank >= 8"
        uw_rank_lead1 = "CM/Ritter rank of first-listed lead manager"
        TT_lead1     = "Top-tier dummy: first-listed lead manager only, rank >= 8"
        n_lead_managers    = "Number of SDC lead managers after cleaning"
        n_matched_managers = "Number of lead managers matched to Ritter ranking"
        top_underwriter_name   = "SDC lead manager with highest matched rank"
        top_underwriter_ritter = "Matched Ritter name with highest rank";
run;

/* CHECKPOINT:
   Verify underwriter reputation coverage in final IPO sample.
*/

proc means data=master.sdc_crsp_uw n nmiss mean median min max;
    var uw_rank TT uw_rank_ave TT_ave uw_rank_lead1 TT_lead1
        n_lead_managers n_matched_managers;
    title "Checkpoint: underwriter reputation matching summary";
run;

proc freq data=master.sdc_crsp_uw;
    tables TT TT_ave TT_lead1 / missing;
    title "Checkpoint: top-tier underwriter dummies";
run;

title;

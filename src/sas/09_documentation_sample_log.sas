/**********************************************************************
 Program: 09_documentation_sample_log.sas
 Purpose: Create Sample_Construction_Log.xlsx
          Sheet1: Detailed replication log
          Sheet2: Journal-ready sample selection table
**********************************************************************/

%include "00_config.sas";

/* Documentation output folder */
%let docs = &proj.\documentation;

options dlcreatedir;
libname docs "&docs.";


/**********************************************************************
 1. Detailed construction log from permanent attrition table
**********************************************************************/

data work.attrition_base;

    set master.sample_attrition;

    length Sample_Selection_Criteria $180 
           SAS_File $100;

    select (strip(step));

        when ("Initial SDC import") do;
            Step_No = 1;
            Sample_Selection_Criteria =
                "Initial SDC Platinum IPO universe";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("Original IPO and live") do;
            Step_No = 2;
            Sample_Selection_Criteria =
                "Keep original IPOs with active issue status";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("US IPOs only") do;
            Step_No = 3;
            Sample_Selection_Criteria =
                "Restrict to U.S. issuers";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("Exclude SPACs") do;
            Step_No = 4;
            Sample_Selection_Criteria =
                "Exclude SPACs and blank-check companies";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("Common equity offerings only") do;
            Step_No = 5;
            Sample_Selection_Criteria =
                "Keep common equity IPOs";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("USD-denominated offers only") do;
            Step_No = 6;
            Sample_Selection_Criteria =
                "Keep USD-denominated IPOs";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("Cleaned SDC base") do;
            Step_No = 7;
            Sample_Selection_Criteria =
                "Require valid identifiers and remove duplicate CUSIPs";
            SAS_File = "01_stage1_sdc_cleaning";
        end;

        when ("CRSP matched") do;
            Step_No = 8;
            Sample_Selection_Criteria =
                "Match IPOs with CRSP identifiers";
            SAS_File = "02_stage1_wrds_crsp_linking";
        end;

        when ("Underwriter information merged") do;
            Step_No = 9;
            Sample_Selection_Criteria =
                "Merge underwriter reputation data";
            SAS_File = "03_stage1_underwriter_matching";
        end;

        when ("Analysis universe (FF30 1-29, year>=1975)") do;
            Step_No = 10;
            Sample_Selection_Criteria =
                "Require IPO characteristics and industry classification";
            SAS_File = "04_stage1_final_sample";
        end;

        otherwise delete;

    end;

    Remaining_IPOs = n;

    keep Step_No Sample_Selection_Criteria
         Remaining_IPOs SAS_File;

run;


/**********************************************************************
 2. Add final estimation samples
**********************************************************************/

proc sql;

create table work.final_counts as

select 11 as Step_No,
       "Require expected skewness, coskewness, and IPO return variables"
          as Sample_Selection_Criteria length=180,
       count(*) as Remaining_IPOs,
       "05_stage2_skewness_coskewness; 06_stage2_ipo_returns"
          as SAS_File length=100
from master.analysis_full
where main_sample_flag=1
  and not missing(skew1)
  and not missing(coskewness)
  and not missing(r0)
  and not missing(r2_bhar_3y)

union all

select 12,
       "Final extended sample (1975-2024)",
       count(*),
       "Final dataset"
from master.analysis_full
where main_sample_flag=1
  and 1975 <= year(idate) <= 2024
  and not missing(skew1)
  and not missing(coskewness)
  and not missing(r0)
  and not missing(r2_bhar_3y)

union all

select 13,
       "Original replication sample period (1975-2016)",
       count(*),
       "Final dataset"
from master.analysis_full
where main_sample_flag=1
  and 1975 <= year(idate) <= 2016
  and not missing(skew1)
  and not missing(coskewness)
  and not missing(r0)
  and not missing(r2_bhar_3y)
;

quit;

/**********************************************************************
 3. Detailed table + dropped observations
**********************************************************************/

data work.detailed_log;

    set work.attrition_base
        work.final_counts;

run;

proc sort data=work.detailed_log;
    by Step_No;
run;


data work.detailed_log;

    retain Step
           SAS_File
           Sample_Selection_Criteria
           Remaining_IPOs
           Dropped_IPOs;

    set work.detailed_log;

    by Step_No;

    Previous_N = lag(Remaining_IPOs);

    if Step_No = 1 then Dropped_IPOs = .;
    else Dropped_IPOs = Previous_N - Remaining_IPOs;

    Step = Step_No;

    keep Step
         SAS_File
         Sample_Selection_Criteria
         Remaining_IPOs
         Dropped_IPOs;

run;

/**********************************************************************
 4. Create journal-ready sample selection table
**********************************************************************/

data work.journal_sample_table;

    length Filtering_Criteria $250
           Remaining_IPOs 8
           Dropped_IPOs 8;

    infile datalines delimiter='|' dsd truncover;

    input Filtering_Criteria :$250.
          Remaining_IPOs
          Dropped_IPOs;

datalines;
Baseline SDC Platinum IPO Universe|14009|.
Less: Non-original IPOs, inactive issues, non-U.S. firms, non-common equity, or non-USD offers|12897|1112
Less: Observations unmatched with CRSP identifiers|9334|3563
Less: Observations without required IPO characteristics and controls|8856|478
Less: Blank check companies (SPACs) and non-exchange listings|8562|294
Final IPO Sample (1975-2024)|8562|.
;
run;


/**********************************************************************
 5. Export two sheets
**********************************************************************/

proc export data=work.detailed_log
    outfile="&docs.\Sample_Construction_Log.xlsx"
    dbms=xlsx
    replace;
    sheet="Detailed_Construction_Log";
run;


proc export data=work.journal_sample_table
    outfile="&docs.\Sample_Construction_Log.xlsx"
    dbms=xlsx
    replace;
    sheet="Journal_Sample_Table";
run;


/**********************************************************************
 Check
**********************************************************************/

title "Detailed Sample Construction Log";
proc print data=work.detailed_log noobs;
run;

title "Journal Sample Selection Table";
proc print data=work.journal_sample_table noobs;
run;

title;

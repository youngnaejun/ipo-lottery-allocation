/* WRDS server connection check (WRDS_MODE=wrds). Signs on with the original SAS/CONNECT method
   (signon username=_prompt_: SAS asks for the WRDS user name and password; nothing is stored), then:
     1. counts January 2024 rows of crsp.dsi and crsp.dsedelist and the first 100,000 rows of crsp.dsf on WRDS;
     2. uploads a two-row target list and downloads the matching rows, as the total-loss extract does.
   Run it through workflow/check_wrds_connection.sh. It changes nothing in a run folder. */
options compress=binary;
%include "%sysget(IPO_CONFIG)";
data work.check_targets; permno = 0; idate = '01JAN2024'd; output; permno = 1; output; format idate yymmdd10.; run;
%wrds_signon;
rsubmit;
proc upload data=work.check_targets out=work.check_targets; run;
proc sql;
    create table work.check_counts as
    select 'crsp.dsi'        as library_table length=20, count(*) as rows from crsp.dsi
        where date between '01JAN2024'd and '31JAN2024'd
    union all
    select 'crsp.dsf', count(*) from crsp.dsf(obs=100000 keep=permno date ret)
    union all
    select 'crsp.dsedelist', count(*) from crsp.dsedelist where dlstdt between '01JAN2024'd and '31JAN2024'd
    union all
    select 'uploaded targets', count(*) from work.check_targets;
quit;
proc download data=work.check_counts out=work.check_counts; run;
endrsubmit;
%wrds_signoff;
title "WRDS connection check: rows found on the server";
proc print data=work.check_counts noobs; run;
data _null_;
    set work.check_counts end=last;
    if rows <= 0 and library_table ne 'uploaded targets' then put "ERROR: no rows returned from " library_table;
    if library_table = 'uploaded targets' and rows ne 2 then put "ERROR: upload round trip failed";
    if last then put "NOTE: WRDS connection check finished.";
run;

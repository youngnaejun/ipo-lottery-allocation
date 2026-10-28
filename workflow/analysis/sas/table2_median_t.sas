/* Table 2 median high-minus-low test (He and Hu, 2002 MCMB resampling), as in compare_table2.sas:
   PROC RANK GROUPS=3 terciles of skew1, Low+High sample, PROC QUANTREG ci=resampling seed=20260930.
   Usage: sas -sysin table2_median_t.sas -set INCSV <ipo_returns.csv> -set OUTCSV <params.csv> */
%let incsv=%sysget(INCSV);
%let outcsv=%sysget(OUTCSV);
options nodate nonumber;
ods graphics off;
proc import datafile="&incsv." out=work.sample dbms=csv replace; guessingrows=max; run;
data work.sample; set work.sample; where 1975<=ipo_year and ipo_year<=2024; run;
proc rank data=work.sample out=work.ranked groups=3; var skew1; ranks skew_rank; run;
data work.diff_sample; set work.ranked; skew_group=skew_rank+1; if skew_group in (1,3); high_dummy=(skew_group=3); run;
ods output ParameterEstimates=work.median_params;
proc quantreg data=work.diff_sample ci=resampling;
 model r0=high_dummy / quantile=0.5 seed=20260930;
run;
proc export data=work.median_params outfile="&outcsv." dbms=csv replace; run;

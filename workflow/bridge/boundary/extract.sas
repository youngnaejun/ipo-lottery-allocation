/* Total-loss (-100%) correction: extract CRSP daily and delisting returns of the target IPOs
   (targets.csv, written by make_boundary_targets.py) into aud.daily and aud.delist for compare.py.
   WRDS_MODE=local reads the local WRDS copy (extract_local.sas); WRDS_MODE=wrds runs the same selection on the
   WRDS server through SAS/CONNECT (extract_wrds.sas). */
options compress=binary;
%include "%sysget(IPO_CONFIG)";
libname aud '@RUN_ROOT@\ext\boundary';
data targets; infile '@RUN_ROOT@\ext\boundary\targets.csv' dsd firstobs=2; informat idate yymmdd10.; input permno idate r0; run;
%macro pick_route;
  %global route_file;
  %if %upcase(%sysget(IPO_WRDS_MODE)) = WRDS %then %let route_file = extract_wrds.sas;
  %else %let route_file = extract_local.sas;
%mend;
%pick_route;
%put NOTE: Total-loss extract route: &route_file.;
%include "@RUN_ROOT@\ext\boundary\&route_file.";

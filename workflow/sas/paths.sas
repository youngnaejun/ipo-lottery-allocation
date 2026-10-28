/* Pipeline configuration. Set by the runner through environment variables:
     IPO_ROOT       run root holding raw\, master\, output\, ext\ (raw\ holds the supplier files)
     IPO_SRC        this source tree
     IPO_WRDS_MODE  local = WRDS blocks run in a spawned SAS session on a local WRDS copy (IPO_WRDS_DATA)
                    wrds  = WRDS blocks run on the WRDS server (credentials typed at the SAS sign-on prompt)
     IPO_WRDS_DATA  root of the local WRDS copy (local mode only), e.g. C:\data\wrds                */
options compress=binary nodate nonumber;
ods graphics off;
%let proj   = %sysget(IPO_ROOT);
%let src    = %sysget(IPO_SRC);
%let raw    = &proj.\raw;
%let master = &proj.\master;
%let output = &proj.\output;
%let ext    = &proj.\ext;
options dlcreatedir;
libname raw    "&raw.";
libname master "&master.";
libname output "&output.";

%macro wrds_signon;
  %if %upcase(%sysget(IPO_WRDS_MODE)) = WRDS %then %do;
    %global wrds;
    %let wrds = wrds-cloud.wharton.upenn.edu 4016;
    options comamid=TCP remote=WRDS;
    signon username=_prompt_;
  %end;
  %else %do;
    %let wrdsdata = %sysget(IPO_WRDS_DATA);
    options sascmd="!sascmd -nosyntaxcheck -noautoexec" remote=wrdsloc;
    signon wrdsloc;
    %syslput wrdsdata=&wrdsdata / remote=wrdsloc;
    rsubmit wrdsloc;
      options compress=binary;
      libname crsp "&wrdsdata.\raw\crsp\a_stock" access=readonly;
      libname ff   "&wrdsdata.\raw\ff" access=readonly;
      %include "&wrdsdata.\catalog\comp_local.sas";
    endrsubmit;
  %end;
%mend;
%macro wrds_signoff;
  signoff;
%mend;

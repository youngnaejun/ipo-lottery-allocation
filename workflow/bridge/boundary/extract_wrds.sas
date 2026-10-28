/* Total-loss correction extract, server route (WRDS_MODE=wrds): the same selection as extract_local.sas, run on
   the WRDS server through SAS/CONNECT. %wrds_signon prompts for the WRDS user name and password in SAS; nothing
   is stored. The target list is uploaded, the daily and delisting returns of the target IPOs are selected on
   WRDS, and the two result datasets are downloaded to the run folder (aud.daily, aud.delist), where the
   correction step (compare.py) reads them. Included by extract.sas, which defines work.targets and aud. */
%wrds_signon;
rsubmit;
proc upload data=work.targets out=work.targets; run;
data work.daily;
 if _n_=1 then do;
  if 0 then set targets;
  declare hash h(dataset:'targets'); h.defineKey('permno'); h.defineData('idate'); h.defineDone();
 end;
 set crsp.dsf(keep=permno date ret);
 if h.find()=0 and date>=idate and date<='@DATA_END_DATE@'d;
 keep permno date ret;
run;
data work.delist;
 if _n_=1 then do;
  if 0 then set targets;
  declare hash h(dataset:'targets'); h.defineKey('permno'); h.defineData('idate'); h.defineDone();
 end;
 set crsp.dsedelist(keep=permno dlstdt dlret dlstcd);
 if h.find()=0 and dlstdt>=idate and dlstdt<='@DATA_END_DATE@'d;
 keep permno dlstdt dlret dlstcd;
run;
proc download data=work.daily out=aud.daily; run;
proc download data=work.delist out=aud.delist; run;
endrsubmit;
%wrds_signoff;

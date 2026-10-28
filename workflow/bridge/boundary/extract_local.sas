/* Total-loss correction extract, local route (WRDS_MODE=local): reads the local copy of CRSP daily returns
   and delisting returns for the target IPOs. Included by extract.sas, which defines work.targets and aud. */
libname crsp '@WRDS_DATA@\raw\crsp\a_stock' access=readonly;
data aud.daily;
 if _n_=1 then do;
  if 0 then set targets;
  declare hash h(dataset:'targets'); h.defineKey('permno'); h.defineData('idate'); h.defineDone();
 end;
 set crsp.dsf(keep=permno date ret);
 if h.find()=0 and date>=idate and date<='@DATA_END_DATE@'d;
 keep permno date ret;
run;
data aud.delist;
 if _n_=1 then do;
  if 0 then set targets;
  declare hash h(dataset:'targets'); h.defineKey('permno'); h.defineData('idate'); h.defineDone();
 end;
 set crsp.dsedelist(keep=permno dlstdt dlret dlstcd);
 if h.find()=0 and dlstdt>=idate and dlstdt<='@DATA_END_DATE@'d;
 keep permno dlstdt dlret dlstcd;
run;

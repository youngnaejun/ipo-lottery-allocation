/********************************************************************
Project:
IPO Lottery Demand Replication and Extension

Program:
00_config.sas

Purpose:
Define global project folders and SAS libraries.

Last updated:
June 2026
********************************************************************/

options encoding="utf-8" compress=binary nodate nonumber;
ods graphics off;

/*
  Project folders. IPO_LOTTERY_ROOT must point to a private local workspace
  containing raw/, master/ and output/. No licensed data belong in this repo.
*/
%let proj = %sysget(IPO_LOTTERY_ROOT);
%if %superq(proj)= %then %do;
    %put ERROR: Set the IPO_LOTTERY_ROOT environment variable before running SAS.;
    %abort cancel;
%end;
%let raw    = &proj.\raw;
%let master = &proj.\master;
%let output = &proj.\output;

/* Create folders automatically when needed */
options dlcreatedir;

/* Project libraries */
libname raw    "&raw.";
libname master "&master.";
libname output "&output.";

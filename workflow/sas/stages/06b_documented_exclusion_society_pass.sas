/* Stage 06b (paper-specific; runs after Stage 06). */
/* Preserve the prior exclusion of Society Pass (PERMNO 22342) due to an SDC data issue. */
/* This is a decision about one record in the paper's SDC extract, not a general screen (for example, it is
   not a foreign-issuer rule). It applies only when APPLY_PAPER_EXCLUSIONS=1 in the workflow configuration.
   When applied, the stage stops if more than the one intended observation would be removed. A sample that
   does not contain the record (another period) passes with nothing removed, unless PAPER_CHECKS=1, which
   requires exactly one removal as in the paper. */
%include "%sysget(IPO_CONFIG)";
%macro paper_exclusion;
    %if @APPLY_PAPER_EXCLUSIONS@ ne 1 %then %do;
        %put NOTE: Stage 06b skipped (APPLY_PAPER_EXCLUSIONS is not 1).;
        %return;
    %end;
    proc sql noprint;
        select count(*) into :n_before trimmed from master.analysis_full;
        select count(*) into :n_target trimmed from master.analysis_full where permno = 22342;
    quit;
    data master.analysis_full;
        set master.analysis_full;
        if permno = 22342 then delete;
    run;
    proc sql noprint;
        select count(*) into :n_after trimmed from master.analysis_full;
    quit;
    %if &n_target gt 1 or %eval(&n_before - &n_after) ne &n_target
        or (@PAPER_CHECKS@ = 1 and &n_target ne 1) %then %do;
        %put ERROR: Stage 06b expected to remove one row for PERMNO 22342 (found &n_target, removed %eval(&n_before - &n_after)).;
        %abort cancel;
    %end;
    %else %put NOTE: Stage 06b removed &n_target row(s) for PERMNO 22342 (&n_before -> &n_after rows).;
%mend;
%paper_exclusion;

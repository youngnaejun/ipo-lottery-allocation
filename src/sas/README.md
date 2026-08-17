# SAS production pipeline

These programs are the authoritative data-engineering implementation used with
licensed SDC/LSEG and WRDS data. They are retained in their working language;
the Python package is a public test harness, not a claim that the production
research was rewritten in Python.

Run SAS from this directory so the relative `%include "00_config.sas"` statements
resolve. Before starting, define `IPO_LOTTERY_ROOT` as the absolute path to a
private workspace containing `raw/`, `master/` and `output/` subdirectories.
WRDS stages prompt for the authorised user's username and do not store it.

## Stages

1. `01_stage1_sdc_cleaning.sas` cleans the new-issues universe.
2. `02_stage1_wrds_crsp_linking.sas` resolves securities against CRSP.
3. `03_stage1_underwriter_matching.sas` attaches underwriter reputation.
4. `04_stage1_final_sample.sas` constructs the analysis universe.
5. `05_stage2_skewness_coskewness.sas` constructs lottery-preference measures.
6. `06_stage2_ipo_returns.sas` constructs first-day and long-run returns.
7. `09_documentation_sample_log.sas` writes sample-construction diagnostics.

The retained source does not yet contain the direct identifier exclusion that
removed Society Pass from the saved 8,923-observation analysis dataset. Do not
claim a fresh source-only run reproduces that final count until the confirmed
identifier rule has been restored and reviewed.


# Public file manifest

Release candidate prepared 22 October 2026, revised 23 October 2026 (not published). Sources: the repository's committed files
(`ipo-lottery-allocation`, HEAD `fecacff`) and the project's internal replication package (22 October 2026).
No data files, environments, caches or run outputs are included.

| File | Origin | Change |
|---|---|---|
| `.dockerignore` | repository | unchanged |
| `.env.example` | repository | unchanged |
| `.github/workflows/tests.yml` | repository | unchanged |
| `.gitignore` | repository | unchanged |
| `CITATION.cff` | repository | unchanged |
| `Dockerfile` | repository | unchanged |
| `LICENSE` | repository | unchanged |
| `PUBLIC_MANIFEST.md` | new | this file |
| `README.md` | repository (rewritten) | from the approved README draft |
| `config/config.yaml` | repository | unchanged |
| `docs/architecture.md` | repository (rewritten) | two components; structural vs paper checks |
| `docs/configuration.md` | new | settings and date dependencies |
| `docs/conventions.md` | new | research conventions |
| `docs/data_acquisition.md` | new | data acquisition |
| `docs/input_schemas.md` | new | input schemas |
| `pyproject.toml` | repository | unchanged |
| `src/ipo_lottery/__init__.py` | repository | unchanged |
| `src/ipo_lottery/__main__.py` | repository | unchanged |
| `src/ipo_lottery/analysis.py` | repository | unchanged |
| `src/ipo_lottery/audit.py` | repository | unchanged |
| `src/ipo_lottery/clean.py` | repository | unchanged |
| `src/ipo_lottery/cli.py` | repository | unchanged |
| `src/ipo_lottery/features.py` | repository | unchanged |
| `src/ipo_lottery/ingest.py` | repository | unchanged |
| `src/ipo_lottery/link.py` | repository | unchanged |
| `tests/__init__.py` | repository | unchanged |
| `tests/conftest.py` | repository | unchanged |
| `tests/fixtures/__init__.py` | repository | unchanged |
| `tests/fixtures/make_synthetic.py` | repository | unchanged |
| `tests/test_audit.py` | repository | unchanged |
| `tests/test_clean.py` | repository | unchanged |
| `tests/test_features.py` | repository | unchanged |
| `tests/test_link.py` | repository | unchanged |
| `tests/test_pipeline.py` | repository | unchanged |
| `tests/test_workflow_tools.py` | new | tests of placeholder filling and the synthetic generator |
| `workflow/analysis/build_word_tables.py` | internal package stata | docstring |
| `workflow/analysis/do/00_master.do` | internal package stata/do | header wording |
| `workflow/analysis/do/01_table1.do` | internal package stata/do | header wording |
| `workflow/analysis/do/02_table2.do` | internal package stata/do | header wording |
| `workflow/analysis/do/03_returns.do` | internal package stata/do | header wording |
| `workflow/analysis/do/04_panels.do` | internal package stata/do | header wording |
| `workflow/analysis/do/06_revisions.do` | internal package stata/do | header wording |
| `workflow/analysis/do/08_appendix_b3_b4.do` | internal package stata/do | header wording |
| `workflow/analysis/do/09_internet_appendix_ppml.do` | internal package stata/do | header wording |
| `workflow/analysis/do/_post.do` | internal package stata/do | header wording |
| `workflow/analysis/export_stata_inputs.py` | internal package stata | docstring |
| `workflow/analysis/sas/table2_median_t.sas` | internal package stata/sas | unchanged |
| `workflow/analysis/table_input_schema.json` | new | column names and types of the four analysis datasets |
| `workflow/analysis/table_text.json` | new | neutral captions and notes (replaces manuscript wording) |
| `workflow/bridge/boundary/compare.py` | internal package src/downstream/boundary | paths and data end date from configuration; regression comparison with diagnostic models removed |
| `workflow/bridge/boundary/extract.sas` | internal package src/downstream/boundary | route dispatcher: local copy or WRDS server by WRDS_MODE |
| `workflow/bridge/boundary/extract_local.sas` | internal package src/downstream/boundary/extract.sas | the original local extract, unchanged in substance |
| `workflow/bridge/boundary/extract_wrds.sas` | new | same selection on the WRDS server via SAS/CONNECT (upload targets, download results) |
| `workflow/bridge/boundary/make_boundary_targets.py` | internal package tools | unchanged |
| `workflow/bridge/controls/audit_additional_filer_controls.py` | internal package src/downstream/0928-1002_code | paths from placeholders; comparisons with archived results removed; paper counts only with PAPER_CHECKS; underwriter rank blocks extended to Rank25/26 as in stage 03 |
| `workflow/bridge/controls/audit_all_filer_controls.py` | internal package src/downstream/0928-1002_code | paths from placeholders; comparisons with archived results removed; paper counts only with PAPER_CHECKS; underwriter rank blocks extended to Rank25/26 as in stage 03 |
| `workflow/bridge/controls/audit_recovered61.py` | internal package src/downstream/0928-1002_code | paths from placeholders; comparisons with archived results removed; paper counts only with PAPER_CHECKS; underwriter rank blocks extended to Rank25/26 as in stage 03 |
| `workflow/bridge/controls/estimate_all_filer_comparison.py` | internal package src/downstream/0928-1002_code | paths from placeholders; comparisons with archived results removed; paper counts only with PAPER_CHECKS; underwriter rank blocks extended to Rank25/26 as in stage 03 |
| `workflow/bridge/controls/estimate_table4.py` | internal package src/downstream/0928-1002_code | reduced to the estimation helpers; benchmark code reading archived results removed |
| `workflow/bridge/controls/estimate_table5_expanded.py` | internal package src/downstream/0928-1002_code | paths from placeholders; comparisons with archived results removed; paper counts only with PAPER_CHECKS; underwriter rank blocks extended to Rank25/26 as in stage 03 |
| `workflow/bridge/controls/make_recovered61_list.py` | internal package tools | paper count only with PAPER_CHECKS |
| `workflow/bridge/filing_panels/add_year_to_confirmed_panel.py` | internal package tools | docstring |
| `workflow/bridge/filing_panels/audit_market_return.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/filing_panels/build_final.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/filing_panels/build_t11_t13_confirmed.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/filing_panels/build_t14.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/filing_panels/t11_design_diag_build.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/filing_panels/t11_three_definitions_build.py` | internal package src/downstream/sep_scratch | paths from placeholders; date windows and supplier file names from configuration; paper counts only with PAPER_CHECKS; unused do-file templating removed |
| `workflow/bridge/final_panels/prepare.py` | internal package src/downstream/ppml/prepare.py | panel construction only; comparison with diagnostic models removed |
| `workflow/bridge/recovery/build_recovered_inputs.py` | internal package compare_recovered61.py (as patched at run time) | construction steps only; diagnostics and manuscript/archived-result comparisons removed |
| `workflow/bridge/recovery/estimate_tables67.py` | internal package (as patched at run time) | reduced to the OLS helper and variable lists |
| `workflow/bridge/recovery/make_recovery_targets.py` | new | writes the recovery targets file (replaces embedded records) |
| `workflow/bridge/recovery/prepare_complete.py` | internal package src/downstream/recovered61_complete | run-time rewriting of other scripts removed; counts generalised (paper counts with PAPER_CHECKS) |
| `workflow/bridge/stata_exports/additional_01_price_revision.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/stata_exports/additional_01n_sharerevision_actual.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/stata_exports/additional_02_filing_proceeds.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/stata_exports/additional_03_completion_withdrawal.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/stata_exports/additional_03c_completion_industry_name_fallback.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/stata_exports/analysis.do` | internal package src/downstream/stata_exports | paths from placeholders; date window from configuration; paper counts only with PAPER_CHECKS; panel size as a formula; no network package install; a collaborator name removed from a comment |
| `workflow/bridge/ws2_panels/audit_extra999.py` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/bridge/ws2_panels/restore_ws2_61.py` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/bridge/ws2_panels/table11_nominal_comparison.do` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/bridge/ws2_panels/table11_quarter_month.do` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/bridge/ws2_panels/tables12_13_estimate.do` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/bridge/ws2_panels/tables12_13_prepare.do` | internal package src/downstream/ws2a | paths from placeholders; date windows from configuration; paper counts only with PAPER_CHECKS; the template step that used a private do-file removed |
| `workflow/check_wrds_connection.sh` | new | entry point for the WRDS connection check |
| `workflow/config/workflow_config.example.sh` | new | example configuration |
| `workflow/examples/make_synthetic_analysis_inputs.py` | new | synthetic analysis datasets |
| `workflow/python/build_sdc_industry_crosswalk.py` | internal package src/python | run folder from placeholder |
| `workflow/python/parse_sdc_fullhistory.py` | internal package src/python | unchanged |
| `workflow/requirements.txt` | new | workflow Python environment |
| `workflow/run_analysis.sh` | new | entry point: analysis only |
| `workflow/run_workflow.sh` | new | entry point: full workflow |
| `workflow/sas/common/ff30_mapping.sas` | internal package src/sas/common | unchanged |
| `workflow/sas/external/T11_T13_Export_Industry_Coskewness.sas` | internal package src/sas/external | CRSP date window from configuration |
| `workflow/sas/external/WRDS_Recovered61.sas` | internal package src/sas/external | embedded deal records and expected values replaced by a generated targets file; structure check generalised; dates from configuration |
| `workflow/sas/inputs_for_07b/02b_refresh_crsp_monthly_ret.sas` | internal package src/sas/inputs_for_07b | CRSP date window from configuration |
| `workflow/sas/inputs_for_07b/04e_repair_industry_return_controls.sas` | internal package src/sas/inputs_for_07b | CRSP date window from configuration |
| `workflow/sas/paths.sas` | internal package src/config/paths.sas | example path in a comment |
| `workflow/sas/stages/01_stage1_sdc_cleaning.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/01b_stage1_sdc_all_filings_cleaning.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/02_stage1_wrds_crsp_linking.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/02c_stage1_all_filings_industry_linking.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/03_stage1_underwriter_matching.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/04_stage1_final_sample.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/04d_additional_controls.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/05_stage2_skewness_coskewness.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/05b_stage2_price_revision.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/06_stage2_ipo_returns.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/06b_documented_exclusion_society_pass.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/07b_stage2_filing_quarter_panel.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sas/stages/07c_stage2_completion_withdrawal.sas` | internal package src/sas/stages | dates and supplier file names are configuration placeholders; 01b import range open-ended (same records for the paper's export); 06b switchable and labelled paper-specific; 06: record-level comment removed from an inactive (commented-out) diagnostic; 04d/05: collaborator names and an internal request note removed from comments |
| `workflow/sdc_settings/IPO project.sdcs` | the project's SDC settings files | report files unchanged; in the two search files the linked report path was reduced to the file name and the desktop session token cleared |
| `workflow/sdc_settings/README.md` | new | SDC settings: export mapping, export layout, reference inputs |
| `workflow/sdc_settings/SDC_all_filings_1975_2024_20260812.sdcs` | the project's SDC settings files | report files unchanged; in the two search files the linked report path was reduced to the file name and the desktop session token cleared |
| `workflow/sdc_settings/datacollection.sdcrpt` | the project's SDC settings files | report files unchanged; in the two search files the linked report path was reduced to the file name and the desktop session token cleared |
| `workflow/sdc_settings/sdc_all_filings_report_20260812.sdcrpt` | the project's SDC settings files | report files unchanged; in the two search files the linked report path was reduced to the file name and the desktop session token cleared |
| `workflow/sdc_settings/sdc_all_filings_report_20260903.sdcrpt` | the project's SDC settings files | report files unchanged; in the two search files the linked report path was reduced to the file name and the desktop session token cleared |
| `workflow/tools/check_outputs.py` | new | structural checks for any sample |
| `workflow/tools/make_tables.sh` | internal package tools/make_tables.sh | neutral Word file name; structural checks instead of paper benchmarks; SAS median test through run_sas.sh |
| `workflow/tools/materialise.py` | new | fills configuration placeholders in run copies |
| `workflow/tools/run_sas.sh` | new | SAS launch with exit-status and log checks |
| `workflow/tools/runstata.sh` | internal package tools | unchanged |
| `workflow/tools/wrds_connection_check.sas` | new | WRDS server sign-on and library check |

## Removed from the repository's committed files

The historical SAS/Stata snapshot is replaced by the current workflow (one current implementation):

- `src/sas/00_config.sas`
- `src/sas/01_stage1_sdc_cleaning.sas`
- `src/sas/02_stage1_wrds_crsp_linking.sas`
- `src/sas/03_stage1_underwriter_matching.sas`
- `src/sas/04_stage1_final_sample.sas`
- `src/sas/05_stage2_skewness_coskewness.sas`
- `src/sas/06_stage2_ipo_returns.sas`
- `src/sas/09_documentation_sample_log.sas`
- `src/sas/README.md`
- `src/stata/Appendix B.do`
- `src/stata/README.md`
- `src/stata/Table 3_additional controls.do`
- `src/stata/analysis.do`

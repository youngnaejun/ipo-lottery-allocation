#!/bin/sh
# Public research workflow: your authorised supplier exports -> SAS data construction -> bridge to the four
# table-input (analysis) datasets -> Tables 1-7, B1-B4, IA1-IA3 (Stata, SAS median test, Word) -> structural checks.
#
# Usage:  workflow/run_workflow.sh <config.sh> <run_root> [stage ...]
#   <config.sh>  your copy of workflow/config/workflow_config.example.sh
#   <run_root>   new, empty folder outside any synced drive (several GB; see README.md)
#   stages       any of: inputs sas external bridge tables word check   (default: all, in this order)
# Run from Git Bash on Windows. Every script is copied into <run_root>/code with its @SETTING@ placeholders
# filled in from <config.sh> (tools/materialise.py); the copies are what runs.
set -e
WF=$(cd "$(dirname "$0")" && pwd)
CONFIG=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); shift
ROOT="$1"; shift || true
[ -f "$CONFIG" ] && [ -n "$ROOT" ] || { echo "usage: workflow/run_workflow.sh <config.sh> <run_root> [stages]"; exit 2; }
. "$CONFIG"
STAGES="${*:-inputs sas external bridge tables word check}"
mkdir -p "$ROOT"; ROOT=$(cd "$ROOT" && pwd); ROOTW=$(cygpath -w "$ROOT")
pyx() { "$PYTHON_EXE" -B "$@"; }   # Python from the configuration (path may contain spaces)
export STATA_EXE
export IPO_ROOT="$ROOTW" IPO_SRC="$(cygpath -w "$ROOT/code")" IPO_CONFIG="$(cygpath -w "$WF/sas/paths.sas")" \
       IPO_WRDS_MODE="$WRDS_MODE" IPO_WRDS_DATA="$WRDS_DATA"
mkdir -p "$ROOT/raw/reference" "$ROOT/master" "$ROOT/output" "$ROOT/stata" "$ROOT/logs" "$ROOT/ext/sep21_25" "$ROOT/code" "$ROOT/sas"
has() { case " $STAGES " in *" $1 "*) return 0;; *) return 1;; esac; }
log() { echo "$(date -Iseconds) $*" >> "$ROOT/logs/run_order.txt"; echo "== $*"; }
mat() { pyx "$WF/tools/materialise.py" "$CONFIG" "$ROOTW" "$1" "$2"; }   # mat <source> <run copy>

export SAS_EXE
sas() {  # sas <path under code/sas>: run one materialised SAS program; stop unless it finished cleanly
  b=$(basename "$1" .sas); start=$(date -Iseconds)
  case "$b" in   # programs that redirect part of their log with PROC PRINTTO
    01b_*|02c_*|07c_*) extra="$ROOT/output/$b.log" ;;
    *) extra="" ;;
  esac
  SAS_EXTRA_LOGS="$extra" "$WF/tools/run_sas.sh" "$ROOT/code/sas/$1" "$ROOT/logs/$b.log" "$ROOT/logs/$b.lst" ||
    { echo "$start $(date -Iseconds) FAILED $1" >> "$ROOT/logs/run_order.txt"; exit 1; }
  echo "$start $(date -Iseconds) completed $1" >> "$ROOT/logs/run_order.txt"
}
stata() { "$WF/tools/runstata.sh" "$@"; }

# Materialise all SAS programs (also needed as code text by two bridge scripts).
for f in $(cd "$WF/sas" && find stages inputs_for_07b external common -name '*.sas'); do mat "$WF/sas/$f" "$ROOT/code/sas/$f"; done
cp -p "$ROOT"/code/sas/stages/*.sas "$ROOT/sas/"

if has inputs; then
  log "stage inputs: copy your supplier exports into the run folder"
  for f in "$SDC_IPO_FILE" "$SDC_ALL_FILINGS_FILE" "$SDC_FULL_HISTORY_FILE" UMCSENT.csv ipo_age_clean.csv sentiment_clean.csv \
           underwriter_clean.csv reference/census_sic88_97.txt; do
    [ -f "$INPUT_DIR/$f" ] || { echo "Missing input: $INPUT_DIR/$f (see docs/data_acquisition.md)"; exit 1; }
    cp -p "$INPUT_DIR/$f" "$ROOT/raw/$f"
  done
fi

if has sas; then
  log "stage sas: data construction"
  for p in stages/01_stage1_sdc_cleaning stages/02_stage1_wrds_crsp_linking stages/03_stage1_underwriter_matching \
           stages/04_stage1_final_sample stages/05_stage2_skewness_coskewness stages/06_stage2_ipo_returns \
           stages/06b_documented_exclusion_society_pass stages/04d_additional_controls stages/05b_stage2_price_revision \
           inputs_for_07b/02b_refresh_crsp_monthly_ret inputs_for_07b/04e_repair_industry_return_controls \
           stages/01b_stage1_sdc_all_filings_cleaning stages/02c_stage1_all_filings_industry_linking \
           stages/07b_stage2_filing_quarter_panel stages/07c_stage2_completion_withdrawal; do
    sas "$p.sas"
  done
fi

if has external; then
  log "stage external: SDC Full History parser, industry-quarter coskewness export"
  pyx "$WF/python/parse_sdc_fullhistory.py" --input "$ROOT/raw/$SDC_FULL_HISTORY_FILE" --sheet "$SDC_FULL_HISTORY_SHEET" \
      --output "$ROOT/stata/sdc_fullhistory_parsed_20260903.csv"
  sas external/T11_T13_Export_Industry_Coskewness.sas
fi

if has bridge; then
  log "stage bridge: Stata exports, filing panels, controls, recovered IPOs, -100% correction, final panels"
  B="$WF/bridge"; mkdir -p "$ROOT/stata_output/additional_tests/completion_industry_crosswalk" "$ROOT/code/stata" "$ROOT/code/python"
  # 1. Stata copies of the SAS master datasets (+ do-file derived variables) and the SDC industry crosswalk.
  for f in analysis additional_01_price_revision additional_02_filing_proceeds additional_03_completion_withdrawal \
           additional_01n_sharerevision_actual additional_03c_completion_industry_name_fallback; do
    mat "$B/stata_exports/$f.do" "$ROOT/code/stata/$f.do"
  done
  for f in analysis additional_01_price_revision additional_02_filing_proceeds additional_03_completion_withdrawal \
           additional_01n_sharerevision_actual; do
    log "stata $f"; stata "$ROOT/code/stata" "$f.do"
  done
  mat "$WF/python/build_sdc_industry_crosswalk.py" "$ROOT/code/python/build_sdc_industry_crosswalk.py"
  log "python build_sdc_industry_crosswalk"; (cd "$ROOT/code/python" && pyx build_sdc_industry_crosswalk.py > crosswalk.out)
  log "stata additional_03c"; stata "$ROOT/code/stata" additional_03c_completion_industry_name_fallback.do

  # 2. Completed-IPO filing-quarter panels and the filing-link recovery rule.
  E="$ROOT/ext/ipo-ws2a-tables-20260914"; mkdir -p "$E"
  for f in table11_quarter_month.do table11_nominal_comparison.do tables12_13_prepare.do tables12_13_estimate.do \
           audit_extra999.py restore_ws2_61.py; do mat "$B/ws2_panels/$f" "$E/$f"; done
  for f in table11_quarter_month table11_nominal_comparison tables12_13_prepare tables12_13_estimate; do
    log "stata $f"; stata "$E" "$f.do"
  done
  log "python audit_extra999"; (cd "$E" && pyx audit_extra999.py > audit_extra999.out)
  log "python restore_ws2_61"; (cd "$E" && pyx restore_ws2_61.py > restore.out)
  mkdir -p "$ROOT/ext/shared_root/20260914-18/workstream 2" "$ROOT/ext/ws2_shared"
  for f in ws2_eligible8905_deals_20260917.dta ws2_quarterly_recovered61_20260917.dta; do
    cp -p "$E/$f" "$ROOT/ext/shared_root/20260914-18/workstream 2/"; cp -p "$E/$f" "$ROOT/ext/ws2_shared/"
  done

  # 3. Table 4 panel, all-filings Table 5 panel, market-return control.
  S="$ROOT/ext/ipo-20260921-25"; mkdir -p "$S/t14filing_final" "$S/market_return_candidate_audit" "$S/fe_ladder_20260924"
  for f in t11_three_definitions_build.py build_t11_t13_confirmed.py build_t14.py t11_design_diag_build.py; do
    mat "$B/filing_panels/$f" "$S/$f"; done
  mat "$B/filing_panels/build_final.py" "$S/t14filing_final/build_final.py"
  mat "$B/filing_panels/audit_market_return.py" "$S/market_return_candidate_audit/audit_market_return.py"
  cp -p "$ROOT/ext/sep21_25/industry_quarter_coskewness.csv" "$S/industry_quarter_coskewness.csv"
  log "python t11_three_definitions_build"; (cd "$S" && pyx t11_three_definitions_build.py > l5_01.out)
  log "python build_t11_t13_confirmed"; (cd "$S" && pyx build_t11_t13_confirmed.py > l5_02.out)
  log "python add_year_to_confirmed_panel"; (cd "$S" && pyx "$B/filing_panels/add_year_to_confirmed_panel.py" t11_t13_confirmed_panel.dta t11_yearfe_confirmed.dta)
  log "python build_t14"; (cd "$S" && pyx build_t14.py > l5_03.out)
  log "python t11_design_diag_build"; (cd "$S" && pyx t11_design_diag_build.py > l5_04.out)
  log "python build_final"; (cd "$S/t14filing_final" && pyx build_final.py > build_final.out)
  cp -p "$S/t14filing_final/T14_Filing_Panel_20260924.dta" "$S/t14filing_final/T14_Audit.json" "$S/fe_ladder_20260924/"
  log "python audit_market_return"; (cd "$S/market_return_candidate_audit" && pyx audit_market_return.py > amr.out)

  # 4. Table 5 all-filer controls and the recovered IPOs' IPO-level variables.
  X="$ROOT/ext/0928-1002"; mkdir -p "$X/code" "$X/inputs" "$X/results/table1"
  for f in audit_all_filer_controls audit_additional_filer_controls estimate_all_filer_comparison estimate_table5_expanded \
           audit_recovered61 estimate_table4; do mat "$B/controls/$f.py" "$X/code/$f.py"; done
  cp -p "$S/market_return_candidate_audit/T4_Panel_With_Candidate_20260925.dta" "$S/market_return_candidate_audit/T5_Panel_With_Candidate_20260925.dta" "$X/inputs/"
  cp -p "$ROOT/stata/price_revision_sample.dta" "$ROOT/stata/sharerevision_actual.dta" "$X/inputs/"
  for f in audit_all_filer_controls audit_additional_filer_controls estimate_all_filer_comparison estimate_table5_expanded; do
    log "python $f"; (cd "$X/code" && pyx $f.py > $f.out)
  done
  log "python make_recovered61_list"
  mat "$B/controls/make_recovered61_list.py" "$ROOT/code/python/make_recovered61_list.py"
  pyx "$ROOT/code/python/make_recovered61_list.py" "$E/extra999_link_audit_20260917.json" "$X/results/table1/Recovered61_audit_records.csv"

  # 5. Returns and coskewness of the recovered IPOs (WRDS), then their complete variables.
  RC="$ROOT/ext/recovered61-complete"; mkdir -p "$RC/results" "$ROOT/ext/recovery"
  mat "$B/recovery/make_recovery_targets.py" "$ROOT/code/python/make_recovery_targets.py"
  log "python make_recovery_targets"; pyx "$ROOT/code/python/make_recovery_targets.py"
  rm -rf "$ROOT/ext/recovered61-wrds"; sas external/WRDS_Recovered61.sas
  W61=$(ls -d "$ROOT"/ext/recovered61-wrds/run_* 2>/dev/null | head -1)
  [ -n "$W61" ] || { echo "Stopping: WRDS_Recovered61.sas wrote no output folder"; exit 1; }
  # The program redirects its log to client_run.log (local) and run.log (remote session): both must be clean.
  for x in "$W61/client_run.log" "$W61/run.log"; do
    [ -s "$x" ] || { echo "Stopping: recovery log missing or empty: $x"; exit 1; }
    if grep -q '^ERROR' "$x"; then grep -n -m 5 '^ERROR' "$x"; echo "Stopping: ERROR line(s) in $x"; exit 1; fi
  done
  cp -p "$W61"/* "$ROOT/ext/recovered61-wrds/"
  log "python audit_recovered61"; (cd "$X/code" && pyx audit_recovered61.py > audit_recovered61.out)
  for f in prepare_complete.py build_recovered_inputs.py estimate_tables67.py; do mat "$B/recovery/$f" "$RC/$f"; done
  mat "$B/controls/estimate_table4.py" "$RC/estimate_table4.py"
  log "python prepare_complete"; (cd "$RC" && pyx prepare_complete.py > prepare_complete.out)
  log "python build_recovered_inputs"; (cd "$RC" && pyx build_recovered_inputs.py > build_recovered_inputs.out)

  # 6. -100% (total-loss) correction of the long-run returns, then the final Table 4/5 panels.
  BD="$ROOT/ext/boundary"; mkdir -p "$BD"
  for f in compare.py extract.sas extract_local.sas extract_wrds.sas make_boundary_targets.py; do mat "$B/boundary/$f" "$BD/$f"; done
  log "python make_boundary_targets"; pyx "$BD/make_boundary_targets.py" "$RC/results/Expanded_analysis.pkl" "$BD/targets.csv"
  log "sas total-loss extract (CRSP dsf/dsedelist; WRDS_MODE=$WRDS_MODE)"
  (cd "$BD" && "$WF/tools/run_sas.sh" "$BD/extract.sas" "$BD/extract.log" "$BD/extract.lst") || exit 1
  log "python boundary correction"; (cd "$BD" && pyx compare.py > compare.out)
  mkdir -p "$ROOT/ext/ppml"; mat "$B/final_panels/prepare.py" "$ROOT/ext/ppml/prepare.py"
  log "python final panels"; (cd "$ROOT/ext/ppml" && pyx prepare.py > prepare.out)
fi

if has tables; then
  log "stage tables: table-input datasets, Stata tables, Table 2 median test (SAS)"
  pyx "$WF/analysis/export_stata_inputs.py" "$ROOTW\\stata_tables\\data" "$ROOTW"
  "$WF/tools/make_tables.sh" "$CONFIG" "$ROOT/stata_tables/data" "$ROOT/stata_tables/out" tables
fi
if has word; then
  log "stage word: Word table file"
  "$WF/tools/make_tables.sh" "$CONFIG" "$ROOT/stata_tables/data" "$ROOT/stata_tables/out" word
fi
if has check; then
  log "stage check: structural checks"
  "$WF/tools/make_tables.sh" "$CONFIG" "$ROOT/stata_tables/data" "$ROOT/stata_tables/out" check
fi
log "finished stages: $STAGES"

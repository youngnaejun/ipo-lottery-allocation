#!/bin/sh
# Table step: table-input datasets -> Stata tables + Table 2 median t (SAS) -> Word file -> structural checks.
# Called by workflow/run_workflow.sh and workflow/run_analysis.sh.
#
# Usage: tools/make_tables.sh <config.sh> <data_dir> <out_dir> [tables] [word] [check]   (default: all three)
#   <data_dir>  folder holding ipo_returns.dta, revisions.dta, t4_panel.dta, t5_panel.dta
set -e
WF=$(cd "$(dirname "$0")/.." && pwd)
CONFIG=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); . "$CONFIG"
export STATA_EXE SAS_EXE
pyx() { "$PYTHON_EXE" -B "$@"; }   # Python from the configuration (path may contain spaces)
DATA=$(cd "$2" && pwd); mkdir -p "$3"; OUT=$(cd "$3" && pwd); shift 3
STEPS="${*:-tables word check}"
DATAW=$(cygpath -w "$DATA"); OUTW=$(cygpath -w "$OUT")
has() { case " $STEPS " in *" $1 "*) return 0;; *) return 1;; esac; }

if has tables; then
  echo "== tables: Stata (analysis/do/00_master.do), then the Table 2 median t-statistic (SAS)"
  RUNSTATA_LOGDIR="$OUT" "$WF/tools/runstata.sh" "$WF/analysis/do" 00_master.do "$DATAW" "$OUTW"
  pyx -c "import pandas as pd,sys; pd.read_stata(sys.argv[1])[['analysis_id','ipo_year','skew1','r0']].to_csv(sys.argv[2],index=False)" \
      "$DATAW\\ipo_returns.dta" "$OUTW\\ipo_returns_t2.csv"
  rm -f "$OUT/table2_median_params.csv"
  "$WF/tools/run_sas.sh" "$WF/analysis/sas/table2_median_t.sas" "$OUT/table2_median_t.log" "" -- \
      -set INCSV "$OUTW\\ipo_returns_t2.csv" -set OUTCSV "$OUTW\\table2_median_params.csv" || exit 1
  [ -s "$OUT/table2_median_params.csv" ] || { echo "Stopping: the median test wrote no results"; exit 1; }
fi
if has word; then
  echo "== word: Word table file"
  pyx "$WF/analysis/build_word_tables.py" "$OUT" "$WF/analysis/table_text.json" "$OUT/ipo_tables.docx"
fi
if has check; then
  echo "== check: structural checks (no paper-specific values)"
  pyx "$WF/tools/check_outputs.py" "$DATA" "$OUT" "$WF/analysis/table_input_schema.json"
fi

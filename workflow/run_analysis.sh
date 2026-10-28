#!/bin/sh
# Analysis only: your own four table-input datasets -> Tables 1-7, B1-B4, IA1-IA3 (Stata results, Word file)
#   -> structural checks. Use this when you have built ipo_returns.dta, revisions.dta, t4_panel.dta and
#   t5_panel.dta yourself (with run_workflow.sh or otherwise) following docs/input_schemas.md.
#
# Usage:  workflow/run_analysis.sh <config.sh> <data_dir> <out_dir> [tables] [word] [check]
set -e
WF=$(cd "$(dirname "$0")" && pwd)
"$WF/tools/make_tables.sh" "$@"

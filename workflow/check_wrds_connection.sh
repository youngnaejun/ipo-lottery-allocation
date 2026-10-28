#!/bin/sh
# Check the WRDS server route before a full run with WRDS_MODE="wrds".
#
# Usage:  workflow/check_wrds_connection.sh <config.sh> <log_folder>
# SAS opens the WRDS sign-on (signon username=_prompt_) and asks for your WRDS user name and password;
# type them into SAS. They are not passed through this script or stored anywhere. Some SAS installations do
# not show the prompt in batch mode; in that case run workflow/tools/wrds_connection_check.sas from an
# interactive SAS session with the same environment variables (IPO_CONFIG, IPO_WRDS_MODE=wrds).
set -e
WF=$(cd "$(dirname "$0")" && pwd)
CONFIG=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); . "$CONFIG"
mkdir -p "$2"; OUT=$(cd "$2" && pwd)
export SAS_EXE IPO_ROOT="$(cygpath -w "$OUT")" IPO_SRC="$(cygpath -w "$WF")" \
       IPO_CONFIG="$(cygpath -w "$WF/sas/paths.sas")" IPO_WRDS_MODE=wrds IPO_WRDS_DATA="$WRDS_DATA"
mkdir -p "$OUT/raw" "$OUT/master" "$OUT/output"
"$WF/tools/run_sas.sh" "$WF/tools/wrds_connection_check.sas" "$OUT/wrds_connection_check.log" "$OUT/wrds_connection_check.lst"

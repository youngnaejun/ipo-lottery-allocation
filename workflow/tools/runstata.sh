#!/bin/sh
# Usage: runstata.sh <do_dir_posix> <file.do> [args...]
# Runs Stata in batch (/e) through a wrapper _run_<file>.do that changes to <do_dir> first, so the batch log
# never collides with the do-file's own "log using <file>.log". The wrapper and batch log are written to
# $RUNSTATA_LOGDIR when set (run_all.sh points it into the run root), otherwise to <do_dir>.
# Requires STATA_EXE (Windows path), exported by run_all.sh and tools/make_tables.sh.
D="$1"; F="$2"; shift 2
B=$(basename "$F" .do)
L="${RUNSTATA_LOGDIR:-$D}"; mkdir -p "$L"
printf 'cd "%s"\ndo "%s" %s\n' "$(cygpath -w "$D")" "$F" "$*" > "$L/_run_$B.do"
LW=$(cygpath -w "$L")
start=$(date -Iseconds)
rm -f "$L/_run_$B.log"
powershell -NoProfile -Command "\$p=Start-Process -FilePath '$STATA_EXE' -ArgumentList '/e','do','_run_$B.do' -WorkingDirectory '$LW' -PassThru -Wait; exit \$p.ExitCode"
rc=$?
echo "$start $(date -Iseconds) rc=$rc $D/$F $*" >> "$L/stata_run_order.txt"
# A failed launch can still return 0 from PowerShell, so also require the batch log.
[ "$rc" -eq 0 ] && [ -f "$L/_run_$B.log" ] || { echo "Stopping: Stata did not run $D/$F (rc=$rc; check STATA_EXE)"; exit 1; }
n=$(grep -c -E '^r\([0-9]+\);' "$L/_run_$B.log" 2>/dev/null || true)
echo "rc=$rc  Stata errors r(...): ${n:-0}  ($B)"
grep -n -B4 -E '^r\([0-9]+\);' "$L/_run_$B.log" | head -24
[ "${n:-0}" -eq 0 ] || { echo "Stopping: Stata error in $D/$F; see $L/_run_$B.log"; exit 1; }

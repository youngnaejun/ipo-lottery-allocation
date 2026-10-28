#!/bin/sh
# Run one SAS program in batch and decide success from both the exit status and the log.
#
# Usage: tools/run_sas.sh <program.sas> <log> [listing] [-- extra SAS options ...]
#   Paths may be POSIX or Windows style. Requires SAS_EXE (exported by the runner).
#
# Success requires all of:
#   - SAS exit status 0 (no warnings) or 1 (warnings only; accepted explicitly and reported);
#     status 2 or higher (errors, ABORT, failed start) stops the run;
#   - a new, non-empty log: any old log is removed before the run, so a stale log cannot pass;
#   - SAS's end-of-session note in the log (a truncated log means the session did not finish);
#   - no line starting with ERROR in the log.
# Programs that redirect part of their log with PROC PRINTTO name those logs in SAS_EXTRA_LOGS
# (";"-separated POSIX paths): each is removed before the run and must afterwards exist, be non-empty and
# contain no ERROR line.
PROG="$1"; LOG="$2"; LST="$3"; shift 3 2>/dev/null || shift $#
[ "$1" = "--" ] && shift
[ -n "$PROG" ] && [ -n "$LOG" ] || { echo "usage: run_sas.sh <program.sas> <log> [listing] [-- options]"; exit 2; }
win() { case "$1" in /*) cygpath -w "$1";; *) printf '%s' "$1";; esac; }
rm -f "$LOG"
[ -n "$LST" ] && rm -f "$LST"
OLDIFS=$IFS; IFS=';'; for x in $SAS_EXTRA_LOGS; do [ -n "$x" ] && rm -f "$x"; done; IFS=$OLDIFS
if [ -n "$LST" ]; then
  "$SAS_EXE" -sysin "$(win "$PROG")" -log "$(win "$LOG")" -print "$(win "$LST")" -nosplash -noicon -batch -noautoexec "$@"
else
  "$SAS_EXE" -sysin "$(win "$PROG")" -log "$(win "$LOG")" -nosplash -noicon -batch -noautoexec "$@"
fi
rc=$?
name=$(basename "$PROG")
fail() { echo "Stopping: $name - $1"; exit 1; }
[ -s "$LOG" ] || fail "no SAS log was written (exit status $rc; check SAS_EXE and the program path)"
n=$(grep -c '^ERROR' "$LOG")
if [ "$n" -gt 0 ]; then
  grep -n -m 5 '^ERROR' "$LOG"
  fail "$n ERROR line(s) in $LOG (exit status $rc)"
fi
grep -q 'NOTE: The SAS System used:' "$LOG" || fail "the log has no end-of-session note; SAS did not finish (exit status $rc): $LOG"
OLDIFS=$IFS; IFS=';'
for x in $SAS_EXTRA_LOGS; do
  [ -n "$x" ] || continue
  [ -s "$x" ] || { IFS=$OLDIFS; fail "redirected log missing or empty: $x"; }
  if grep -q '^ERROR' "$x"; then IFS=$OLDIFS; grep -n -m 5 '^ERROR' "$x"; fail "ERROR line(s) in redirected log $x"; fi
done
IFS=$OLDIFS
case "$rc" in
  0) echo "SAS ok: $name" ;;
  1) echo "SAS ok with warnings (exit status 1): $name; see $LOG" ;;
  *) fail "SAS exit status $rc: $LOG" ;;
esac

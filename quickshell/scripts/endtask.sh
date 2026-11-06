#!/bin/sh
# Ends processes politely: SIGTERM (never SIGKILL) to the pids given, for the launcher's "kill <name>" rows.
#   endtask.sh <pid> [<pid> ...]
# Every argument must be a plain integer above 1 (-1 would signal everything you own, 0 your process group, 1 is init),
# otherwise nothing is signalled and it exits 2. Only your own processes are signalled (the owner of /proc/<pid> must be
# you); a pid that is gone or not yours is skipped with a note on stderr. Its own pid and its parent's are never signalled.
# The signal goes out through the external `kill` found on PATH (`env kill`), pids as separate arguments after `--`.
# ENDTASK_PROCDIR overrides /proc for tests.
proc=${ENDTASK_PROCDIR:-/proc}

[ "$#" -gt 0 ] || { echo "usage: endtask.sh <pid> [<pid> ...]" >&2; exit 2; }

for p in "$@"; do
    case $p in
        ''|*[!0-9]*|0?*) echo "endtask.sh: not a pid: $p" >&2; exit 2 ;;
    esac
    # no leading zeros (octal games); 0 and 1 are refused
    [ "$((p + 0))" -gt 1 ] 2>/dev/null || { echo "endtask.sh: not a usable pid: $p" >&2; exit 2; }
done

ok=
for p in "$@"; do
    n=$((p + 0))
    if [ "$n" -eq "$$" ] || [ "$n" -eq "$PPID" ]; then
        echo "endtask.sh: skipped $n (this helper or its parent)" >&2
        continue
    fi
    if [ ! -O "$proc/$n" ]; then
        echo "endtask.sh: skipped $n (gone, or not yours)" >&2
        continue
    fi
    ok="$ok $n"
done

[ -n "$ok" ] || exit 1
# shellcheck disable=SC2086
exec env kill -s TERM -- $ok

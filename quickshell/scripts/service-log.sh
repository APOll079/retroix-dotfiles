#!/bin/sh
# Last 40 lines of a user dinit service's buffered log, for the Services panel's Log view.
#   service-log.sh <name>
# Runs `dinitctl --user catlog <name>`. Exit 2: bad or missing name (only A-Z a-z 0-9 . _ @ - allowed, so
# nothing odd reaches dinitctl) or dinitctl not installed. Otherwise dinitctl's exit status; output may be
# empty when the service has no log-type = buffer.
name=$1
case $name in
    '' | *[!A-Za-z0-9._@-]*)
        echo "service-log: bad service name" >&2
        exit 2
        ;;
esac
case $name in
    -*)
        echo "service-log: bad service name" >&2
        exit 2
        ;;
esac
command -v dinitctl >/dev/null 2>&1 || {
    echo "service-log: dinitctl not found" >&2
    exit 2
}
out=$(dinitctl --user catlog "$name")
rc=$?
[ -n "$out" ] && printf '%s\n' "$out" | tail -n 40
exit "$rc"

#!/bin/sh
# Network checks for NetworkWatch.qml. Every argument is one argv word, never spliced into script text.
#   net-check.sh --link          prints {"state":"connected"} : first word of `nmcli -t -f STATE g`
#                                (connected, disconnected, connecting, asleep, unknown ...); the same command the bar's
#                                ETH indicator runs. A missing nmcli prints {"state":"unknown"} and exits 2.
#   net-check.sh <host...>       prints [{"host":"h","up":true}, ...] in argument order, one `ping -c1 -W2` per host,
#                                all in parallel. A host may only hold letters digits . : - and must not start with -;
#                                anything else is not pinged and prints {"host":"...","up":false,"invalid":true}.
# A missing ping exits 2 with one line on stderr.

esc() {
    printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

valid() {
    case "$1" in
        "" | -* | *[!A-Za-z0-9.:-]*) return 1 ;;
    esac
    return 0
}

if [ "$1" = "--link" ]; then
    command -v nmcli >/dev/null 2>&1 || { echo '{"state":"unknown"}'; exit 2; }
    s=$(nmcli -t -f STATE g 2>/dev/null | head -n 1 | cut -d' ' -f1 | tr -cd 'a-z')
    printf '{"state":"%s"}\n' "${s:-unknown}"
    exit 0
fi

[ "$#" -eq 0 ] && { echo "usage: net-check.sh --link | <host...>" >&2; exit 2; }
command -v ping >/dev/null 2>&1 || { echo "ping is not installed" >&2; exit 2; }

dir=$(mktemp -d) || exit 1
trap 'rm -rf "$dir"' EXIT
i=0
for h in "$@"; do
    i=$((i + 1))
    if valid "$h"; then
        ( ping -c1 -W2 -- "$h" >/dev/null 2>&1 && echo 1 >"$dir/$i" || echo 0 >"$dir/$i" ) &
    else
        echo x >"$dir/$i"
    fi
done
wait
i=0
sep=""
printf '['
for h in "$@"; do
    i=$((i + 1))
    r=$(cat "$dir/$i" 2>/dev/null)
    case "$r" in
        1) printf '%s{"host":"%s","up":true}' "$sep" "$(esc "$h")" ;;
        0) printf '%s{"host":"%s","up":false}' "$sep" "$(esc "$h")" ;;
        *) printf '%s{"host":"%s","up":false,"invalid":true}' "$sep" "$(esc "$h")" ;;
    esac
    sep=","
done
printf ']\n'

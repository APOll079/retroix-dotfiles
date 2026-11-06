#!/bin/sh
# Disk usage of the given mounts, as JSON for DiskWatch.qml.
#   disk-usage.sh <mount> [<mount> ...]
# Prints [{"mount":"/","usedPercent":93,"size":1000,"used":930,"status":"ok"}, ...] (bytes). Only `df` output is
# read: no directory is listed and no file is opened. Each mount is read with `timeout 3 df -P -B1 -- <mount>`
# (DISK_TIMEOUT overrides the 3 s for tests) so a hung NFS mount can't freeze the watcher.
# status: ok | unreachable (df timed out or failed) | missing (the path doesn't exist). For the last two
# usedPercent, size and used are null. A mount with a control character in its name is skipped.
limit=${DISK_TIMEOUT:-3}

esc() {
    # JSON string escape for \ and "
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# one mount: prints its JSON object
one() {
    m=$1
    err=$(mktemp "${TMPDIR:-/tmp}/disk-usage.XXXXXX") || return 1
    line=$(LC_ALL=C timeout "$limit" df -P -B1 -- "$m" 2>"$err" | tail -n 1)
    status=ok
    pct=null
    size=null
    used=null
    fs=''
    sz=''
    us=''
    av=''
    pc=''
    rest=''
    # no data line (df failed or timed out) leaves these empty
    read -r fs sz us av pc rest <<EOF
$line
EOF
    case $sz$us in
        '' | *[!0-9]*) sz='' ;;
    esac
    pc=${pc%\%}
    case $pc in
        '' | *[!0-9]*) pc='' ;;
    esac
    if [ -n "$sz" ] && [ -n "$pc" ]; then
        size=$sz
        used=$us
        pct=$pc
    elif grep -q 'No such file' "$err" 2>/dev/null; then
        status=missing
    else
        status=unreachable
    fi
    rm -f "$err"
    printf '{"mount":"%s","usedPercent":%s,"size":%s,"used":%s,"status":"%s"}' "$(esc "$m")" "$pct" "$size" "$used" "$status"
}

printf '['
sep=''
for m in "$@"; do
    case $m in
        '' | *[![:print:]]*) continue ;;
    esac
    printf '%s' "$sep"
    one "$m"
    sep=','
done
printf ']\n'

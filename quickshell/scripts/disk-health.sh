#!/bin/sh
# SMART health of the machine's disks, as JSON for DiskWatch.qml.
#   disk-health.sh
# Devices come from `lsblk -dn -o NAME,TYPE` (type disk only, names [a-z0-9]+ only); each is asked with
# `smartctl -H -j /dev/<name>`. Prints [{"dev":"sda","passed":true,"status":"ok"}, ...]
#   status ok         smartctl said passed (passed true)
#   status failed     smartctl said not passed (passed false)
#   status permission smartctl couldn't open the device: the text "Permission denied" or exit status 4 (passed null)
#   status missing    smartctl isn't installed, or gave no verdict (virtual disks like zram, USB bridges) (passed null)
# On permission the script retries once with `doas -n smartctl ...` (non-interactive: it works only with a
# nopass rule, see docs/desktop.md; without one it stays "permission").
# Only smartctl's verdict is read; no file or directory of the owner is touched. SMART_TIMEOUT (default 15 s)
# bounds each smartctl call.
limit=${SMART_TIMEOUT:-15}

have=1
command -v smartctl >/dev/null 2>&1 || have=0

devs=$(lsblk -dn -o NAME,TYPE 2>/dev/null | while read -r name type rest; do
    [ "$type" = disk ] || continue
    case $name in
        '' | *[!a-z0-9]*) continue ;;
    esac
    printf '%s\n' "$name"
done)

# sets passed / status from $res (smartctl's output) and the exit status in $1
classify() {
    passed=null
    status=missing
    if printf '%s' "$res" | grep -q 'Permission denied'; then
        status=permission
    elif printf '%s' "$res" | grep -q '"passed": *true'; then
        passed=true
        status=ok
    elif printf '%s' "$res" | grep -q '"passed": *false'; then
        passed=false
        status=failed
    elif [ "$1" = 4 ]; then
        status=permission
    fi
}

printf '['
sep=''
for dev in $devs; do
    passed=null
    status=missing
    if [ "$have" = 1 ]; then
        res=$(timeout "$limit" smartctl -H -j "/dev/$dev" 2>&1)
        classify $?
        # no permission: try a passwordless doas rule (`doas -n` never prompts), see docs/desktop.md
        if [ "$status" = permission ] && command -v doas >/dev/null 2>&1; then
            res=$(timeout "$limit" doas -n smartctl -H -j "/dev/$dev" 2>&1)
            classify $?
            # a refused doas is still "no permission"
            [ "$status" = missing ] && status=permission
        fi
    fi
    printf '%s{"dev":"%s","passed":%s,"status":"%s"}' "$sep" "$dev" "$passed" "$status"
    sep=','
done
printf ']\n'

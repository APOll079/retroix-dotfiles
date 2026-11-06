#!/bin/sh
# USB drives for UsbState.qml. Every argument is validated and passed as one argv word, never spliced into text.
#   usb.sh list          JSON [{dev, label, size, mountpoint|null, removable}] of partitions (or bare disks without
#                        partitions) of removable / usb-transport devices only; internal disks never appear
#   usb.sh mount <dev>   udisksctl mount -b /dev/<dev>; prints the mountpoint
#   usb.sh eject <dev>   udisksctl unmount -b /dev/<dev>, then udisksctl power-off -b /dev/<parent disk>
# <dev> is a kernel name like sdb1 (^[a-z0-9]+$, else exit 2). A missing tool exits 2 with one line on stderr;
# a failed udisksctl exits 1 with its first error line on stderr (shown in the toast).

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "$1 is not installed" >&2; exit 2; }
}

valid() {
    case "$1" in
        "" | *[!a-z0-9]*) echo "bad device name" >&2; exit 2 ;;
    esac
}

# First line of an error text, without the "Error mounting /dev/sdb1: " lead
oneline() {
    printf '%s\n' "$1" | sed -n '1{s/^Error [a-z]* *\/dev\/[a-z0-9]*: *//;p;q}'
}

# sdb1 -> sdb, mmcblk0p1 -> mmcblk0, nvme0n1p1 -> nvme0n1; a bare disk stays as it is
parent_of() {
    printf '%s\n' "$1" | sed -E 's/^(.*[0-9])p[0-9]+$/\1/; t; s/^((sd|vd|hd|xvd)[a-z]+)[0-9]+$/\1/'
}

PYFILTER='
import json, re, sys
def truthy(v):
    return v is True or str(v).lower() in ("1", "true")
def clean(s):
    return re.sub(r"[\x00-\x1f\x7f]", " ", str(s or "")).strip()
def mount_of(d):
    m = d.get("mountpoint")
    if not m:
        ms = [x for x in (d.get("mountpoints") or []) if x]
        m = ms[0] if ms else None
    return m or None
def size_of(d):
    try:
        return int(d.get("size") or 0)
    except (TypeError, ValueError):
        return 0
try:
    disks = json.load(sys.stdin)["blockdevices"]
except Exception:
    print("[]")
    sys.exit(0)
out = []
for d in disks if isinstance(disks, list) else []:
    if not isinstance(d, dict) or d.get("type") != "disk":
        continue
    if not (truthy(d.get("rm")) or str(d.get("tran") or "").lower() == "usb"):
        continue
    parts = [c for c in (d.get("children") or []) if isinstance(c, dict) and c.get("type") == "part"]
    for p in parts or [d]:
        name = str(p.get("name") or "")
        if not re.fullmatch(r"[a-z0-9]+", name):
            continue
        out.append({"dev": name, "label": clean(p.get("label")), "size": size_of(p), "mountpoint": mount_of(p), "removable": True})
print(json.dumps(out))
'

case "$1" in
list)
    need lsblk
    need python3
    raw=$(lsblk -J -b -o NAME,LABEL,SIZE,RM,TRAN,MOUNTPOINT,TYPE 2>/dev/null) || raw=""
    printf '%s\n' "$raw" | python3 -I -c "$PYFILTER"
    ;;
mount)
    valid "$2"
    need udisksctl
    out=$(udisksctl mount -b "/dev/$2" 2>&1) || {
        # already mounted: udisks says "... is already mounted at `/path'."
        at=$(printf '%s\n' "$out" | sed -n "s/.*already mounted at \`\\(.*\\)'.*/\\1/p" | head -n 1)
        if [ -n "$at" ]; then printf '%s\n' "$at"; exit 0; fi
        oneline "$out" >&2
        exit 1
    }
    printf '%s\n' "$out" | sed -n '1{s/^Mounted .* at //;s/\.$//;p;q}'
    ;;
eject)
    valid "$2"
    need udisksctl
    disk=$(parent_of "$2")
    out=$(udisksctl unmount -b "/dev/$2" 2>&1) || {
        case "$out" in
            *"not mounted"*) ;;
            *) oneline "$out" >&2; exit 1 ;;
        esac
    }
    out=$(udisksctl power-off -b "/dev/$disk" 2>&1) || { oneline "$out" >&2; exit 1; }
    ;;
*)
    echo "usage: usb.sh list | mount <dev> | eject <dev>" >&2
    exit 2
    ;;
esac

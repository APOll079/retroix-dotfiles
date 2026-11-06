#!/bin/sh
# Tests quickshell/scripts/usb.sh with fake lsblk and udisksctl on an isolated PATH (nothing real runs, no disks read).
# The fakes log their arguments to $LOG. Usage: sh tests/usb-script-test.sh   (prints PASS / FAIL lines, exit 1 on a failure)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
USB="$ROOT/quickshell/scripts/usb.sh"
W=$(mktemp -d "${TMPDIR:-/tmp}/usbtest.XXXXXX")
OLDPATH=$PATH
trap 'PATH=$OLDPATH; rm -rf "$W"' EXIT
mkdir "$W/bin"
LOG="$W/log"
fails=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2 / want: $3)"; fi; }

# fake lsblk prints $W/lsblk.json; fake udisksctl logs its arguments and answers from $W/udisks.*
cat > "$W/bin/lsblk" <<EOF
#!/bin/sh
echo "lsblk \$*" >> "$LOG"
cat "$W/lsblk.json"
EOF
cat > "$W/bin/udisksctl" <<EOF
#!/bin/sh
echo "udisksctl \$*" >> "$LOG"
case "\$1" in
    mount) cat "$W/udisks.mount.out"; exit \$(cat "$W/udisks.mount.rc") ;;
    unmount) cat "$W/udisks.unmount.out"; exit \$(cat "$W/udisks.unmount.rc") ;;
    power-off) cat "$W/udisks.off.out"; exit \$(cat "$W/udisks.off.rc") ;;
esac
EOF
chmod +x "$W/bin/lsblk" "$W/bin/udisksctl"
PY=$(command -v python3)
# python3 and the basic tools stay reachable through symlinks; lsblk / udisksctl come only from the fakes
for t in sh sed head tail cat printf grep tr wc rm; do p=$(command -v $t) && ln -s "$p" "$W/bin/$t"; done
ln -s "$PY" "$W/bin/python3"
export PATH="$W/bin"

cat > "$W/lsblk.json" <<'EOF'
{"blockdevices": [
 {"name":"nvme0n1","label":null,"size":1000204886016,"rm":false,"tran":"nvme","mountpoint":null,"type":"disk","children":[
   {"name":"nvme0n1p1","label":"EFI","size":536870912,"rm":false,"tran":null,"mountpoint":"/boot","type":"part"}]},
 {"name":"sda","label":null,"size":500107862016,"rm":false,"tran":"sata","mountpoint":null,"type":"disk","children":[
   {"name":"sda1","label":"data","size":500000000000,"rm":false,"tran":null,"mountpoint":"/mnt/data","type":"part"}]},
 {"name":"sdb","label":null,"size":16000000000,"rm":true,"tran":"usb","mountpoint":null,"type":"disk","children":[
   {"name":"sdb1","label":"STICK","size":15999000000,"rm":true,"tran":null,"mountpoint":null,"type":"part"},
   {"name":"sdb2","label":"Evil\u0007<b>x</b>\n$(id)","size":1000,"rm":true,"tran":null,"mountpoint":"/run/media/u/B","type":"part"}]},
 {"name":"sdc","label":"RAWDISK","size":8000000000,"rm":true,"tran":"usb","mountpoint":"/run/media/u/RAW","type":"disk"},
 {"name":"sr0","label":null,"size":1073741312,"rm":true,"tran":"sata","mountpoint":null,"type":"rom"},
 {"name":"mmcblk0","label":null,"size":32000000000,"rm":"1","tran":null,"mountpoint":null,"type":"disk","children":[
   {"name":"mmcblk0p1","label":"SD","size":32000000000,"rm":"1","tran":null,"mountpoint":null,"type":"part"}]}
]}
EOF
out=$(sh "$USB" list)
summary() { printf '%s' "$out" | python3 -I -c 'import json,sys; print(",".join(d["dev"] for d in json.load(sys.stdin)))'; }
check "list keeps only usb / removable partitions and bare disks" "$(summary)" "sdb1,sdb2,sdc,mmcblk0p1"
field() { printf '%s' "$out" | python3 -I -c 'import json,sys; d={x["dev"]:x for x in json.load(sys.stdin)}; print(json.dumps(d[sys.argv[1]][sys.argv[2]]))' "$1" "$2"; }
check "unmounted stick has mountpoint null" "$(field sdb1 mountpoint)" "null"
check "mounted stick keeps its mountpoint" "$(field sdc mountpoint)" '"/run/media/u/RAW"'
check "label is passed through" "$(field sdb1 label)" '"STICK"'
check "size is bytes" "$(field sdb1 size)" "15999000000"
check "hostile label has control characters removed" "$(field sdb2 label | grep -c '\\u0007')" "0"
check "no internal disk in the output" "$(printf '%s' "$out" | grep -c 'nvme\|sda')" "0"
check "lsblk was asked for the JSON columns" "$(head -n 1 "$LOG")" "lsblk -J -b -o NAME,LABEL,SIZE,RM,TRAN,MOUNTPOINT,TYPE"

echo "this is not json {" > "$W/lsblk.json"
check "junk lsblk output gives []" "$(sh "$USB" list)" "[]"
: > "$W/lsblk.json"
check "empty lsblk output gives []" "$(sh "$USB" list)" "[]"
echo '{"blockdevices": "nope"}' > "$W/lsblk.json"
check "wrong-shaped lsblk output gives []" "$(sh "$USB" list)" "[]"

# mount
: > "$LOG"
echo "Mounted /dev/sdb1 at /run/media/u/STICK." > "$W/udisks.mount.out"; echo 0 > "$W/udisks.mount.rc"
check "mount prints the mountpoint" "$(sh "$USB" mount sdb1)" "/run/media/u/STICK"
check "mount argv" "$(cat "$LOG")" "udisksctl mount -b /dev/sdb1"
echo "Error mounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.AlreadyMounted: Device /dev/sdb1 is already mounted at \`/run/media/u/STICK'." > "$W/udisks.mount.out"; echo 1 > "$W/udisks.mount.rc"
check "already mounted still prints the mountpoint" "$(sh "$USB" mount sdb1)" "/run/media/u/STICK"
echo "Error mounting /dev/sdb1: wrong fs type" > "$W/udisks.mount.out"
sh "$USB" mount sdb1 2> "$W/err"; rc=$?
check "mount failure exits 1" "$rc" "1"
check "mount failure message is one line" "$(cat "$W/err")" "wrong fs type"

# eject
: > "$LOG"
echo "" > "$W/udisks.unmount.out"; echo 0 > "$W/udisks.unmount.rc"; echo "" > "$W/udisks.off.out"; echo 0 > "$W/udisks.off.rc"
sh "$USB" eject sdb1; rc=$?
check "eject succeeds" "$rc" "0"
check "eject unmounts the partition then powers off the disk" "$(tr '\n' '|' < "$LOG")" "udisksctl unmount -b /dev/sdb1|udisksctl power-off -b /dev/sdb|"
: > "$LOG"; sh "$USB" eject mmcblk0p1; check "eject powers off mmcblk0 for mmcblk0p1" "$(tail -n 1 "$LOG")" "udisksctl power-off -b /dev/mmcblk0"
: > "$LOG"; sh "$USB" eject sdc; check "eject of a bare disk powers off itself" "$(tail -n 1 "$LOG")" "udisksctl power-off -b /dev/sdc"
: > "$LOG"
echo "Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: target is busy" > "$W/udisks.unmount.out"; echo 1 > "$W/udisks.unmount.rc"
sh "$USB" eject sdb1 2> "$W/err"; rc=$?
check "busy eject exits 1" "$rc" "1"
check "busy eject shows one line" "$(cat "$W/err")" "GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: target is busy"
check "busy eject does not power off" "$(grep -c power-off "$LOG")" "0"
: > "$LOG"
echo "Error unmounting /dev/sdb1: Device is not mounted" > "$W/udisks.unmount.out"
sh "$USB" eject sdb1; check "not-mounted eject still powers off" "$(grep -c power-off "$LOG")" "1"

# validation and missing tools
for bad_dev in "" "sdb1;rm" "../sda" "SDB1" 'sd b' '$(id)' "sda/1"; do
    : > "$LOG"
    sh "$USB" mount "$bad_dev" 2>/dev/null; rc=$?
    check "mount rejects '$bad_dev' with 2 and runs nothing" "$rc:$(wc -c < "$LOG" | tr -d ' ')" "2:0"
    sh "$USB" eject "$bad_dev" 2>/dev/null; rc=$?
    check "eject rejects '$bad_dev' with 2 and runs nothing" "$rc:$(wc -c < "$LOG" | tr -d ' ')" "2:0"
done
sh "$USB" bogus 2>/dev/null; check "unknown command exits 2" "$?" "2"
rm "$W/bin/udisksctl" "$W/bin/lsblk"
sh "$USB" mount sdb1 2> "$W/err"; rc=$?
check "missing udisksctl exits 2 with one line" "$rc:$(cat "$W/err")" "2:udisksctl is not installed"
sh "$USB" list 2> "$W/err"; rc=$?
check "missing lsblk exits 2 with one line" "$rc:$(cat "$W/err")" "2:lsblk is not installed"

echo "usb script tests failures=$fails"
[ "$fails" -eq 0 ]

#!/bin/sh
# KDE Connect phone state for the bar (PhoneBattery.qml).
#   phone.sh battery
# Prints one JSON line: {"connected":false} when no paired phone is reachable (or kdeconnect-cli / busctl is
# missing), else {"connected":true,"id":"<id>","name":"<name>","percent":78,"charging":false} for the first one.
# `kdeconnect-cli -a --id-name-only` lists the reachable paired devices ("<id> <name>"); the battery comes from the
# session bus (org.kde.kdeconnect.device.battery: charge, isCharging) through busctl. Arguments are never spliced
# into shell text; ids are checked against [A-Za-z0-9_]+ before they go into an object path.
# Exit 0 always (a missing phone is a normal state); 2 for a bad usage.

case "$1" in
battery) ;;
*)
	echo "usage: phone.sh battery" >&2
	exit 2
	;;
esac

none() {
	printf '{"connected":false}\n'
	exit 0
}

command -v kdeconnect-cli >/dev/null 2>&1 || none
command -v busctl >/dev/null 2>&1 || none

line=$(kdeconnect-cli -a --id-name-only 2>/dev/null | head -n 1)
[ -n "$line" ] || none
id=${line%% *}
name=${line#* }
[ "$name" = "$line" ] && name=""
case "$id" in
'' | *[!A-Za-z0-9_]*) none ;;
esac

path="/modules/kdeconnect/devices/$id/battery"
iface="org.kde.kdeconnect.device.battery"
charge=$(busctl --user get-property org.kde.kdeconnect "$path" "$iface" charge 2>/dev/null) || none
charging=$(busctl --user get-property org.kde.kdeconnect "$path" "$iface" isCharging 2>/dev/null) || charging="b false"

# "i 78" -> 78
percent=${charge#* }
case "$percent" in
'' | *[!0-9]*) none ;;
esac
[ "$percent" -le 100 ] || none
case "$charging" in
"b true") c=true ;;
*) c=false ;;
esac

# names are outside text: keep only printable characters that need no JSON escaping
name=$(printf '%s' "$name" | tr -cd 'A-Za-z0-9 ._()-')
printf '{"connected":true,"id":"%s","name":"%s","percent":%s,"charging":%s}\n' "$id" "$name" "$percent" "$c"

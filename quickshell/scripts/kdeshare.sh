#!/bin/sh
# Send a file or a link to the phone through KDE Connect (Phone tab: Send to phone).
#   kdeshare.sh <device-id> <file|url>
# A path (~/ is expanded against HOME) must be an existing file and goes out with `kdeconnect-cli --share`; an
# http:// or https:// link goes out with `--share-text` (the phone opens it). The device id must match [A-Za-z0-9_]+.
# Arguments are never spliced into shell text and never start with "-". Exit: 0 sent, 1 kdeconnect-cli failed or the
# file is missing, 2 bad arguments.

[ "$#" -eq 2 ] || {
	echo "usage: kdeshare.sh <device-id> <file|url>" >&2
	exit 2
}
id=$1
what=$2
case "$id" in
'' | *[!A-Za-z0-9_]*)
	echo "kdeshare: bad device id" >&2
	exit 2
	;;
esac
case "$what" in
'' | -*)
	echo "kdeshare: nothing to send" >&2
	exit 2
	;;
http://?* | https://?*)
	exec kdeconnect-cli -d "$id" --share-text "$what"
	;;
'~/'*) what="$HOME/${what#\~/}" ;;
/*) ;;
*:*)
	echo "kdeshare: only files and http(s) links can be sent" >&2
	exit 2
	;;
esac
[ -f "$what" ] || {
	echo "kdeshare: not a file: $what" >&2
	exit 1
}
exec kdeconnect-cli -d "$id" --share "$what"

#!/bin/sh
# Move one app's playback stream to another output (right-click an app in the Home tab > Play on).
#   move-sink.sh <sink-input-id> <sink-id>
# Runs `pactl move-sink-input <sink-input-id> <sink-id>`. Both ids must be plain non-negative integers (PipeWire object
# ids, which pactl accepts for sink inputs and sinks); anything else exits 2 and runs nothing. Arguments are never
# spliced into shell text. Exit: 0 ok, 1 pactl failed, 2 bad arguments.

[ "$#" -eq 2 ] || {
	echo "usage: move-sink.sh <sink-input-id> <sink-id>" >&2
	exit 2
}
for v in "$1" "$2"; do
	case "$v" in
	'' | *[!0-9]*)
		echo "move-sink: ids must be integers" >&2
		exit 2
		;;
	esac
done
pactl move-sink-input "$1" "$2" || exit 1

#!/bin/sh
# Hear yourself: plays the default microphone back through the default output for a few seconds (the Test mic button
# in the Home tab's Microphone group).
#   micloop.sh start    runs `timeout 5 pw-loopback` and returns when it ends (5 s, or earlier on stop / TERM)
#   micloop.sh stop     ends a running test (signals the start call, which kills the loopback)
#   micloop.sh status   prints "on" or "off"
# WARNING: with speakers the microphone hears them again and howls (feedback). Use headphones or turn the volume down.
# Nothing is left behind: the loopback runs under `timeout`, so it ends by itself after MICLOOP_SECONDS (default 5)
# even if this script is killed hard. The pid file is MICLOOP_DIR (default XDG_RUNTIME_DIR, else /tmp)/qs-micloop.pid.
# No arguments are used in shell text. Exit: 0 ok, 1 pw-loopback missing, 2 bad usage.

dir=${MICLOOP_DIR:-${XDG_RUNTIME_DIR:-/tmp}}
pidfile="$dir/qs-micloop.pid"
secs=${MICLOOP_SECONDS:-5}
case "$secs" in
'' | *[!0-9]*) secs=5 ;;
esac

# the pid in the pid file, if it is alive and is one of these scripts
running_pid() {
	[ -f "$pidfile" ] || return 1
	p=$(head -n 1 "$pidfile" 2>/dev/null)
	case "$p" in
	'' | *[!0-9]*) return 1 ;;
	esac
	kill -0 "$p" 2>/dev/null || return 1
	case "$(ps -p "$p" -o args= 2>/dev/null)" in
	*micloop.sh*) ;;
	*) return 1 ;;
	esac
	printf '%s' "$p"
}

case "$1" in
start)
	command -v pw-loopback >/dev/null 2>&1 || {
		echo "micloop: pw-loopback is not installed (package pipewire)" >&2
		exit 1
	}
	if running_pid >/dev/null; then
		exit 0
	fi
	child=""
	cleanup() {
		if [ -n "$child" ]; then
			kill -TERM "$child" 2>/dev/null
			wait "$child" 2>/dev/null
		fi
		rm -f "$pidfile"
		exit 0
	}
	trap cleanup TERM INT HUP
	mkdir -p "$dir" 2>/dev/null
	echo $$ >"$pidfile"
	timeout "$secs" pw-loopback &
	child=$!
	wait "$child"
	child=""
	rm -f "$pidfile"
	exit 0
	;;
stop)
	p=$(running_pid) || exit 0
	kill -TERM "$p" 2>/dev/null
	exit 0
	;;
status)
	if running_pid >/dev/null; then echo on; else echo off; fi
	exit 0
	;;
*)
	echo "usage: micloop.sh start|stop|status" >&2
	exit 2
	;;
esac

#!/bin/sh
# Restart one desktop component for FixPanel.qml (Start > Troubleshoot). Only ever run after the panel's "Restart" confirm.
#   fixes.sh <id>      id is one of: pipewire portals hyprpaper easyeffects (anything else is refused)
# For each program: when `dinitctl --user list` shows it as a user service it is restarted with `dinitctl --user restart <name>`;
# otherwise the process is stopped with `pkill -x <name>` and started again detached (`setsid -f <cmd>`).
#   pipewire      services pipewire, wireplumber, pipewire-pulse   (fallback: pipewire, wireplumber)
#   portals       services xdg-desktop-portal, xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk
#                 (fallback: the same processes, started from PATH or /usr/lib/<name>, hyprland and gtk portals first)
#   hyprpaper     service hyprpaper                                (fallback: pkill + hyprpaper)
#   easyeffects   service easyeffects                              (fallback: pkill + easyeffects --gapplication-service)
# Test hook: FIXES_LIBDIR replaces /usr/lib in that fallback.
# Quickshell itself is NOT handled here: restarting it from inside kills the panel (the panel only shows the command).
# stdout: one line saying what was restarted; on failure the reason on stderr and exit 1. The id is only matched against
# the fixed list, never put into a command.

listed=$(dinitctl --user list 2>/dev/null)

in_dinit() {
    printf '%s\n' "$listed" | grep -Eq "(^|[^A-Za-z0-9._-])$1( |\$|\()"
}

# restart_one <name> [command args...]: dinit service when listed, else pkill + relaunch (command defaults to the name)
restart_one() {
    name=$1
    shift
    if in_dinit "$name"; then
        dinitctl --user restart "$name" >/dev/null 2>&1 || { echo "dinitctl could not restart $name" >&2; return 1; }
        done_list="$done_list $name"
        return 0
    fi
    [ "$#" -eq 0 ] && set -- "$name"
    exe=$1
    if ! command -v "$exe" >/dev/null 2>&1; then
        if [ -x "${FIXES_LIBDIR:-/usr/lib}/$exe" ]; then
            shift
            set -- "${FIXES_LIBDIR:-/usr/lib}/$exe" "$@"
        else
            return 0   # not installed: nothing to restart
        fi
    fi
    pkill -x "$name" >/dev/null 2>&1
    sleep 1
    setsid -f "$@" >/dev/null 2>&1 </dev/null
    done_list="$done_list $name"
    return 0
}

done_list=""
fail=0
case "$1" in
    pipewire)
        for n in pipewire wireplumber pipewire-pulse; do
            if [ "$n" = pipewire-pulse ] && ! in_dinit "$n"; then continue; fi
            restart_one "$n" || fail=1
        done
        ;;
    portals)
        for n in xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal; do
            restart_one "$n" || fail=1
        done
        ;;
    hyprpaper)
        restart_one hyprpaper || fail=1
        ;;
    easyeffects)
        restart_one easyeffects easyeffects --gapplication-service || fail=1
        ;;
    *)
        echo "unknown fix" >&2
        exit 1
        ;;
esac
if [ "$fail" -ne 0 ]; then
    exit 1
fi
if [ -z "$done_list" ]; then
    echo "nothing to restart: not installed" >&2
    exit 1
fi
echo "Restarted$done_list"
exit 0

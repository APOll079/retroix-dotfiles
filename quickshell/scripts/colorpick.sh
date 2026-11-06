#!/bin/sh
# Pick a colour from the screen: `hyprpicker -a` (the pick is also copied to the clipboard), then print it.
#   colorpick.sh   prints the colour as #rrggbb (lowercase); prints nothing and exits 1 when the pick was cancelled
# The bind then records it in the colour history:  qs ipc call colors add <#rrggbb>
# Exit codes: 0 ok, 1 cancelled or not a colour, 2 hyprpicker is not installed.

export LC_ALL=C

command -v hyprpicker >/dev/null 2>&1 || { echo "hyprpicker is not installed" >&2; exit 2; }
out=$(hyprpicker -a 2>/dev/null | head -n 1 | tr 'A-F' 'a-f')
case $out in
    "#"[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) printf '%s\n' "$out" ;;
    *) exit 1 ;;
esac

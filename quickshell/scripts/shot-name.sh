#!/bin/sh
# Prints a screenshot name (no extension): <class>_YYYY-MM-DD_HH-MM, e.g. firefox_2026-11-03_10-15.
#   shot-name.sh [class]
# With no argument the class is the focused window's (hyprctl activewindow -j). The class is
# lowercased, anything outside [a-z0-9._-] becomes "-", leading dots are dropped and it is capped at
# 40 characters, so the name can never hold a slash or climb out of the folder. An empty class,
# "null" (no focused window) or a failed query gives "screenshot".
# Used by the snipping overlay (popups/ScreenshotOverlay.qml) and the Shift+Print bind (hypr/binds.lua).
# The callers add -2, -3 when the name is taken (there are no seconds in it).

export LC_ALL=C
if [ $# -ge 1 ]; then
    cls=$1
else
    cls=$(hyprctl activewindow -j 2>/dev/null | jq -r .class 2>/dev/null)
fi
cls=$(printf %s "$cls" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9._-' '-' | sed 's/^\.*//' | cut -c1-40)
case $cls in
    "" | null) cls=screenshot ;;
esac
printf '%s_%s\n' "$cls" "$(date +%Y-%m-%d_%H-%M)"

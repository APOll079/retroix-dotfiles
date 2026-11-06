#!/bin/bash
# Render quickshell/gallery.qml offscreen, one PNG per theme.
#   scripts/render-gallery.sh -o OUTDIR [theme ...]     (default themes: cherry dusty default)
# Works on a scratch copy of quickshell/ inside OUTDIR/.work (deleted afterwards). Never touches the
# running shell: no Wayland / X display, no session D-Bus, a private XDG_* tree, QS_NO_APPLY so apply.py
# never runs.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=""
if [ "${1:-}" = "-o" ]; then OUT="${2:-}"; shift 2; fi
if [ -z "$OUT" ]; then echo "usage: $0 -o OUTDIR [theme ...]" >&2; exit 2; fi
THEMES=("$@")
[ ${#THEMES[@]} -eq 0 ] && THEMES=(cherry dusty default)
mkdir -p "$OUT" || exit 1
OUT="$(cd "$OUT" && pwd)"
WORK="$OUT/.work"
rc=0
for theme in "${THEMES[@]}"; do
    if ! python3 -c "import json,sys; sys.exit(0 if sys.argv[1] in json.load(open(sys.argv[2])) else 1)" "$theme" "$ROOT/quickshell/theme/themes.json"; then
        echo "no such theme: $theme" >&2; rc=1; continue
    fi
    rm -rf "$WORK"
    mkdir -p "$WORK/xdg/config" "$WORK/xdg/state" "$WORK/xdg/cache" "$WORK/xdg/run"
    chmod 700 "$WORK/xdg/run"
    cp -r "$ROOT/quickshell" "$WORK/qs"
    python3 - "$WORK/qs/settings.json" "$theme" <<'PY'
import json, sys
p, theme = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d.setdefault("settings", {})["currentTheme"] = theme
json.dump(d, open(p, "w"), indent=4)
PY
    png="$OUT/gallery-$theme.png"
    rm -f "$png"
    env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        QT_QPA_PLATFORM=offscreen QS_NO_APPLY=1 \
        XDG_CONFIG_HOME="$WORK/xdg/config" XDG_STATE_HOME="$WORK/xdg/state" \
        XDG_CACHE_HOME="$WORK/xdg/cache" XDG_RUNTIME_DIR="$WORK/xdg/run" \
        QS_GALLERY_OUT="$png" \
        timeout 30 qs -p "$WORK/qs/gallery.qml" > "$WORK/log.txt" 2>&1
    if [ -s "$png" ]; then
        echo "$theme: $png"
    else
        echo "$theme: no PNG, log:" >&2; grep -v "^$" "$WORK/log.txt" | tail -15 >&2; rc=1
    fi
done
rm -rf "$WORK"
exit $rc

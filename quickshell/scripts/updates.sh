#!/bin/sh
# Update counts and Arch news for UpdateState.qml. Read-only: nothing is installed or changed.
#   updates.sh          prints {"pacman": N|null, "aur": N|null, "flatpak": N|null, "error": ""}
#                       (checkupdates from pacman-contrib, yay -Qua, flatpak remote-ls --updates;
#                       a missing tool gives null, never an error; 20 s timeout per tool)
#   updates.sh news     prints the newest 5 items of https://archlinux.org/feeds/news/ as
#                       [{"title": "...", "date": "YYYY-MM-DD"}], [] on any failure. Arch's feed, not Artix's.
# Titles come from outside: the caller shows them as plain text.
export LC_ALL=C

# count <empty-rc> cmd args...: prints the number of output lines, or null if the tool is missing, timed
# out or failed. rc 0 with no output and rc <empty-rc> both mean "nothing to update" (checkupdates exits 2).
count() {
    empty_rc=$1
    shift
    command -v "$1" >/dev/null 2>&1 || { printf null; return; }
    out=$(timeout 20 "$@" 2>/dev/null)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        if [ -z "$out" ]; then printf 0; else printf '%s\n' "$out" | wc -l | tr -d ' '; fi
    elif [ "$rc" -eq "$empty_rc" ]; then
        printf 0
    else
        printf null
    fi
}

news() {
    command -v curl >/dev/null 2>&1 || { echo '[]'; return; }
    feed=$(curl -fsS --max-time 10 https://archlinux.org/feeds/news/ 2>/dev/null) || { echo '[]'; return; }
    printf '%s' "$feed" | python3 -I -c '
import sys, json, xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
try:
    out = []
    for it in ET.fromstring(sys.stdin.read()).iter("item"):
        title = " ".join((it.findtext("title") or "").split())
        raw = (it.findtext("pubDate") or "").strip()
        try:
            date = parsedate_to_datetime(raw).strftime("%Y-%m-%d")
        except Exception:
            date = raw[:16]
        if title:
            out.append({"title": title, "date": date})
        if len(out) == 5:
            break
    print(json.dumps(out))
except Exception:
    print("[]")
' 2>/dev/null || echo '[]'
}

case "${1:-}" in
    news) news ;;
    "")
        p=$(count 2 checkupdates)
        a=$(count 1 yay -Qua)
        f=$(count 99 flatpak remote-ls --updates --columns=application)
        printf '{"pacman": %s, "aur": %s, "flatpak": %s, "error": ""}\n' "$p" "$a" "$f"
        ;;
    *) echo "usage: updates.sh [news]" >&2; exit 2 ;;
esac

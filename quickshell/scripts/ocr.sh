#!/bin/sh
# Text from a screen region: grim -> tesseract -> wl-copy.
#   ocr.sh <WxH+X+Y>   grabs that rectangle (global pixels) to a temp png in $XDG_RUNTIME_DIR, reads it with
#                      `tesseract <png> - -l swe+eng` (QS_OCR_LANG replaces the languages; if those language data are
#                      missing it retries with eng), copies the text with wl-copy and prints it. The temp file is removed.
# Exit codes: 0 ok (text printed and copied), 1 failed (bad region, grim / tesseract error), 2 tesseract is not
# installed, 3 nothing was recognised (the clipboard is left alone), 64 bad usage.
# Packages: tesseract, tesseract-data-swe, tesseract-data-eng (and grim, wl-clipboard).
# The region is validated and passed as separate arguments, never spliced into script text.

export LC_ALL=C

[ $# -eq 1 ] || { echo "usage: ocr.sh <WxH+X+Y>" >&2; exit 64; }
command -v tesseract >/dev/null 2>&1 || { echo "tesseract is not installed" >&2; exit 2; }
command -v grim >/dev/null 2>&1 || { echo "grim is not installed" >&2; exit 1; }
command -v wl-copy >/dev/null 2>&1 || { echo "wl-copy is not installed" >&2; exit 1; }
case $1 in
    *[!0-9x+]*) echo "bad region" >&2; exit 1 ;;
    [0-9]*x[0-9]*+[0-9]*+[0-9]*) ;;
    *) echo "bad region" >&2; exit 1 ;;
esac
size=${1%%+*}
rest=${1#*+}
x=${rest%%+*}
y=${rest#*+}

rt=${XDG_RUNTIME_DIR:-/tmp}
png=$(mktemp "$rt/qs-ocr-XXXXXX.png") || exit 1
trap 'rm -f "$png"' EXIT INT TERM

grim -g "$x,$y $size" "$png" || { echo "could not grab the region" >&2; exit 1; }
lang=${QS_OCR_LANG:-swe+eng}
text=$(tesseract "$png" - -l "$lang" 2>/dev/null) || text=$(tesseract "$png" - -l eng 2>/dev/null) || { echo "tesseract failed" >&2; exit 1; }
# nothing but whitespace: say so, keep the clipboard
case $text in
    *[![:space:]]*) ;;
    *) exit 3 ;;
esac
printf '%s\n' "$text" | wl-copy || { echo "could not copy" >&2; exit 1; }
printf '%s\n' "$text"

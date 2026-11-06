#!/bin/sh
# A GIF from a recording: ffmpeg palettegen / paletteuse.
#   gif.sh <in.mp4>   writes <name>.gif next to the video (never over a file: <name>-2.gif, -3 ... when taken), 640 px
#                     wide, 12 fps, at most the first 15 s; prints the path of the gif.
# Exit codes: 0 ok, 1 failed (no such file, ffmpeg error; a half-written gif is removed), 2 ffmpeg is not installed,
# 64 bad usage. Package: ffmpeg. The path is one argument, never spliced into script text.

export LC_ALL=C

[ $# -eq 1 ] || { echo "usage: gif.sh <in.mp4>" >&2; exit 64; }
in=$1
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is not installed" >&2; exit 2; }
[ -f "$in" ] || { echo "no such file" >&2; exit 1; }

dir=$(dirname -- "$in")
base=$(basename -- "$in")
name=${base%.*}
out=$dir/$name.gif
n=2
while [ -e "$out" ]; do
    out=$dir/$name-$n.gif
    n=$((n + 1))
done

ffmpeg -nostdin -loglevel error -t 15 -i "$in" \
    -vf "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
    -loop 0 "$out" || { rm -f "$out"; echo "ffmpeg failed" >&2; exit 1; }
printf '%s\n' "$out"

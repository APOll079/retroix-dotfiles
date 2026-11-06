#!/bin/sh
# Download speed for the Network page. Runs only when called (the page's "Speed test" button), never by itself.
#   speedtest.sh <url>
# Downloads <url> (an http:// or https:// test file) to /dev/null with `curl --max-time 20` and prints JSON
# {"ok":true,"bytesPerSec":11650000,"mbit":93.2,"partial":false,"error":""}. "partial" is true when the 20 s limit hit
# before the file ended (the speed so far is still reported). A missing curl, a bad URL or a failed download gives
# {"ok":false,...,"error":"one line"}; the exit code is 0 in every case but a wrong argument count (2).
exec python3 -I -c '
import json, re, shutil, subprocess, sys

url = sys.argv[1] if len(sys.argv) == 2 else None
if url is None:
    sys.exit(2)


def out(ok, bps=0.0, partial=False, error=""):
    print(json.dumps({"ok": ok, "bytesPerSec": round(bps), "mbit": round(bps * 8 / 1e6, 1), "partial": partial, "error": error}))
    sys.exit(0)


if not re.fullmatch(r"https?://[^\s\x00-\x1f\x7f]{1,500}", url):
    out(False, error="the test URL is not an http or https address")
if not shutil.which("curl"):
    out(False, error="curl not installed")
try:
    r = subprocess.run(["curl", "-sS", "--max-time", "20", "--proto", "=http,https", "-o", "/dev/null", "-w", "%{speed_download}", "--", url],
                       capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)
except (OSError, subprocess.SubprocessError):
    out(False, error="the speed test could not run")
try:
    bps = float(r.stdout.strip().splitlines()[-1]) if r.stdout.strip() else 0.0
except ValueError:
    bps = 0.0
if r.returncode == 0 and bps > 0:
    out(True, bps)
if r.returncode == 28 and bps > 0:
    out(True, bps, True)
msg = (r.stderr.strip().splitlines() or ["the download failed"])[-1][:120]
out(False, error=msg)
' "$@"

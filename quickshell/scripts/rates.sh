#!/bin/sh
# Exchange rates for the launcher's currency answers ("100 eur in sek"). Called at most once per launcher open, and only
# when the cache is older than 12 hours.
#   rates.sh
# Fetches the European Central Bank reference rates from frankfurter.app
# (`curl -fsS --max-time 10 -L https://api.frankfurter.app/latest?from=EUR`) and prints JSON
# {"ok":true,"date":"2026-11-06","rates":{"EUR":1,"SEK":11.23,...},"error":""}. Only three-letter codes with a positive
# number are kept and EUR = 1 is always there. No network, a bad answer or a missing curl gives
# {"ok":false,"date":"","rates":{},"error":"one line"}; the exit code is 0 in every case. Nothing is stored here.
exec python3 -I -c '
import json, re, shutil, subprocess, sys


def out(ok, date="", rates=None, error=""):
    print(json.dumps({"ok": ok, "date": date, "rates": rates or {}, "error": error}))
    sys.exit(0)


if len(sys.argv) != 1:
    sys.exit(2)
if not shutil.which("curl"):
    out(False, error="curl not installed")
try:
    r = subprocess.run(["curl", "-fsS", "--max-time", "10", "-L", "--proto-redir", "=https", "https://api.frankfurter.app/latest?from=EUR"],
                       capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL)
except (OSError, subprocess.SubprocessError):
    out(False, error="the rates could not be fetched")
if r.returncode != 0:
    out(False, error=(r.stderr.strip().splitlines() or ["no network"])[-1][:120])
try:
    d = json.loads(r.stdout)
    date = d["date"]
    raw = d["rates"]
    assert isinstance(raw, dict) and isinstance(date, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", date)
except (ValueError, KeyError, TypeError, AssertionError):
    out(False, error="the rates answer was not understood")
rates = {"EUR": 1}
for k, v in raw.items():
    if re.fullmatch(r"[A-Z]{3}", str(k)) and isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0:
        rates[k] = v
if len(rates) < 2:
    out(False, error="the rates answer was empty")
out(True, date, rates)
' "$@"

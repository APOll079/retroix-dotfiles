#!/usr/bin/env python3
"""Login time report for the Login report panel (popups/LoginReportPanel.qml).

    python3 -I loginreport.py [FILE]

FILE defaults to $XDG_RUNTIME_DIR/qs-login-times. hypr/autostart.lua appends one line per step as it starts:

    <epoch-ms> <name>        e.g.   1767225600123 session-start
                                    1767225601456 waybar-up

The first line is the start of the login. A name is everything after the first space (it can contain spaces); lines that
do not parse are skipped; the lines are put in time order.
Prints one JSON array, slowest step first:  [{"name": str, "ms": int, "since_previous_ms": int}]
  ms                   milliseconds from the first line to this one
  since_previous_ms    milliseconds since the line before it (0 for the first line)
The total login time is the largest ms. A missing, empty or unreadable file prints [] and exits 0.
"""
import json
import os
import sys


def report(text):
    rows = []
    for line in text.splitlines():
        stamp, _, name = line.strip().partition(" ")
        name = name.strip()
        if not stamp.isdigit() or name == "":
            continue
        rows.append((int(stamp), name))
    rows.sort(key=lambda r: r[0])
    out = []
    for i, (t, name) in enumerate(rows):
        out.append({"name": name, "ms": t - rows[0][0], "since_previous_ms": t - rows[i - 1][0] if i else 0})
    # slowest first; equal steps keep their time order
    out.sort(key=lambda r: -r["since_previous_ms"])
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "qs-login-times")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read(1 << 20)
    except OSError:
        text = ""
    print(json.dumps(report(text)))


if __name__ == "__main__":
    main()

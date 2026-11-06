#!/usr/bin/env python3
"""Writes CHANGELOG.md from the git history: one section per day, newest first, one line per commit (its subject).

  python3 scripts/changelog.py            rewrite CHANGELOG.md
"""
import subprocess
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
out = subprocess.run(["git", "log", "--no-merges", "--format=%ad%x09%h%x09%s", "--date=short"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
days = OrderedDict()
for line in out.splitlines():
    date, h, subject = line.split("\t", 2)
    days.setdefault(date, []).append((h, subject))
lines = ["# Changelog", "", "Written by `python3 scripts/changelog.py` from the git history (one line per commit, newest day first).", ""]
for date, items in days.items():
    lines.append("## " + date)
    lines.append("")
    lines += ["- " + subject + " (`" + h + "`)" for h, subject in items]
    lines.append("")
(ROOT / "CHANGELOG.md").write_text("\n".join(lines))
print("CHANGELOG.md: %d commits, %d days" % (sum(len(v) for v in days.values()), len(days)))

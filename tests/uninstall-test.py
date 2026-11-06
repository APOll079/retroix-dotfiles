#!/usr/bin/env python3
"""Tests uninstall.sh against a scratch HOME with a fake backup: the dry run copies nothing, --yes restores folders and
loose files, a missing backup fails cleanly. Never touches the real home.  python3 tests/uninstall-test.py"""
import os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
failures = 0
def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    failures += 0 if cond else 1
with tempfile.TemporaryDirectory(prefix="qsun-") as t:
    home = Path(t)
    (home / "config-backup-2026-01-01-0000/kitty").mkdir(parents=True)
    (home / "config-backup-2026-01-01-0000/kitty/kitty.conf").write_text("old")
    (home / "config-backup-2026-01-01-0000/hyfetch.json").write_text("{}")
    (home / "config-backup-2026-02-02-0000/kitty").mkdir(parents=True)
    (home / "config-backup-2026-02-02-0000/kitty/kitty.conf").write_text("newest")
    (home / ".config/kitty").mkdir(parents=True)
    (home / ".config/kitty/kitty.conf").write_text("current")
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"))
    def run(*a):
        return subprocess.run(["bash", str(ROOT / "uninstall.sh"), *a], env=env, capture_output=True, text=True, timeout=30)
    r = run()
    check("dry run says so and copies nothing", r.returncode == 0 and "dry run" in r.stdout and (home / ".config/kitty/kitty.conf").read_text() == "current")
    r = run("--yes")
    check("--yes restores the newest backup over the current file", r.returncode == 0 and (home / ".config/kitty/kitty.conf").read_text() == "newest")
    r = run("--yes", str(home / "config-backup-2026-01-01-0000"))
    check("an explicit folder restores folders and loose files", (home / ".config/kitty/kitty.conf").read_text() == "old" and (home / ".config/hyfetch.json").read_text() == "{}")
    r = run("--yes", str(home / "nope"))
    check("a missing backup fails cleanly", r.returncode == 1 and "no backup folder" in r.stdout)
print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

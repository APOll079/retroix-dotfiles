#!/usr/bin/env python3
"""Tests quickshell/scripts/service-log.sh with a fake dinitctl on an isolated PATH.
  python3 tests/script_service_log.py     (prints PASS/FAIL lines, exit 1 on a failure)
The fake logs its arguments to $LOG and never touches a real dinit."""
import os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "quickshell/scripts/service-log.sh"
fails = 0


def check(name, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        fails += 1


def run(path_dirs, *args, env_extra=None):
    env = {"PATH": ":".join(path_dirs), "HOME": str(tmp), "LOG": str(tmp / "log"), "LANG": "C"}
    env.update(env_extra or {})
    return subprocess.run(["/bin/sh", str(SCRIPT), *args], env=env, capture_output=True, text=True, timeout=10)


with tempfile.TemporaryDirectory() as t:
    tmp = Path(t)
    fake = tmp / "fake"
    fake.mkdir()
    # fake dinitctl: logs its arguments, prints 100 lines for "chatty", nothing for "quiet", fails for "gone"
    (fake / "dinitctl").write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$LOG"
case $3 in
  chatty) i=1; while [ $i -le 100 ]; do echo "line $i"; i=$((i+1)); done ;;
  quiet) : ;;
  gone) echo "dinitctl: service not found" >&2; exit 1 ;;
  *) echo "hello $3" ;;
esac
''')
    (fake / "dinitctl").chmod(0o755)
    # a PATH with the basic tools but no dinitctl (and the fake dir gets the same tools next to the fake)
    bare = tmp / "bare"
    bare.mkdir()
    for tool in ("tail", "sh", "cat", "printf"):
        for d in ("/usr/bin", "/bin"):
            if (Path(d) / tool).exists():
                (bare / tool).symlink_to(Path(d) / tool)
                (fake / tool).symlink_to(Path(d) / tool)
                break

    r = run([str(fake)], "chatty")
    lines = r.stdout.splitlines()
    check("chatty: exit 0, last 40 lines", r.returncode == 0 and len(lines) == 40 and lines[0] == "line 61" and lines[-1] == "line 100")
    check("chatty: dinitctl got --user catlog <name>", (tmp / "log").read_text().strip() == "--user catlog chatty")
    r = run([str(fake)], "quiet")
    check("quiet: empty output, exit 0", r.returncode == 0 and r.stdout == "")
    r = run([str(fake)], "gone")
    check("gone: dinitctl's exit status and message pass through", r.returncode == 1 and "not found" in r.stderr)
    r = run([str(fake)], "pipewire-pulse@1.x_y")
    check("a normal name with @ . _ - works", r.returncode == 0 and r.stdout.strip() == "hello pipewire-pulse@1.x_y")

    (tmp / "log").unlink()
    hostile = ["", "a b", "a;rm -rf ~", "$(touch /tmp/x)", "`id`", "a\nb", "a/b", "../x", "-h", "--user", "a'b", 'a"b', "a|b", "a*", "é", "a&b", "a>b"]
    for h in hostile:
        r = run([str(fake)], h)
        check("hostile %r: exit 2, nothing run" % h, r.returncode == 2 and r.stdout == "")
    check("hostile names never reached dinitctl", not (tmp / "log").exists())
    r = run([str(fake)])
    check("no argument: exit 2", r.returncode == 2)
    r = run([str(bare)], "chatty")
    check("dinitctl missing: exit 2", r.returncode == 2 and "not found" in r.stderr)

sys.exit(1 if fails else 0)

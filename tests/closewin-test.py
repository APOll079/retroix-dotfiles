#!/usr/bin/env python3
"""Tests hypr/scripts/closewin with a fake hyprctl (serves JSON fixtures, logs the dispatches) and the real jq.
Nothing real is run.  python3 tests/closewin-test.py   prints TEST pass|FAIL lines and "TEST done failures=N" """
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "hypr/scripts/closewin"
failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    failures += 0 if cond else 1


def client(addr, wsid, wsname, x, y, w, h, mapped=True):
    return {"address": addr, "mapped": mapped, "workspace": {"id": wsid, "name": wsname}, "at": [x, y], "size": [w, h]}


def run_case(work, active_ws, cursor, clients, monitors):
    (work / "activewindow").write_text(json.dumps({"workspace": {"name": active_ws}} if active_ws else {}))
    (work / "cursorpos").write_text(json.dumps(cursor))
    (work / "clients").write_text(json.dumps(clients))
    (work / "monitors").write_text(json.dumps(monitors))
    (work / "log").write_text("")
    subprocess.run(["sh", str(SCRIPT)], env={"PATH": str(work / "bin"), "W": str(work)}, capture_output=True, timeout=20)
    return (work / "log").read_text().splitlines()


with tempfile.TemporaryDirectory(prefix="qscw-") as t:
    work = Path(t)
    (work / "bin").mkdir()
    for tool in ("sh", "printf", "cat", "jq"):
        p = shutil.which(tool)
        if p:
            (work / "bin" / tool).symlink_to(p)
    fake = work / "bin" / "hyprctl"
    fake.write_text('''#!/bin/sh
case "$1" in
  activewindow) cat "$W/activewindow" ;;
  cursorpos) cat "$W/cursorpos" ;;
  clients) cat "$W/clients" ;;
  monitors) cat "$W/monitors" ;;
  dispatch) echo "$2" >> "$W/log" ;;
esac
''')
    fake.chmod(0o755)
    mons = [{"activeWorkspace": {"id": 1}}, {"activeWorkspace": {"id": 2}}]
    kitty = client("0xaa11", 2, "2", 1920, 0, 1000, 600)
    vesktop = client("0xbb22", -98, "special:spotifyspace", 100, 100, 900, 700)
    far = client("0xcc33", 7, "7", 1920, 0, 1000, 600)
    close = "hl.dsp.window.close()"

    log = run_case(work, "1", {"x": 2000, "y": 100}, [kitty, vesktop], mons)
    check("active on a normal workspace: just close it", log == [close])
    log = run_case(work, "special:spotifyspace", {"x": 2000, "y": 100}, [kitty, vesktop], mons)
    check("active on a special workspace, pointer over kitty: focus kitty, then close", log == ['hl.dsp.focus({ window = "address:0xaa11" })', close])
    log = run_case(work, "special:spotifyspace", {"x": 5000, "y": 5000}, [kitty, vesktop], mons)
    check("active on a special workspace, pointer over nothing: close the active one", log == [close])
    log = run_case(work, "special:spotifyspace", {"x": 2000, "y": 100}, [far, vesktop], mons)
    check("a window on a workspace that isn't shown is never picked", log == [close])
    log = run_case(work, "special:spotifyspace", {"x": 200, "y": 200}, [vesktop], mons)
    check("pointer over the special window itself: close it (no change)", log == [close])
    log = run_case(work, "special:spotifyspace", {"x": 2000, "y": 100}, [client("0xdd44", 2, "2", 1920, 0, 1000, 600, mapped=False), vesktop], mons)
    check("an unmapped window is ignored", log == [close])
    log = run_case(work, "special:spotifyspace", {"x": 2000, "y": 100}, [client("0xzz'; touch pwn", 2, "2", 1920, 0, 1000, 600)], mons)
    check("a hostile address never reaches a dispatch", log == [close] and not Path("pwn").exists())
    log = run_case(work, "", {"x": 1, "y": 1}, [], mons)
    check("no active window data: the plain close", log == [close])

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

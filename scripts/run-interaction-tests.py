#!/usr/bin/env python3
"""Runs tests/interaction/*.qml offscreen with real simulated mouse / key input. Stdlib only.

  python3 scripts/run-interaction-tests.py [file.qml ...]    exit 1 if any test fails or a file doesn't finish

Each test file is run by `qs -p` on a scratch copy of quickshell/ (no display, no session D-Bus, a private XDG
tree, QS_NO_APPLY=1, so the running shell is never touched) and prints "TEST pass|FAIL <name>" lines plus a
final "TEST done failures=N". Needs the `qs` binary; without it the tests are skipped with a note.
"""
import os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run_file(qml):
    work = Path(tempfile.mkdtemp(prefix="qsit-"))
    try:
        for d in ("config", "state", "cache", "run"):
            (work / "xdg" / d).mkdir(parents=True)
        (work / "xdg" / "run").chmod(0o700)
        shutil.copytree(ROOT / "quickshell", work / "qs", ignore=shutil.ignore_patterns("__pycache__"))
        # the test file goes to the root of the copy, where the shell's singletons and `popups` resolve
        shutil.copy(qml, work / "qs" / qml.name)
        env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS")}
        env.update(QT_QPA_PLATFORM="offscreen", QS_NO_APPLY="1",
                   XDG_CONFIG_HOME=str(work / "xdg/config"), XDG_STATE_HOME=str(work / "xdg/state"),
                   XDG_CACHE_HOME=str(work / "xdg/cache"), XDG_RUNTIME_DIR=str(work / "xdg/run"))
        try:
            r = subprocess.run(["qs", "-p", str(work / "qs" / qml.name)], env=env, capture_output=True, text=True, timeout=40)
            out = r.stdout + r.stderr
        except subprocess.TimeoutExpired as e:
            out = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
            out += "\nTEST FAIL the file did not finish within 40 s"
        out = re.sub(r"\x1b\[[0-9;]*m", "", out)
        return [l[l.index("TEST "):] for l in out.splitlines() if "TEST " in l], out
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    if not shutil.which("qs"):
        print("interaction tests skipped: no qs binary")
        return 0
    files = [Path(a).resolve() for a in sys.argv[1:]] or sorted((ROOT / "tests" / "interaction").glob("*.qml"))
    bad = 0
    for f in files:
        lines, out = run_file(f)
        done = any(l.startswith("TEST done") for l in lines)
        fails = [l for l in lines if l.startswith("TEST FAIL")]
        for l in lines:
            print(f"{f.name}: {l}")
        if not done and not fails:
            fails.append("TEST FAIL no result (the file did not run); log tail: " + " | ".join(out.strip().splitlines()[-3:]))
            print(f"{f.name}: {fails[-1]}")
        bad += len(fails)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

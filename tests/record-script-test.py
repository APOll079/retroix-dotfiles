#!/usr/bin/env python3
"""Tests quickshell/scripts/record.sh with a fake gpu-screen-recorder (logs its arguments, writes a stub mp4 on
SIGINT, logs SIGUSR1). Isolated PATH, scratch HOME and XDG_RUNTIME_DIR; nothing real is run.

  python3 tests/record-script-test.py        prints TEST pass|FAIL lines and "TEST done failures=N"
"""
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "quickshell/scripts/record.sh"
FAKE = r'''#!/usr/bin/env python3
# fake gpu-screen-recorder: logs argv, saves a stub mp4 on SIGINT, logs SIGUSR1
import os, signal, sys, time
log = os.environ["FAKE_LOG"]
open(log, "a").write("ARGS " + "\x1f".join(sys.argv[1:]) + "\n")
args = sys.argv[1:]
out = args[args.index("-o") + 1]
def done(*_):
    f = out if out.endswith(".mp4") else os.path.join(out, "Replay_fake.mp4")
    open(f, "wb").write(b"\0" * 16)
    open(log, "a").write("SIGINT\n")
    sys.exit(0)
signal.signal(signal.SIGINT, done)
signal.signal(signal.SIGUSR1, lambda *_: open(log, "a").write("SIGUSR1\n"))
while True:
    time.sleep(0.05)
'''

failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    if not cond:
        failures += 1


def main():
    global failures
    work = Path(tempfile.mkdtemp(prefix="qsrec-"))
    try:
        bin_, home, rt = work / "bin", work / "home", work / "run"
        for d in (bin_, home, rt):
            d.mkdir()
        rt.chmod(0o700)
        # the script needs sh, sed, grep, tr, date, mkdir, mv, rm, sleep, kill, head, basename, dirname, nohup, python3
        for tool in ("sh", "sed", "grep", "tr", "date", "mkdir", "mv", "rm", "sleep", "head", "basename", "dirname", "nohup", "python3", "cat", "env", "printf", "kill", "cut"):
            p = shutil.which(tool)
            if p and not (bin_ / tool).exists():
                (bin_ / tool).symlink_to(p)
        fake = bin_ / "gpu-screen-recorder"
        fake.write_text(FAKE)
        fake.chmod(0o755)
        log = work / "fake.log"
        log.write_text("")
        env = {"PATH": str(bin_), "HOME": str(home), "XDG_RUNTIME_DIR": str(rt), "FAKE_LOG": str(log)}

        def rec(*a, e=None):
            return subprocess.run(["sh", str(SCRIPT), *a], env=e or env, capture_output=True, text=True, timeout=30)

        def args_lines():
            return [l[5:].split("\x1f") for l in log.read_text().splitlines() if l.startswith("ARGS ")]

        out = work / "out"
        r = rec("start", "region", "0", str(out), "100x80+10+20", "firefox")
        check("start region exits 0 and prints the file", r.returncode == 0 and r.stdout.strip().startswith(str(out) + "/firefox_") and r.stdout.strip().endswith(".mp4"))
        a = args_lines()[-1] if args_lines() else []
        check("region args: -w region -region WxH+X+Y, one audio track, mp4",
              a[:4] == ["-w", "region", "-region", "100x80+10+20"] and a.count("-a") == 1 and "default_output" in a and "-c" in a and "mp4" in a)
        f = r.stdout.strip()
        check("-o is the printed file", a[a.index("-o") + 1] == f)
        s = rec("status")
        st = json.loads(s.stdout)
        check("status while recording", st["recording"] is True and st["file"] == f and st["since"] > 0)
        r2 = rec("start", "screen", "0", str(out), "DP-1")
        check("second start is refused", r2.returncode == 1 and "already" in r2.stderr and len(args_lines()) == 1)
        r = rec("stop")
        check("stop prints the path and the file exists", r.returncode == 0 and r.stdout.strip() == f and Path(f).is_file())
        check("fake got SIGINT", "SIGINT" in log.read_text())
        check("status after stop", json.loads(rec("status").stdout)["recording"] is False)
        check("stop when idle fails", rec("stop").returncode == 1)

        r = rec("start", "screen", "1", "~/clips", "DP-2")
        a = args_lines()[-1]
        check("screen with mic: -w DP-2, two audio tracks, ~ expanded",
              r.returncode == 0 and a[:2] == ["-w", "DP-2"] and a.count("-a") == 2 and "default_input" in a and r.stdout.startswith(str(home) + "/clips/recording_"))
        rec("stop")
        r = rec("start", "window", "0", str(out), "640x480+0+0", "My App")
        check("window mode is a region and the class is sanitised", r.returncode == 0 and "-region" in args_lines()[-1] and "/my-app_" in r.stdout)
        rec("stop")

        # hostile input stays one argument and never executes
        evil = work / "e'v\"il; touch PWNED $(touch PWNED2)"
        r = rec("start", "region", "0", str(evil), "10x10+0+0", "x; touch PWNED3")
        a = args_lines()[-1]
        f = r.stdout.strip()
        check("hostile dir and class: file inside the dir, nothing executed",
              r.returncode == 0 and a[a.index("-o") + 1] == f and f.startswith(str(evil) + "/x--touch-pwned3_")
              and not list(work.glob("PWNED*")) and not Path("PWNED").exists())
        check("status JSON stays valid with quotes in the path", json.loads(rec("status").stdout)["file"] == f)
        r = rec("stop")
        check("stop returns the hostile path intact", r.stdout.strip() == f)
        check("bad region is rejected", rec("start", "region", "0", str(out), "1;2").returncode == 1)
        check("bad output name is rejected", rec("start", "screen", "0", str(out), "-x").returncode == 1)

        # missing tool
        e2 = dict(env, PATH=str(work / "nobin"))
        (work / "nobin").mkdir()
        for tool in ("sh", "sed", "grep", "tr", "date", "mkdir", "dirname", "head", "cat", "cut"):
            p = shutil.which(tool)
            if p:
                (work / "nobin" / tool).symlink_to(p)
        r = rec("start", "screen", "0", str(out), "DP-1", e=e2)
        check("missing tool: exit 2 and one clear line", r.returncode == 2 and r.stderr.strip() == "gpu-screen-recorder is not installed")
        r = rec("replay-start", str(out), "30", e=e2)
        check("replay-start missing tool: exit 2", r.returncode == 2)

        # replay
        rdir = work / "replays"
        r = rec("replay-start", str(rdir), "45", "DP-1")
        a = args_lines()[-1]
        check("replay-start args", r.returncode == 0 and a[:6] == ["-w", "DP-1", "-r", "45", "-c", "mp4"] and a[a.index("-o") + 1] == str(rdir))
        check("replay-status", json.loads(rec("replay-status").stdout) | {"since": 0} == {"replaying": True, "dir": str(rdir), "since": 0})
        check("double replay-start refused", rec("replay-start", str(rdir)).returncode == 1)
        check("a recording can run alongside", rec("start", "screen", "0", str(out), "DP-1").returncode == 0)
        rec("stop")
        r = rec("replay-save")
        import time
        time.sleep(0.3)
        check("replay-save sends SIGUSR1 and prints nothing", r.returncode == 0 and r.stdout == "" and "SIGUSR1" in log.read_text())
        r = rec("replay-stop")
        check("replay-stop sends SIGINT and clears state", r.returncode == 0 and json.loads(rec("replay-status").stdout)["replaying"] is False)
        check("replay-save when idle fails", rec("replay-save").returncode == 1)
        check("replay-last names the newest mp4 only", rec("replay-last", str(rdir)).stdout.strip() == "Replay_fake.mp4")
        old = rdir / "old.mp4"
        old.write_bytes(b"x")
        os.utime(old, (1, 1))
        (rdir / "note.txt").write_text("x")
        check("replay-last ignores older and non-mp4", rec("replay-last", str(rdir)).stdout.strip() == "Replay_fake.mp4")
        check("replay-last on a missing dir is empty", rec("replay-last", str(work / "nope")).stdout == "")
        check("replay seconds validated", rec("replay-start", str(rdir), "x; id").returncode == 1)
    finally:
        for p in (work / "run").glob("*.json"):
            pass
        subprocess.run(["pkill", "-f", str(work)], capture_output=True)
        shutil.rmtree(work, ignore_errors=True)
    print("TEST done failures=%d" % failures)
    return 1 if failures else 0


sys.exit(main())

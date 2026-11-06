#!/usr/bin/env python3
"""Tests quickshell/scripts/phone.sh, micloop.sh, move-sink.sh and kdeshare.sh.
  python3 tests/scripts-r4a.py     (prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
Every external tool (kdeconnect-cli, busctl, pw-loopback, pactl, timeout is real) is a fake on an isolated PATH that logs
its arguments; the real ones are never run. HOME is a scratch folder. Nothing outside the scratch folder is touched."""
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
S = ROOT / "quickshell/scripts"
failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    if not cond:
        failures += 1


with tempfile.TemporaryDirectory() as t:
    tmp = Path(t)
    fake = tmp / "fake"
    fake.mkdir()
    home = tmp / "home"
    home.mkdir()
    log = tmp / "log"
    for tool in ("sh", "env", "python3", "timeout", "sleep", "cat", "printf", "head", "tr", "kill", "pgrep", "ps", "mkdir", "rm", "dirname", "basename", "touch", "test", "tail", "wc", "id"):
        for d in ("/usr/bin", "/bin"):
            if (Path(d) / tool).exists():
                (fake / tool).symlink_to(Path(d) / tool)
                break

    def fakecmd(name, body):
        p = fake / name
        if p.exists() or p.is_symlink():
            p.unlink()
        p.write_text("#!/bin/sh\n" + body)
        p.chmod(0o755)

    def rmfake(name):
        p = fake / name
        if p.exists() or p.is_symlink():
            p.unlink()

    def run(script, *args, extra=None, timeout=30):
        env = {"PATH": str(fake), "HOME": str(home), "LOG": str(log), "LANG": "C", "XDG_RUNTIME_DIR": str(tmp / "run")}
        env.update(extra or {})
        (tmp / "run").mkdir(exist_ok=True)
        return subprocess.run(["/bin/sh", str(S / script), *args], env=env, capture_output=True, text=True, timeout=timeout)

    def calls():
        return [l.split() for l in log.read_text().splitlines()] if log.exists() else []

    def clear():
        if log.exists():
            log.unlink()

    # ---------------- phone.sh ----------------
    fakecmd("kdeconnect-cli", 'echo "kdeconnect-cli $*" >> "$LOG"\n[ "$1" = "-a" ] && echo "$PHONE_LINE"\n')
    fakecmd("busctl", 'echo "busctl $*" >> "$LOG"\ncase "$6" in charge) echo "i ${CHARGE:-78}";; isCharging) echo "b ${CHARGING:-false}";; esac\n')
    r = run("phone.sh", "battery", extra={"PHONE_LINE": "abc123_x Pixel 8"})
    check("phone: a reachable phone gives its level", r.returncode == 0 and r.stdout.strip() == '{"connected":true,"id":"abc123_x","name":"Pixel 8","percent":78,"charging":false}')
    check("phone: busctl is asked about that device's battery path on the user bus",
          any(c[:3] == ["busctl", "--user", "get-property"] and "/modules/kdeconnect/devices/abc123_x/battery" in c for c in calls()))
    r = run("phone.sh", "battery", extra={"PHONE_LINE": "abc Pixel", "CHARGING": "true", "CHARGE": "5"})
    check("phone: charging and 5 percent", '"percent":5,"charging":true' in r.stdout)
    r = run("phone.sh", "battery", extra={"PHONE_LINE": ""})
    check("phone: no device is not connected", r.returncode == 0 and r.stdout.strip() == '{"connected":false}')
    r = run("phone.sh", "battery", extra={"PHONE_LINE": "bad;id Pixel"})
    check("phone: an id with odd characters is refused", r.stdout.strip() == '{"connected":false}')
    r = run("phone.sh", "battery", extra={"PHONE_LINE": "abc Pixel", "CHARGE": "abc"})
    check("phone: a junk level is not connected", r.stdout.strip() == '{"connected":false}')
    r = run("phone.sh", "battery", extra={"PHONE_LINE": "abc Pi\"xel$(x)"})
    check("phone: the name is stripped to safe characters", r.stdout.strip().startswith('{"connected":true') and '"name":"Pixel(x)"' in r.stdout)
    r = run("phone.sh")
    check("phone: no argument is a usage error", r.returncode == 2)
    rmfake("kdeconnect-cli")
    r = run("phone.sh", "battery")
    check("phone: without kdeconnect-cli it is simply not connected", r.returncode == 0 and r.stdout.strip() == '{"connected":false}')

    # ---------------- micloop.sh ----------------
    # fake pw-loopback: records its start, stays up until killed
    fakecmd("pw-loopback", 'echo "pw-loopback $*" >> "$LOG"\necho $$ > "$RUN_DIR/pw.pid"\ntrap \'echo "pw-loopback TERM" >> "$LOG"; exit 0\' TERM\nwhile :; do sleep 0.1; done\n')
    rd = tmp / "mic"
    rd.mkdir()
    env = {"RUN_DIR": str(rd), "MICLOOP_DIR": str(rd), "MICLOOP_SECONDS": "5"}
    clear()
    r = run("micloop.sh", "bogus", extra=env)
    check("micloop: bad usage exits 2", r.returncode == 2)
    clear()
    r = run("micloop.sh", "start", extra={**env, "MICLOOP_SECONDS": "1"}, timeout=20)
    check("micloop: start runs pw-loopback and ends by itself after the timeout", r.returncode == 0 and any(c[0] == "pw-loopback" for c in calls()) and ["pw-loopback", "TERM"] in calls())
    check("micloop: nothing left behind after the timeout", not (rd / "qs-micloop.pid").exists())
    # start in the background, stop with a second call
    clear()
    p = subprocess.Popen(["/bin/sh", str(S / "micloop.sh"), "start"], env={"PATH": str(fake), "HOME": str(home), "LOG": str(log), "LANG": "C", **env}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(1.2)
    check("micloop: running while the test plays", p.poll() is None and (rd / "qs-micloop.pid").exists())
    r = run("micloop.sh", "status", extra=env)
    check("micloop: status says on", r.returncode == 0 and r.stdout.strip() == "on")
    r = run("micloop.sh", "stop", extra=env)
    time.sleep(0.5)
    check("micloop: stop ends the first call and kills the loopback", p.poll() is not None and ["pw-loopback", "TERM"] in calls())
    check("micloop: the pid file is gone after a stop", not (rd / "qs-micloop.pid").exists())
    r = run("micloop.sh", "status", extra=env)
    check("micloop: status says off", r.stdout.strip() == "off")
    r = run("micloop.sh", "stop", extra=env)
    check("micloop: stop with nothing running is fine", r.returncode == 0)
    # closing (SIGTERM to the start call, what Quickshell does to a Process) kills the loopback too
    clear()
    p = subprocess.Popen(["/bin/sh", str(S / "micloop.sh"), "start"], env={"PATH": str(fake), "HOME": str(home), "LOG": str(log), "LANG": "C", **env}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(1.0)
    p.terminate()
    p.wait(timeout=10)
    time.sleep(0.5)
    check("micloop: killing the start call kills the loopback", ["pw-loopback", "TERM"] in calls() and not (rd / "qs-micloop.pid").exists())
    pwpid = (rd / "pw.pid").read_text().strip() if (rd / "pw.pid").exists() else ""
    alive = False
    if pwpid.isdigit():
        try:
            os.kill(int(pwpid), 0)
            alive = True
        except OSError:
            alive = False
    check("micloop: no pw-loopback process is left", not alive)
    rmfake("pw-loopback")
    r = run("micloop.sh", "start", extra=env)
    check("micloop: without pw-loopback it says so and exits 1", r.returncode == 1 and "pw-loopback" in r.stderr)

    # ---------------- move-sink.sh ----------------
    fakecmd("pactl", 'echo "pactl $*" >> "$LOG"\n')
    clear()
    r = run("move-sink.sh", "42", "7")
    check("move-sink: runs pactl move-sink-input with both ids as separate arguments", r.returncode == 0 and calls() == [["pactl", "move-sink-input", "42", "7"]])
    clear()
    for bad in (["42"], [], ["a", "7"], ["42", "x"], ["42;touch pwned", "7"], ["-1", "7"], ["42", "7", "8"], ["", "7"], ["4 2", "7"], ["$(touch pwned)", "7"], ["1e3", "7"]):
        r = run("move-sink.sh", *bad)
        check("move-sink: bad arguments %r exit 2 and run nothing" % (bad,), r.returncode == 2 and calls() == [])
    check("move-sink: nothing was executed from an argument", not (home / "pwned").exists() and not Path("pwned").exists())
    fakecmd("pactl", 'echo "pactl $*" >> "$LOG"\nexit 1\n')
    r = run("move-sink.sh", "42", "7")
    check("move-sink: a failing pactl is reported", r.returncode == 1)

    # ---------------- kdeshare.sh ----------------
    fakecmd("kdeconnect-cli", 'echo "kdeconnect-cli $*" >> "$LOG"\n')
    f = home / "shot one.png"
    f.write_text("x")
    clear()
    r = run("kdeshare.sh", "abc_123", str(f))
    check("kdeshare: a file goes out with --share and the path as one argument", r.returncode == 0 and calls() == [["kdeconnect-cli", "-d", "abc_123", "--share", str(f)]] or (r.returncode == 0 and log.read_text().strip() == "kdeconnect-cli -d abc_123 --share " + str(f)))
    clear()
    r = run("kdeshare.sh", "abc_123", "https://example.org/a?b=1&c=2")
    check("kdeshare: a URL goes out with --share-text", r.returncode == 0 and log.read_text().strip() == "kdeconnect-cli -d abc_123 --share-text https://example.org/a?b=1&c=2")
    clear()
    r = run("kdeshare.sh", "abc_123", "~/shot one.png")
    check("kdeshare: ~/ is expanded against HOME", r.returncode == 0 and log.read_text().strip() == "kdeconnect-cli -d abc_123 --share " + str(home) + "/shot one.png")
    clear()
    r = run("kdeshare.sh", "abc_123", str(home / "missing.png"))
    check("kdeshare: a missing file exits 1 and sends nothing", r.returncode == 1 and calls() == [] and "not a file" in r.stderr)
    for bad in (["bad;id", str(f)], ["", str(f)], ["abc"], [], ["abc", ""], ["-d", str(f)], ["abc", "--share-text"], ["abc", "ftp://x"], ["abc", "javascript:alert(1)"], ["abc_1", str(f), "extra"]):
        clear()
        r = run("kdeshare.sh", *bad)
        check("kdeshare: bad arguments %r exit 2 and send nothing" % (bad,), r.returncode == 2 and calls() == [])
    clear()
    r = run("kdeshare.sh", "abc", "$(touch " + str(home / "pwned") + ")")
    check("kdeshare: nothing is executed from an argument", not (home / "pwned").exists() and calls() == [])

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

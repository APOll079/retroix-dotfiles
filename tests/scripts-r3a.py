#!/usr/bin/env python3
"""Tests quickshell/scripts/endtask.sh, ports.sh, nas.sh, downloads.sh and the pure parts of procs.py.
  python3 tests/scripts-r3a.py     (prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
Every external tool (kill, ss, stat, mount, timeout) is a fake on an isolated PATH that logs its arguments; the real
ones are never run. HOME is a scratch folder. Nothing outside the scratch folder is read or written."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
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
    # real helpers the scripts need, linked in by name (kill, ss, stat, mount, timeout-with-fake-stat are fakes)
    for tool in ("sh", "env", "python3", "timeout", "sleep", "cat", "printf"):
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

    def run(script, *args, extra=None):
        env = {"PATH": str(fake), "HOME": str(home), "LOG": str(log), "LANG": "C"}
        env.update(extra or {})
        return subprocess.run(["/bin/sh", str(S / script), *args], env=env, capture_output=True, text=True, timeout=60)

    def calls():
        return [l.split() for l in log.read_text().splitlines()] if log.exists() else []

    # ---------------- endtask.sh ----------------
    fakecmd("kill", 'echo "kill $*" >> "$LOG"\n')
    procdir = tmp / "proc"
    procdir.mkdir()
    for pid in ("4242", "4343"):
        (procdir / pid).mkdir()          # owned by us: counts as our process
    penv = {"ENDTASK_PROCDIR": str(procdir)}

    r = run("endtask.sh", "4242", "4343", extra=penv)
    check("endtask: SIGTERM to both pids, as separate arguments after --", r.returncode == 0 and calls() == [["kill", "-s", "TERM", "--", "4242", "4343"]])
    check("endtask: never SIGKILL", all("KILL" not in " ".join(c) and "-9" not in c for c in calls()))
    log.write_text("")
    for bad in (["0"], ["1"], ["-1"], ["12; touch pwned"], ["abc"], ["4242", "-1"], ["4242", ""], ["1e3"], ["$(touch pwned)"], ["00"], []):
        r = run("endtask.sh", *bad, extra=penv)
        check("endtask: bad arguments %r exit 2, nothing signalled" % (bad,), r.returncode == 2 and calls() == [])
    check("endtask: nothing was executed from an argument", not (home / "pwned").exists() and not Path("pwned").exists())
    r = run("endtask.sh", "9999", extra=penv)
    check("endtask: a pid that is gone is skipped and nothing is signalled", r.returncode == 1 and calls() == [] and "skipped 9999" in r.stderr)
    r = run("endtask.sh", "4242", "9999", extra=penv)
    check("endtask: only the live, own pid goes out", r.returncode == 0 and calls() == [["kill", "-s", "TERM", "--", "4242"]])
    log.write_text("")
    # another user's process: /proc/<pid> owned by someone else (root's /proc/1 is not ours, ENDTASK_PROCDIR=/proc)
    r = run("endtask.sh", "2", extra={"ENDTASK_PROCDIR": "/proc"})
    check("endtask: a process that is not ours is not signalled", calls() == [] and r.returncode in (1, 2))

    # ---------------- ports.sh ----------------
    SS = """Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
tcp   LISTEN 0      128          0.0.0.0:22        0.0.0.0:*     users:(("sshd",pid=812,fd=3))
tcp   LISTEN 0      128             [::]:22           [::]:*     users:(("sshd",pid=812,fd=4))
tcp   LISTEN 0      4096       127.0.0.1:631       0.0.0.0:*
udp   UNCONN 0      0      127.0.0.53%lo:53        0.0.0.0:*     users:(("systemd-resolve",pid=500,fd=13))
udp   UNCONN 0      0               [::]:5353         [::]:*     users:(("avahi (daemon)",pid=77,fd=12))
tcp   LISTEN 0      5                  *:8080            *:*     users:(("python3",pid=3001,fd=5),("python3",pid=3002,fd=5))
garbage line
tcp   LISTEN notaport
tcp   LISTEN 0 0 host:99999 0.0.0.0:*
raw   UNCONN 0 0 0.0.0.0:255 0.0.0.0:*
"""
    fakecmd("ss", 'echo "ss $*" >> "$LOG"\ncat "$SSOUT"\n')
    (tmp / "ss.out").write_text(SS)
    log.write_text("")
    r = run("ports.sh", extra={"SSOUT": str(tmp / "ss.out")})
    rows = json.loads(r.stdout)
    check("ports: asks ss -ltunp and nothing else", r.returncode == 0 and calls() == [["ss", "-ltunp"]])
    check("ports: junk lines, other protocols and bad ports are skipped", len(rows) == 6)
    ssh = [x for x in rows if x["port"] == 22]
    check("ports: IPv4 and IPv6 of one service both listed with pid and name", len(ssh) == 2 and all(x["pid"] == 812 and x["name"] == "sshd" and x["proto"] == "tcp" for x in ssh))
    check("ports: a socket without an owner has pid null and an empty name", [x for x in rows if x["port"] == 631][0]["pid"] is None and [x for x in rows if x["port"] == 631][0]["name"] == "")
    check("ports: the zone after % is dropped from the address", [x for x in rows if x["port"] == 53][0]["addr"] == "127.0.0.53")
    check("ports: a name with spaces and parentheses survives", [x for x in rows if x["port"] == 5353][0]["name"] == "avahi (daemon)")
    check("ports: the first owner of a shared socket is used", [x for x in rows if x["port"] == 8080][0]["pid"] == 3001)
    check("ports: sorted by port", [x["port"] for x in rows] == sorted(x["port"] for x in rows))
    (fake / "ss").unlink()
    r = run("ports.sh")
    check("ports: no ss gives []", r.returncode == 0 and json.loads(r.stdout) == [])
    fakecmd("ss", "exit 1\n")
    r = run("ports.sh")
    check("ports: a failing ss gives []", json.loads(r.stdout) == [])

    # ---------------- nas.sh ----------------
    mounts = tmp / "mounts"
    mounts.write_text("srv:/a /mnt/disk1 nfs rw 0 0\nsrv:/b /mnt/disk2 nfs rw 0 0\nsrv:/c /mnt/with\\040space nfs rw 0 0\n")
    fakecmd("stat", 'echo "stat $*" >> "$LOG"\ncase "$2" in\n  /mnt/disk2) sleep 20 ;;\n  /mnt/bad) exit 1 ;;\nesac\n')
    fakecmd("mount", 'echo "mount $*" >> "$LOG"\n[ "$2" = /mnt/fail ] && { echo "mount: /mnt/fail: can not reach" >&2; exit 32; }\nexit 0\n')
    nenv = {"NAS_MOUNTS": str(mounts), "NAS_TIMEOUT": "1"}
    log.write_text("")
    r = run("nas.sh", "status", "/mnt/disk1", "/mnt/disk2", "/mnt/disk3", extra=nenv)
    st = {x["path"]: x["state"] for x in json.loads(r.stdout)}
    check("nas: a mounted path that answers is mounted", st["/mnt/disk1"] == "mounted")
    check("nas: a mounted path whose stat hangs is stale (timeout)", st["/mnt/disk2"] == "stale")
    check("nas: a path that is not in the mount table is unmounted and never stat-ed", st["/mnt/disk3"] == "unmounted" and not any(c[:1] == ["stat"] and "/mnt/disk3" in c for c in calls()))
    check("nas: only the mount point is stat-ed (no listing)", all(c[0] in ("stat", "timeout") for c in calls()) and all(len(c) <= 3 for c in calls() if c[0] == "stat"))
    mounts.write_text(mounts.read_text() + "srv:/d /mnt/bad nfs rw 0 0\n")
    r = run("nas.sh", "status", "/mnt/bad", "/mnt/with space".replace(" ", "-"), extra=nenv)
    st = {x["path"]: x["state"] for x in json.loads(r.stdout)}
    check("nas: a failing stat is stale", st["/mnt/bad"] == "stale")
    check("nas: an unknown path is unmounted", st["/mnt/with-space"] == "unmounted")
    for bad in (["status"], ["status", "relative"], ["status", "/mnt/a b"], ["status", "/mnt/../etc"], ["status", "/mnt/x;touch pwned"], ["status", "/"], ["nope"], [], ["remount"], ["remount", "/mnt/disk1"],
                ["remount", "/mnt/other", "/mnt/disk1"], ["remount", "/mnt/disk1;touch pwned", "/mnt/disk1;touch pwned"], ["remount", "../x", "../x"]):
        log.write_text("")
        r = run("nas.sh", *bad, extra=nenv)
        check("nas: bad arguments %r exit 2 and run no tool" % (bad,), r.returncode == 2 and calls() == [])
    check("nas: nothing was executed from an argument", not (home / "pwned").exists() and not Path("pwned").exists())
    log.write_text("")
    r = run("nas.sh", "remount", "/mnt/disk1", "/mnt/disk1", "/mnt/disk2", extra=nenv)
    check("nas: remount runs mount -- <path> for a configured mount", r.returncode == 0 and json.loads(r.stdout) == {"ok": True, "message": ""} and calls() == [["mount", "--", "/mnt/disk1"]])
    log.write_text("")
    r = run("nas.sh", "remount", "/mnt/fail", "/mnt/fail", extra=nenv)
    d = json.loads(r.stdout)
    check("nas: a failing mount reports ok false and the last error line", d["ok"] is False and "can not reach" in d["message"])

    # ---------------- downloads.sh ----------------
    dl = home / "Downloads"
    dl.mkdir()
    for name, size in (("movie.mkv", 5000), ("a.PART", 10), ("b.crdownload", 10), ("c.tmp", 1), (".hidden", 3), ("report.pdf", 12), ("Upper.CrDownload", 4), ("semi;colon $(x).txt", 7)):
        (dl / name).write_bytes(b"x" * size)
    (dl / "sub").mkdir()
    (dl / "sub" / "inner.zip").write_bytes(b"y")
    (dl / "link.txt").symlink_to(dl / "movie.mkv")
    r = run("downloads.sh")
    rows = json.loads(r.stdout)
    check("downloads: lists top-level regular files with sizes", {x["name"]: x["size"] for x in rows} == {"movie.mkv": 5000, "report.pdf": 12, "semi;colon $(x).txt": 7})
    check("downloads: skips .part, .crdownload, .tmp (any case), hidden files, folders and symlinks", len(rows) == 3)
    check("downloads: hostile names stay data", not (home / "x").exists())
    r = run("downloads.sh", str(tmp / "nothing-here"))
    check("downloads: a missing folder gives []", json.loads(r.stdout) == [])
    r = run("downloads.sh", str(dl / "sub"))
    check("downloads: the folder argument is used", [x["name"] for x in json.loads(r.stdout)] == ["inner.zip"])
    check("downloads: the script never opens a file (no open() of file data in the source)", "open(" not in (S / "downloads.sh").read_text())

    # ---------------- procs.py pure parts ----------------
    spec = importlib.util.spec_from_file_location("procs_mod", S / "procs.py")
    procs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(procs)
    NETDEV = """Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 9000000      10    0    0    0     0          0         0  9000000      10    0    0    0     0       0          0
  eth0: 1000      10    0    0    0     0          0         0   400       5    0    0    0     0       0          0
wlan0:   500       5    0    0    0     0          0         0   100       2    0    0    0     0       0          0
 junk: abc
"""
    check("procs: net_totals sums every interface but lo", procs.net_totals(NETDEV) == (1500, 500))
    check("procs: net_totals of nothing is zero", procs.net_totals("") == (0, 0) and procs.net_totals("garbage\n") == (0, 0))
    check("procs: core_effect knows the core processes", all(procs.core_effect(n) != "" for n in ("quickshell", "qs", "Hyprland", "pipewire", "pipewire-pulse", "wireplumber", "dinit", "dinitctl", "dbus-daemon", "dbus-broker")))
    check("procs: core_effect is empty for an ordinary program", procs.core_effect("zen") == "" and procs.core_effect("firefox") == "" and procs.core_effect("") == "")
    r = subprocess.run([sys.executable, "-I", str(S / "procs.py"), "--once"], capture_output=True, text=True, timeout=30)
    d = json.loads(r.stdout)
    check("procs: --once carries net and a core field on every group", set(d["net"]) == {"rx", "tx", "t"} and all("core" in g for g in d["groups"]))

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

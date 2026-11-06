#!/usr/bin/env python3
"""Tests quickshell/scripts/disk-usage.sh and disk-health.sh with fake df / smartctl / lsblk on an isolated PATH.
  python3 tests/script_disk.py     (prints PASS/FAIL lines, exit 1 on a failure)
The fakes log their arguments; the real df, smartctl and lsblk are never run."""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
USAGE = ROOT / "quickshell/scripts/disk-usage.sh"
HEALTH = ROOT / "quickshell/scripts/disk-health.sh"
fails = 0


def check(name, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        fails += 1


with tempfile.TemporaryDirectory() as t:
    tmp = Path(t)
    fake = tmp / "fake"
    fake.mkdir()
    for tool in ("sh", "tail", "grep", "sed", "mktemp", "rm", "timeout", "cat", "sleep", "printf", "head", "id"):
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

    def run(script, *args, path=None, extra=None):
        env = {"PATH": str(path or fake), "HOME": str(tmp), "TMPDIR": str(tmp), "LOG": str(tmp / "log"), "LANG": "C"}
        env.update(extra or {})
        return subprocess.run(["/bin/sh", str(script), *args], env=env, capture_output=True, text=True, timeout=60)

    # ---- disk-usage.sh ----
    fakecmd("df", r'''printf '%s\n' "$*" >> "$LOG"
for a; do m=$a; done
case $m in
  /full) printf 'Filesystem 1-blocks Used Available Capacity Mounted on\n/dev/sda1 1000000000000 930000000000 70000000000 93%% /full\n' ;;
  /ok) printf 'Filesystem 1-blocks Used Available Capacity Mounted on\nserver:/export 500 100 400 20%% /ok\n' ;;
  /hang) sleep 8 ;;
  /broken) echo "df: /broken: Input/output error" >&2; exit 1 ;;
  *) echo "df: $m: No such file or directory" >&2; exit 1 ;;
esac
''')
    r = run(USAGE, "/full", "/ok", extra={"DISK_TIMEOUT": "3"})
    try:
        data = json.loads(r.stdout)
    except Exception as e:
        data = None
    check("usage: valid JSON, exit 0", r.returncode == 0 and isinstance(data, list) and len(data) == 2)
    check("usage: /full parsed", data and data[0] == {"mount": "/full", "usedPercent": 93, "size": 1000000000000, "used": 930000000000, "status": "ok"})
    check("usage: /ok parsed", data and data[1]["usedPercent"] == 20 and data[1]["status"] == "ok")
    check("usage: df called with -P -B1 -- <mount>", (tmp / "log").read_text().splitlines()[0] == "-P -B1 -- /full")

    import time
    t0 = time.time()
    r = run(USAGE, "/hang", "/full", extra={"DISK_TIMEOUT": "1"})
    dt = time.time() - t0
    d = json.loads(r.stdout)
    check("usage: a hung df times out (1 s here) and reports unreachable", d[0]["status"] == "unreachable" and d[0]["usedPercent"] is None and dt < 6)
    check("usage: the mount after the hung one is still read", d[1]["status"] == "ok")
    r = run(USAGE, "/broken")
    check("usage: a failing df is unreachable", json.loads(r.stdout)[0]["status"] == "unreachable")
    r = run(USAGE, "/gone")
    check("usage: a missing path is 'missing'", json.loads(r.stdout)[0]["status"] == "missing")
    r = run(USAGE, '/we"ird\\name', "/ok")
    d = json.loads(r.stdout)
    check("usage: quote and backslash in a mount name stay valid JSON", d[0]["mount"] == '/we"ird\\name' and d[1]["status"] == "ok")
    r = run(USAGE, "/a\nb", "", "/ok")
    check("usage: control characters and empty names are skipped", json.loads(r.stdout) == [{"mount": "/ok", "usedPercent": 20, "size": 500, "used": 100, "status": "ok"}])
    r = run(USAGE)
    check("usage: no mounts gives []", json.loads(r.stdout) == [])
    (tmp / "log").unlink()
    run(USAGE, "-h", "$(touch pwned)", "a b;c")
    lines = (tmp / "log").read_text().splitlines()
    check("usage: odd names reach df only as one argument after --", lines == ["-P -B1 -- -h", "-P -B1 -- $(touch pwned)", "-P -B1 -- a b;c"] and not (tmp / "pwned").exists() and not Path("pwned").exists())

    # ---- disk-health.sh ----
    fakecmd("lsblk", r'''printf 'sda disk\nsdb disk\nnvme0n1 disk\nloop0 loop\nsr0 rom\nzram0 disk\nBad;name disk\nsda1 part\n'
''')
    fakecmd("smartctl", r'''printf '%s\n' "$*" >> "$LOG"
for a; do d=$a; done
case $d in
  /dev/sda) echo '{"smart_status": {"passed": true}}' ;;
  /dev/sdb) echo '{"smart_status": {"passed": false}}'; exit 8 ;;
  /dev/nvme0n1) echo 'Smartctl open device: /dev/nvme0n1 failed: Permission denied'; exit 2 ;;
  /dev/zram0) echo '{"messages":[{"string":"Unknown device type"}]}'; exit 1 ;;
esac
''')
    (tmp / "log").unlink()
    r = run(HEALTH)
    h = json.loads(r.stdout)
    by = {e["dev"]: e for e in h}
    check("health: only type disk with valid names, in order", [e["dev"] for e in h] == ["sda", "sdb", "nvme0n1", "zram0"])
    check("health: passed", by["sda"] == {"dev": "sda", "passed": True, "status": "ok"})
    check("health: failed (smartctl exit 8 does not hide the verdict)", by["sdb"] == {"dev": "sdb", "passed": False, "status": "failed"})
    check("health: Permission denied maps to permission", by["nvme0n1"] == {"dev": "nvme0n1", "passed": None, "status": "permission"})
    check("health: no verdict is missing (silent)", by["zram0"]["status"] == "missing" and by["zram0"]["passed"] is None)
    check("health: smartctl called with -H -j /dev/<name>", (tmp / "log").read_text().splitlines()[0] == "-H -j /dev/sda")
    # doas retry: a fake doas that refuses (no rule), then one that runs the command (nopass rule)
    fakecmd("doas", 'printf "doas %s\\n" "$*" >> "$LOG"\necho "doas: Operation not permitted" >&2\nexit 1\n')
    (tmp / "log").unlink()
    r = run(HEALTH)
    by = {e["dev"]: e for e in json.loads(r.stdout)}
    check("health: doas refused keeps permission", by["nvme0n1"]["status"] == "permission")
    check("health: doas is only tried for the permission disk, with -n", [l for l in (tmp / "log").read_text().splitlines() if l.startswith("doas")] == ["doas -n smartctl -H -j /dev/nvme0n1"])
    fakecmd("doas", 'shift; exec "$@"\n')
    fakecmd("smartctl", r'''for a; do d=$a; done
if [ "$(id -u)" != 0 ] && [ -z "$VIA_DOAS" ]; then echo "Smartctl open device: $d failed: Permission denied"; exit 2; fi
echo '{"smart_status": {"passed": true}}'
''')
    fakecmd("doas", 'shift; VIA_DOAS=1 exec "$@"\n')
    r = run(HEALTH)
    check("health: with a working doas rule the permission disks become ok", {e["status"] for e in json.loads(r.stdout) if e["dev"] in ("sda", "nvme0n1")} == {"ok"})
    (fake / "doas").unlink()
    fakecmd("smartctl", 'exit 4\n')
    r = run(HEALTH)
    check("health: exit status 4 without a verdict maps to permission", {e["status"] for e in json.loads(r.stdout)} == {"permission"})
    (fake / "smartctl").unlink()
    r = run(HEALTH)
    check("health: smartctl not installed: every disk 'missing', exit 0", r.returncode == 0 and {e["status"] for e in json.loads(r.stdout)} == {"missing"} and len(json.loads(r.stdout)) == 4)
    (fake / "lsblk").unlink()
    r = run(HEALTH)
    check("health: lsblk missing gives []", json.loads(r.stdout) == [])

sys.exit(1 if fails else 0)

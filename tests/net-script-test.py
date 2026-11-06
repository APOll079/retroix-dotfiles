#!/usr/bin/env python3
"""Tests quickshell/scripts/net-check.sh and vpn-status.sh with fake nmcli, ping and ip (they log their arguments and
answer from FAKE_* env vars). Isolated PATH, scratch HOME and XDG_RUNTIME_DIR; nothing real is run.

  python3 tests/net-script-test.py        prints TEST pass|FAIL lines and "TEST done failures=N"
"""
import json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NET = ROOT / "quickshell/scripts/net-check.sh"
VPN = ROOT / "quickshell/scripts/vpn-status.sh"

FAKE_NMCLI = r'''#!/bin/sh
printf 'nmcli %s\n' "$*" >>"$FAKE_LOG"
case "$*" in
    "-t -f STATE g") printf '%s\n' "$FAKE_STATE" ;;
    "-t -f NAME,TYPE connection show --active") printf '%b' "$FAKE_CONNS" ;;
esac
'''
FAKE_PING = r'''#!/bin/sh
# last argument is the host; hosts listed in FAKE_DOWN fail
for last; do :; done
printf 'ping %s\n' "$*" >>"$FAKE_LOG"
case " $FAKE_DOWN " in *" $last "*) exit 1 ;; esac
exit 0
'''
FAKE_IP = r'''#!/bin/sh
printf 'ip %s\n' "$*" >>"$FAKE_LOG"
printf '%s' "$FAKE_IPJSON"
'''

failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    if not cond:
        failures += 1


def main():
    work = Path(tempfile.mkdtemp(prefix="qsnet-"))
    try:
        bin_, home, rt = work / "bin", work / "home", work / "run"
        for d in (bin_, home, rt):
            d.mkdir()
        rt.chmod(0o700)
        for tool in ("sh", "sed", "tr", "cut", "head", "cat", "rm", "mktemp", "printf", "dirname", "env", "python3", "echo"):
            p = shutil.which(tool)
            if p and not (bin_ / tool).exists():
                (bin_ / tool).symlink_to(p)
        for name, body in (("nmcli", FAKE_NMCLI), ("ping", FAKE_PING), ("ip", FAKE_IP)):
            (bin_ / name).write_text(body)
            (bin_ / name).chmod(0o755)
        log = work / "fake.log"
        log.write_text("")
        base = {"PATH": str(bin_), "HOME": str(home), "XDG_RUNTIME_DIR": str(rt), "FAKE_LOG": str(log)}

        def run(script, *a, **env):
            return subprocess.run(["sh", str(script), *a], env=dict(base, **env), capture_output=True, text=True, timeout=30)

        # ---- net-check.sh --link
        for st, want in (("connected", "connected"), ("connected (site only)", "connected"), ("disconnected", "disconnected"), ("asleep", "asleep")):
            r = run(NET, "--link", FAKE_STATE=st)
            check("--link %r -> %s" % (st, want), r.returncode == 0 and json.loads(r.stdout) == {"state": want})
        check("--link with empty output is unknown", json.loads(run(NET, "--link", FAKE_STATE="").stdout) == {"state": "unknown"})
        check("--link uses exactly the bar's command", "nmcli -t -f STATE g" in log.read_text().splitlines())
        e = dict(base, PATH=str(work / "nobin"))
        (work / "nobin").mkdir()
        for tool in ("sh", "head", "cut", "tr"):
            (work / "nobin" / tool).symlink_to(shutil.which(tool))
        r = subprocess.run(["sh", str(NET), "--link"], env=e, capture_output=True, text=True)
        check("--link without nmcli: unknown, exit 2", r.returncode == 2 and json.loads(r.stdout) == {"state": "unknown"})
        r = subprocess.run(["sh", str(NET), "1.2.3.4"], env=e, capture_output=True, text=True)
        check("hosts without ping: exit 2 and one line", r.returncode == 2 and r.stderr.strip() == "ping is not installed")

        # ---- net-check.sh hosts
        log.write_text("")
        r = run(NET, "192.168.1.1", "nas.lan", "fe80::1", FAKE_DOWN="nas.lan")
        out = json.loads(r.stdout)
        check("hosts: up/down per host, in argument order", r.returncode == 0 and out == [
            {"host": "192.168.1.1", "up": True}, {"host": "nas.lan", "up": False}, {"host": "fe80::1", "up": True}])
        calls = [l for l in log.read_text().splitlines() if l.startswith("ping ")]
        check("each host gets `ping -c1 -W2 -- host`", sorted(calls) == sorted("ping -c1 -W2 -- " + h for h in ("192.168.1.1", "nas.lan", "fe80::1")))

        log.write_text("")
        evil = ["a; touch PWNED", "$(touch PWNED2)", "-c100", "a b", "x`id`", "", 'q"uote', "back\\slash"]
        r = run(NET, *evil, "ok.lan")
        out = json.loads(r.stdout)
        check("invalid hosts: marked invalid, never pinged", [o.get("invalid") for o in out] == [True] * len(evil) + [None]
              and all(o["up"] is False for o in out[:-1]) and [o["host"] for o in out] == evil + ["ok.lan"])
        check("only the valid host reached ping", [l for l in log.read_text().splitlines() if l.startswith("ping ")] == ["ping -c1 -W2 -- ok.lan"])
        check("nothing was executed", not list(work.glob("PWNED*")) and not list(Path.cwd().glob("PWNED*")))
        check("no arguments: usage, exit 2", run(NET).returncode == 2)

        # ---- vpn-status.sh
        log.write_text("")
        conns = "Wired connection 1:802-3-ethernet\\nwork vpn:vpn\\nhome\\\\:wg:wireguard\\nlo:loopback\\n"
        r = run(VPN, FAKE_CONNS=conns, FAKE_IPJSON="[]")
        check("vpn: keeps vpn and wireguard, unescapes names", r.returncode == 0 and json.loads(r.stdout) == {"up": True, "names": ["work vpn", "home:wg"]})
        check("vpn: uses the argv form of nmcli", "nmcli -t -f NAME,TYPE connection show --active" in log.read_text().splitlines())
        r = run(VPN, FAKE_CONNS="Wired:802-3-ethernet\\n", FAKE_IPJSON="[]")
        check("vpn: only a wired link is down", json.loads(r.stdout) == {"up": False, "names": []})
        r = run(VPN, FAKE_CONNS="", FAKE_IPJSON=json.dumps([{"ifname": "lo"}, {"ifname": "wg0", "linkinfo": {"info_kind": "wireguard"}}, {"ifname": "br0", "linkinfo": {"info_kind": "bridge"}}]))
        check("vpn: wireguard interface fallback when NM lists none", json.loads(r.stdout) == {"up": True, "names": ["wg0"]})
        r = run(VPN, FAKE_CONNS="x:vpn\\n", FAKE_IPJSON=json.dumps([{"ifname": "wg0", "linkinfo": {"info_kind": "wireguard"}}]))
        check("vpn: the fallback does not duplicate an NM-listed VPN", json.loads(r.stdout) == {"up": True, "names": ["x"]})
        r = run(VPN, FAKE_CONNS="", FAKE_IPJSON="not json")
        check("vpn: broken ip output is down", json.loads(r.stdout) == {"up": False, "names": []})
        (work / "pyonly").mkdir()
        for tool in ("sh", "python3", "dirname"):
            (work / "pyonly" / tool).symlink_to(shutil.which(tool))
        r = subprocess.run([shutil.which("sh"), str(VPN)], env=dict(base, PATH=str(work / "pyonly")), capture_output=True, text=True)
        check("vpn: no nmcli or ip installed prints down", r.returncode == 0 and json.loads(r.stdout) == {"up": False, "names": []})
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("TEST done failures=%d" % failures)
    return 1 if failures else 0


sys.exit(main())

#!/bin/sh
# Network page data: your addresses, the gateway, the devices the system already knows on the LAN, and one ping.
#   lan.sh              prints JSON {"addrs":[{"ifname","addr","family","prefix"}], "gateway":{"addr","dev"}|null,
#                       "neigh":[{"addr","mac","state","dev","name"}], "error":""}
#   lan.sh ping <ip>    one `ping -c1 -W2`, prints {"host":"1.1.1.1","ok":true,"ms":12.3,"error":""}
# Addresses come from `ip -j addr` (global scope only: no loopback, no link-local), the gateway from `ip -j route`
# (the default route), the devices from `ip -j neigh` (what the kernel already has cached: nothing is scanned and no DNS
# lookup is made; "name" is filled only from /etc/hosts, "" otherwise). `ping` takes an IP address only (a name or an
# option-looking word is refused). A missing tool gives a one-line "error" ("ip not installed"), never a failure.
# Nothing is changed. Arguments are passed as arguments, never spliced into script text.
exec python3 -I -c '
import ipaddress, json, shutil, subprocess, sys


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout
    except (OSError, subprocess.SubprocessError):
        return 127, ""


def jlist(text):
    try:
        v = json.loads(text)
        return v if isinstance(v, list) else []
    except ValueError:
        return []


def hosts_names(path="/etc/hosts"):
    names = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                parts = line.split("#", 1)[0].split()
                if len(parts) >= 2:
                    names.setdefault(parts[0], parts[1])
    except OSError:
        pass
    return names


def addrs(data):
    out = []
    for itf in data:
        if not isinstance(itf, dict) or itf.get("ifname") == "lo":
            continue
        for a in itf.get("addr_info") or []:
            if not isinstance(a, dict) or a.get("scope") != "global" or not a.get("local"):
                continue
            out.append({"ifname": str(itf.get("ifname", "")), "addr": str(a["local"]), "family": "ipv6" if a.get("family") == "inet6" else "ipv4", "prefix": a.get("prefixlen")})
    return out


def gateway(data):
    best = None
    for r in data:
        if isinstance(r, dict) and r.get("dst") == "default" and r.get("gateway"):
            m = r.get("metric", 0)
            if best is None or m < best[0]:
                best = (m, {"addr": str(r["gateway"]), "dev": str(r.get("dev", ""))})
    return best[1] if best else None


def sortkey(addr):
    return (":" in addr, [int(p) if p.isdigit() else 0 for p in addr.replace(":", ".").split(".")])


def neigh(data, names):
    out = []
    for n in data:
        if not isinstance(n, dict) or not n.get("lladdr") or not n.get("dst"):
            continue
        st = n.get("state") or []
        out.append({"addr": str(n["dst"]), "mac": str(n["lladdr"]), "state": str(st[0]) if st else "", "dev": str(n.get("dev", "")), "name": names.get(str(n["dst"]), "")})
    out.sort(key=lambda x: sortkey(x["addr"]))
    return out


def ping(host):
    try:
        ipaddress.ip_address(host)
    except ValueError:
        return {"host": host[:64], "ok": False, "ms": None, "error": "not an IP address"}
    if not shutil.which("ping"):
        return {"host": host, "ok": False, "ms": None, "error": "ping not installed"}
    code, out = run(["ping", "-c1", "-W2", "--", host], 6)
    ms = None
    for part in out.split():
        if part.startswith("time="):
            try:
                ms = float(part[5:])
            except ValueError:
                pass
    ok = code == 0 and ms is not None
    return {"host": host, "ok": ok, "ms": ms, "error": "" if ok else "no answer"}


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "ping":
        print(json.dumps(ping(a[1])))
        return 0
    if a:
        return 2
    if not shutil.which("ip"):
        print(json.dumps({"addrs": [], "gateway": None, "neigh": [], "error": "ip not installed"}))
        return 0
    _, ta = run(["ip", "-j", "addr"])
    _, tr = run(["ip", "-j", "route"])
    _, tn = run(["ip", "-j", "neigh"])
    print(json.dumps({"addrs": addrs(jlist(ta)), "gateway": gateway(jlist(tr)), "neigh": neigh(jlist(tn), hosts_names()), "error": ""}))
    return 0


sys.exit(main())
' "$@"

#!/usr/bin/env python3
"""Tests quickshell/scripts/filesearch.sh, lan.sh, speedtest.sh and rates.sh.
  python3 tests/scripts-r4c.py     (prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
Every external tool (fd, plocate, ip, ping, curl) is a fake on an isolated PATH that logs its arguments; the real ones are
never run. `find` is the real one but only ever sees the scratch HOME tree made here. Nothing outside the scratch folder
is touched."""
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

    def link(tool):
        for d in ("/usr/bin", "/bin"):
            if (Path(d) / tool).exists():
                (fake / tool).symlink_to(Path(d) / tool)
                return

    link("python3")
    link("sh")
    link("env")
    link("cat")

    def fakecmd(name, body):
        p = fake / name
        if p.exists() or p.is_symlink():
            p.unlink()
        p.write_text("#!/bin/sh\n" + body)
        p.chmod(0o755)

    def unfake(name):
        p = fake / name
        if p.exists() or p.is_symlink():
            p.unlink()

    def run(script, *args, env=None):
        e = {"PATH": str(fake), "HOME": str(home), "LC_ALL": "C.UTF-8"}
        if env:
            e.update(env)
        r = subprocess.run(["sh", str(S / script), *args], env=e, capture_output=True, text=True, timeout=60)
        return r.returncode, r.stdout, r.stderr

    def logged():
        return log.read_text() if log.exists() else ""

    def reset():
        if log.exists():
            log.unlink()

    # ---------- a made-up home tree with hostile names ----------
    def touch(rel, data=""):
        p = home / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(data)

    touch("docs/Annual Report 2025.txt")
    touch("docs/-dash report.txt")
    touch("docs/quote'\"report.txt")
    touch("docs/new\nline report.txt")
    touch("docs/a*b report.txt")
    touch("docs/axxb report.txt")
    touch("docs/notes.txt")
    touch(".hidden/report.txt")
    touch(".cache/report.txt")
    touch(".local/share/Trash/files/report.txt")
    touch("proj/node_modules/pkg/report.js")
    touch("proj/.git/report")
    touch("proj/src/report.c")
    touch("Reports/readme.md")
    touch("deep/1/2/3/4/5/6/report-too-deep.txt")
    touch(".dotreport")
    sub = home / "docs/Report Folder"
    sub.mkdir()
    (home / "docs/$(touch pwned)").mkdir()

    # ================= filesearch.sh =================
    # --- find fallback (no fd, no plocate), real find on the scratch tree ---
    link("find")
    code, out, _ = run("filesearch.sh", "report")
    lines = out.splitlines()
    names = {os.path.basename(l.rstrip("/")) for l in lines}
    check("find: exit 0", code == 0)
    check("find: matches case-insensitively on names", "Annual Report 2025.txt" in names and "Reports" in names)
    check("find: a folder gets a trailing slash, a file does not", f"{home}/Reports/" in lines and f"{home}/docs/Annual Report 2025.txt" in lines)
    check("find: name with a leading dash, quotes and spaces comes through intact", "-dash report.txt" in names and "quote'\"report.txt" in names)
    check("find: a name with a newline is skipped (cannot be one line)", not any("new" == l for l in lines) and not any("line report" in l for l in lines))
    check("find: hidden files and folders, .cache, Trash, node_modules, .git are skipped", not any(".hidden" in l or ".cache" in l or "Trash" in l or "node_modules" in l or ".git" in l or ".dotreport" in l for l in lines))
    check("find: a normal source file is found", f"{home}/proj/src/report.c" in lines)
    check("find: depth is limited to 6", not any("too-deep" in l for l in lines))
    check("find: every line is an absolute path under HOME", all(l.startswith(str(home) + "/") for l in lines))
    code, out, _ = run("filesearch.sh", "a*b")
    check("find: glob characters in the query are literal", [os.path.basename(l) for l in out.splitlines()] == ["a*b report.txt"])
    code, out, _ = run("filesearch.sh", "[ab]")
    check("find: brackets are literal too (no match)", code == 0 and out == "")
    code, out, _ = run("filesearch.sh", "$(touch pwned)")
    check("find: shell syntax in the query is never run", not (home / "pwned").exists() and not Path("pwned").exists() and code == 0)
    check("find: a folder named like shell syntax is matched literally", [os.path.basename(l.rstrip("/")) for l in out.splitlines()] == ["$(touch pwned)"])

    # --- the query is validated ---
    check("bad query: leading dash exits 2", run("filesearch.sh", "-rf")[0] == 2)
    check("bad query: 101 characters exits 2", run("filesearch.sh", "x" * 101)[0] == 2)
    check("bad query: 100 characters is fine", run("filesearch.sh", "x" * 100)[0] == 0)
    check("bad query: newline exits 2", run("filesearch.sh", "a\nb")[0] == 2)
    check("bad query: empty without a folder exits 2", run("filesearch.sh", "")[0] == 2)
    check("bad query: no argument exits 2", run("filesearch.sh")[0] == 2)

    # --- folder argument ---
    code, out, _ = run("filesearch.sh", "report", "~/proj")
    check("folder: ~/proj limits the search", [os.path.basename(l) for l in out.splitlines()] == ["report.c"])
    check("folder: a missing folder exits 4", run("filesearch.sh", "x", str(home / "nope"))[0] == 4)
    check("folder: a relative folder exits 4", run("filesearch.sh", "x", "docs")[0] == 4)
    check("folder: a file is not a folder (exit 4)", run("filesearch.sh", "x", str(home / "docs/notes.txt"))[0] == 4)
    code, out, _ = run("filesearch.sh", "", str(home / "Reports"))
    check("folder: an empty query with a folder lists names there", code == 0 and out.splitlines() == [f"{home}/Reports/readme.md"])

    # --- fd (preferred) ---
    fake_out = tmp / "fakeout"
    paths = [f"{home}/docs/p{i}.txt" for i in range(80)]
    fake_out.write_bytes(b"\0".join(p.encode() for p in paths) + b"\0")
    fakecmd("fd", f'echo "$@" > {log}; cat {fake_out}\n')
    reset()
    code, out, _ = run("filesearch.sh", "report")
    a = logged()
    check("fd: used first, with the fixed-string, case-insensitive, limit and exclusion flags",
          "--fixed-strings" in a and "--ignore-case" in a and "--max-results 50" in a and "--exclude node_modules" in a and "--exclude .git" in a)
    check("fd: query and folder come after --", a.strip().endswith(f"-- report {home}"))
    check("fd: hidden files are not asked for", "--hidden" not in a and "--no-ignore" not in a)
    check("fd: output is cut to 50 lines", len(out.splitlines()) == 50)
    reset()
    run("filesearch.sh", "a b")
    check("fd: a query with a space is one argument", f"-- a b {home}" in logged())
    unfake("fd")

    # --- plocate ---
    plo = [f"{home}/docs/Annual Report 2025.txt", f"{home}/proj/node_modules/pkg/report.js", f"{home}/docs/notes-about-report-in-dir/zzz", f"{home}/Reports"]
    fake_out.write_bytes(b"\0".join(p.encode() for p in plo) + b"\0")
    fakecmd("plocate", f'echo "$@" > {log}; cat {fake_out}\n')
    reset()
    code, out, _ = run("filesearch.sh", "re.port")
    a = logged()
    check("plocate: -i -l 50 --regex, pattern restricted to HOME and escaped", "-i -l 50" in a and "--regex" in a and ("^" + str(home) + "/([^/.][^/]*/)*[^/]*re\\.port[^/]*$") in a)
    code, out, _ = run("filesearch.sh", "report")
    check("plocate: node_modules hits and directory-only matches are dropped, a folder gets a slash",
          out.splitlines() == [f"{home}/docs/Annual Report 2025.txt", f"{home}/Reports/"])
    unfake("plocate")

    # --- nothing installed ---
    unfake("find")
    code, out, _ = run("filesearch.sh", "report")
    check("no fd, plocate or find: exit 3 and no output", code == 3 and out == "")

    # ================= lan.sh =================
    ip_addr = json.dumps([
        {"ifname": "lo", "addr_info": [{"family": "inet", "local": "127.0.0.1", "prefixlen": 8, "scope": "host"}]},
        {"ifname": "eth0", "addr_info": [
            {"family": "inet", "local": "192.168.1.20", "prefixlen": 24, "scope": "global"},
            {"family": "inet6", "local": "2001:db8::2", "prefixlen": 64, "scope": "global"},
            {"family": "inet6", "local": "fe80::1", "prefixlen": 64, "scope": "link"}]}])
    ip_route = json.dumps([
        {"dst": "default", "gateway": "10.9.9.9", "dev": "wlan0", "metric": 600},
        {"dst": "default", "gateway": "192.168.1.1", "dev": "eth0", "metric": 100},
        {"dst": "192.168.1.0/24", "dev": "eth0", "protocol": "kernel"}])
    ip_neigh = json.dumps([
        {"dst": "192.168.1.30", "dev": "eth0", "lladdr": "aa:bb:cc:00:00:30", "state": ["STALE"]},
        {"dst": "192.168.1.9", "dev": "eth0", "lladdr": "aa:bb:cc:00:00:09", "state": ["REACHABLE"]},
        {"dst": "192.168.1.77", "dev": "eth0", "state": ["FAILED"]},
        {"dst": "fe80::2", "dev": "eth0", "lladdr": "aa:bb:cc:00:00:02", "state": ["DELAY"]}])
    (tmp / "addr.json").write_text(ip_addr)
    (tmp / "route.json").write_text(ip_route)
    (tmp / "neigh.json").write_text(ip_neigh)
    fakecmd("ip", f'echo "$@" >> {log}\ncase "$2" in addr) cat {tmp}/addr.json;; route) cat {tmp}/route.json;; neigh) cat {tmp}/neigh.json;; esac\n')
    reset()
    code, out, _ = run("lan.sh")
    d = json.loads(out)
    check("lan: exit 0 and the three ip -j calls were made", code == 0 and logged().splitlines() == ["-j addr", "-j route", "-j neigh"])
    check("lan: global addresses only (no loopback, no link-local)", [a["addr"] for a in d["addrs"]] == ["192.168.1.20", "2001:db8::2"] and d["addrs"][0]["prefix"] == 24)
    check("lan: the gateway is the lowest-metric default route", d["gateway"] == {"addr": "192.168.1.1", "dev": "eth0"})
    check("lan: devices without a MAC are left out and the rest are sorted by address", [n["addr"] for n in d["neigh"]] == ["192.168.1.9", "192.168.1.30", "fe80::2"])
    check("lan: neighbour state and MAC are passed on", d["neigh"][0]["state"] == "REACHABLE" and d["neigh"][0]["mac"] == "aa:bb:cc:00:00:09")
    check("lan: error is empty and no name is invented", d["error"] == "" and all(n["name"] == "" for n in d["neigh"]))
    fakecmd("ip", "echo 'not json'\n")
    code, out, _ = run("lan.sh")
    d = json.loads(out)
    check("lan: garbage from ip gives empty lists, not a failure", code == 0 and d["addrs"] == [] and d["gateway"] is None and d["neigh"] == [])
    unfake("ip")
    code, out, _ = run("lan.sh")
    check("lan: no ip tool gives a one-line error", code == 0 and json.loads(out)["error"] == "ip not installed")
    check("lan: an unknown argument exits 2", run("lan.sh", "scan")[0] == 2)

    # ping
    fakecmd("ping", f'echo "$@" >> {log}\necho "64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=12.3 ms"\n')
    reset()
    code, out, _ = run("lan.sh", "ping", "192.168.1.1")
    d = json.loads(out)
    check("ping: one echo, -c1 -W2, address after --", logged().strip() == "-c1 -W2 -- 192.168.1.1")
    check("ping: ms is read from the reply", d["ok"] is True and d["ms"] == 12.3 and d["host"] == "192.168.1.1")
    reset()
    d = json.loads(run("lan.sh", "ping", "1.1.1.1")[1])
    check("ping: 1.1.1.1 works the same", d["ok"] and logged().strip() == "-c1 -W2 -- 1.1.1.1")
    reset()
    d = json.loads(run("lan.sh", "ping", "example.com")[1])
    check("ping: a host name is refused and ping is not run", d["ok"] is False and d["error"] == "not an IP address" and logged() == "")
    d = json.loads(run("lan.sh", "ping", "-c5")[1])
    check("ping: an option-looking word is refused", d["ok"] is False and logged() == "")
    fakecmd("ping", 'echo "From 192.168.1.20 icmp_seq=1 Destination Host Unreachable"\nexit 1\n')
    d = json.loads(run("lan.sh", "ping", "192.168.1.1")[1])
    check("ping: no answer is ok=false with a short line", d["ok"] is False and d["ms"] is None and d["error"] == "no answer")
    unfake("ping")
    d = json.loads(run("lan.sh", "ping", "1.1.1.1")[1])
    check("ping: no ping tool gives a one-line error", d["ok"] is False and d["error"] == "ping not installed")

    # ================= speedtest.sh =================
    url = "https://speed.example.test/__down?bytes=25000000"
    fakecmd("curl", f'echo "$@" > {log}\nprintf "11650000.000"\n')
    reset()
    code, out, _ = run("speedtest.sh", url)
    d = json.loads(out)
    a = logged()
    check("speedtest: ok with bytes per second and Mbit/s", code == 0 and d["ok"] and d["bytesPerSec"] == 11650000 and d["mbit"] == 93.2 and d["partial"] is False)
    check("speedtest: curl gets the 20 s limit, /dev/null, the -w format and the URL after --",
          "--max-time 20" in a and "-o /dev/null" in a and "-w %{speed_download}" in a and a.strip().endswith("-- " + url))
    reset()
    d = json.loads(run("speedtest.sh", "ftp://x/y")[1])
    check("speedtest: a non-http URL is refused and curl is not run", d["ok"] is False and logged() == "")
    d = json.loads(run("speedtest.sh", "https://x/a b")[1])
    check("speedtest: a URL with a space is refused", d["ok"] is False)
    check("speedtest: no URL exits 2", run("speedtest.sh")[0] == 2)
    fakecmd("curl", 'printf "4000000.000"\nexit 28\n')
    d = json.loads(run("speedtest.sh", url)[1])
    check("speedtest: the 20 s limit still reports the speed so far, marked partial", d["ok"] and d["partial"] and d["mbit"] == 32.0)
    fakecmd("curl", 'printf "0.000"\necho "curl: (6) Could not resolve host: speed.example.test" >&2\nexit 6\n')
    code, out, _ = run("speedtest.sh", url)
    d = json.loads(out)
    check("speedtest: a failed download is ok=false with curl's last line, exit 0", code == 0 and not d["ok"] and "Could not resolve" in d["error"])
    unfake("curl")
    d = json.loads(run("speedtest.sh", url)[1])
    check("speedtest: no curl gives a one-line error", not d["ok"] and d["error"] == "curl not installed")

    # ================= rates.sh =================
    fixture = {"amount": 1.0, "base": "EUR", "date": "2026-11-06", "rates": {"SEK": 11.234, "USD": 1.08, "bad": 3, "XX": 2, "ZZZ": -1, "TRY": True, "JPY": 160}}
    (tmp / "rates.json").write_text(json.dumps(fixture))
    fakecmd("curl", f'echo "$@" > {log}\ncat {tmp}/rates.json\n')
    reset()
    code, out, _ = run("rates.sh")
    d = json.loads(out)
    check("rates: ok, dated, EUR = 1 added, only valid codes kept", code == 0 and d["ok"] and d["date"] == "2026-11-06" and d["rates"] == {"EUR": 1, "SEK": 11.234, "USD": 1.08, "JPY": 160})
    check("rates: curl -fsS --max-time 10 with the frankfurter URL", logged().startswith("-fsS --max-time 10") and logged().strip().endswith("https://api.frankfurter.app/latest?from=EUR"))
    check("rates: arguments are refused", run("rates.sh", "x")[0] == 2)
    fakecmd("curl", 'echo "curl: (6) Could not resolve host" >&2\nexit 6\n')
    code, out, _ = run("rates.sh")
    d = json.loads(out)
    check("rates: no network is ok=false with a line, exit 0", code == 0 and not d["ok"] and "resolve" in d["error"] and d["rates"] == {})
    fakecmd("curl", 'echo "<html>nope</html>"\n')
    d = json.loads(run("rates.sh")[1])
    check("rates: a garbage answer is ok=false", not d["ok"])
    fakecmd("curl", 'echo "{\\"date\\":\\"2026-11-06\\",\\"rates\\":{}}"\n')
    d = json.loads(run("rates.sh")[1])
    check("rates: an empty rates table is ok=false", not d["ok"])
    unfake("curl")
    d = json.loads(run("rates.sh")[1])
    check("rates: no curl gives a one-line error", not d["ok"] and d["error"] == "curl not installed")

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

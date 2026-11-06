#!/usr/bin/env python3
"""Script tests for quickshell/scripts/updates.sh and cleanup.sh. Stdlib only.

  python3 tests/scripts-cleanup-updates.py     prints "TEST pass|FAIL ..." lines and "TEST done failures=N"

Everything runs with an isolated PATH (fakes that log their arguments as JSON lines, plus symlinks to the few
real coreutils the scripts need) and a scratch HOME. The real pacman, yay, checkupdates, paccache, flatpak,
gio, curl and doas are never reachable. Deleting paths only ever run against the fakes.
"""
import json, os, shutil, stat, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UPD = ROOT / "quickshell/scripts/updates.sh"
CLN = ROOT / "quickshell/scripts/cleanup.sh"
failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    if not cond:
        failures += 1


FAKE_LOGGER = """#!/usr/bin/env python3
import json, os, sys
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(json.dumps([os.path.basename(sys.argv[0])] + sys.argv[1:]) + "\\n")
"""


def fake(bindir, name, body="", rc=0):
    """A fake tool: logs its argv, prints `body`, exits rc."""
    p = Path(bindir) / name
    p.write_text(FAKE_LOGGER + "sys.stdout.write(%r)\nsys.exit(%d)\n" % (body, rc))
    p.chmod(0o755)


def make_env(tools, scratch):
    """PATH = fakes + links to the real basics only. Returns (env, log path)."""
    fakes = Path(scratch) / "fakes"
    links = Path(scratch) / "links"
    fakes.mkdir()
    links.mkdir()
    for t in ("sh", "env", "find", "xargs", "du", "python3", "wc", "tr", "timeout", "cat", "mkdir", "rm"):
        real = shutil.which(t)
        if real:
            (links / t).symlink_to(real)
    for name, (body, rc) in tools.items():
        fake(fakes, name, body, rc)
    home = Path(scratch) / "home"
    home.mkdir(exist_ok=True)
    log = Path(scratch) / "calls.log"
    log.write_text("")
    env = {"PATH": "%s:%s" % (fakes, links), "HOME": str(home), "FAKE_LOG": str(log), "XDG_RUNTIME_DIR": str(Path(scratch) / "run")}
    return env, log


def calls(log):
    return [json.loads(l) for l in log.read_text().splitlines() if l]


def sh(script, args, env):
    r = subprocess.run(["sh", str(script)] + args, env=env, capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout, r.stderr


PACCACHE = "==> finished dry run: 7 candidates (disk space that would be saved: 1.50 MiB)\n"
PACMAN_QI = "Name : a\nInstalled Size  : 2.00 MiB\n\nName : b\nInstalled Size  : 512.00 KiB\n"


with tempfile.TemporaryDirectory(prefix="wc-") as scratch:
    scratch = Path(scratch)

    # ---------------- updates.sh ----------------
    s1 = scratch / "u1"
    s1.mkdir()
    env, log = make_env({
        "checkupdates": ("a 1 -> 2\nb 1 -> 2\nc 1 -> 2\n", 0),
        "yay": ("aur1 1 -> 2\n", 0),
        "flatpak": ("org.a\norg.b\n", 0),
    }, s1)
    rc, out, _ = sh(UPD, [], env)
    d = json.loads(out)
    check("updates: counts from the three tools", rc == 0 and d == {"pacman": 3, "aur": 1, "flatpak": 2, "error": ""})
    c = calls(log)
    check("updates: yay is asked only for -Qua", ["yay", "-Qua"] in c and all(x[0] != "yay" or x[1:] == ["-Qua"] for x in c))
    check("updates: flatpak is asked read-only", ["flatpak", "remote-ls", "--updates", "--columns=application"] in c)

    s2 = scratch / "u2"
    s2.mkdir()
    env, log = make_env({}, s2)
    rc, out, _ = sh(UPD, [], env)
    check("updates: no tools at all gives nulls and no error", rc == 0 and json.loads(out) == {"pacman": None, "aur": None, "flatpak": None, "error": ""})

    s3 = scratch / "u3"
    s3.mkdir()
    env, log = make_env({"checkupdates": ("", 2), "yay": ("", 1), "flatpak": ("", 0)}, s3)
    rc, out, _ = sh(UPD, [], env)
    check("updates: checkupdates rc 2 / yay rc 1 / empty flatpak mean zero", json.loads(out) == {"pacman": 0, "aur": 0, "flatpak": 0, "error": ""})

    s4 = scratch / "u4"
    s4.mkdir()
    env, log = make_env({"checkupdates": ("boom", 7)}, s4)
    rc, out, _ = sh(UPD, [], env)
    check("updates: a failing tool gives null", json.loads(out)["pacman"] is None)

    RSS = """<?xml version="1.0"?><rss><channel>
""" + "".join(
        "<item><title>News %d: &lt;b&gt;x&lt;/b&gt; $(rm -rf ~)</title><pubDate>Mon, 0%d Jun 2026 10:00:00 +0000</pubDate></item>\n" % (i, i)
        for i in range(1, 8)) + "</channel></rss>"
    s5 = scratch / "u5"
    s5.mkdir()
    env, log = make_env({"curl": (RSS, 0)}, s5)
    rc, out, _ = sh(UPD, ["news"], env)
    n = json.loads(out)
    check("news: newest 5 items", rc == 0 and len(n) == 5 and n[0]["title"].startswith("News 1:"))
    check("news: date is YYYY-MM-DD", n[0]["date"] == "2026-06-01")
    check("news: title stays text from outside (markup and $() untouched)", n[0]["title"] == "News 1: <b>x</b> $(rm -rf ~)")
    check("news: curl is called with the fixed flags and URL", calls(log) == [["curl", "-fsS", "--max-time", "10", "https://archlinux.org/feeds/news/"]])

    s6 = scratch / "u6"
    s6.mkdir()
    env, log = make_env({"curl": ("", 22)}, s6)
    rc, out, _ = sh(UPD, ["news"], env)
    check("news: curl failure gives []", rc == 0 and json.loads(out) == [])
    (scratch / "u7").mkdir()
    env, log = make_env({"curl": ("not xml at all <<<", 0)}, scratch / "u7")
    rc, out, _ = sh(UPD, ["news"], env)
    check("news: broken XML gives []", json.loads(out) == [])
    (scratch / "u8").mkdir()
    env, log = make_env({}, scratch / "u8")
    rc, out, _ = sh(UPD, ["news"], env)
    check("news: no curl gives []", json.loads(out) == [])
    rc, out, err = sh(UPD, ["bogus"], env)
    check("updates: unknown argument exits 2", rc == 2)

    # ---------------- cleanup.sh ----------------
    def cleanup_env(name, tools):
        d = scratch / name
        d.mkdir()
        env, log = make_env(tools, d)
        home = Path(env["HOME"])
        shots = home / "screenshots"
        shots.mkdir()
        old = time.time() - 40 * 86400
        names_old = ["old one.png", "-rf", "x'; touch pwned; '.png", "$(touch pwned2).png", "semi;colon.png"]
        for nme in names_old:
            p = shots / nme
            p.write_bytes(b"x" * 100)
            os.utime(p, (old, old))
        for nme in ("new1.png", "new2.png"):
            (shots / nme).write_bytes(b"y" * 50)
        trash = home / ".local/share/Trash/files"
        trash.mkdir(parents=True)
        (trash / "junk").write_bytes(b"z" * 5000)
        return env, log, home, shots, names_old

    tools = {
        "paccache": (PACCACHE, 0),
        "pacman": ("", 0),
        "flatpak": ("", 0),
        "gio": ("", 0),
    }
    env, log, home, shots, old_names = cleanup_env("c1", tools)
    # a pacman that answers per mode
    pm = Path(env["PATH"].split(":")[0]) / "pacman"
    pm.write_text(FAKE_LOGGER + """
if sys.argv[1:2] == ["-Qdtq"]:
    print("a\\nb")
elif sys.argv[1:2] == ["-Qi"]:
    sys.stdout.write(%r)
""" % PACMAN_QI)
    fp = Path(env["PATH"].split(":")[0]) / "flatpak"
    fp.write_text(FAKE_LOGGER + """
print("Info: runtimes\\n\\n        ID   Branch  Op\\n 1.     org.x.Platform  23.08   r\\n 2.     org.y.Platform  22.08   r\\n\\nNothing to do.")
""")
    rc, out, _ = sh(CLN, ["sizes", "30"], env)
    rows = {r["id"]: r for r in json.loads(out)}
    check("sizes: five rows in order", rc == 0 and list(rows) == ["pacman-cache", "orphans", "flatpak-unused", "shots", "trash"])
    check("sizes: paccache dry run parsed (bytes, count, root)", rows["pacman-cache"]["bytes"] == int(1.5 * 1024**2) and rows["pacman-cache"]["count"] == 7 and rows["pacman-cache"]["needsRoot"] is True)
    check("sizes: orphans counted and sizes summed", rows["orphans"]["count"] == 2 and rows["orphans"]["bytes"] == 2 * 1024**2 + 512 * 1024 and rows["orphans"]["needsRoot"] is True)
    check("sizes: flatpak unused counted, size null", rows["flatpak-unused"]["count"] == 2 and rows["flatpak-unused"]["bytes"] is None)
    check("sizes: shots counts only the old files", rows["shots"]["count"] == len(old_names) and rows["shots"]["bytes"] == 100 * len(old_names))
    check("sizes: trash size comes from du", rows["trash"]["bytes"] >= 5000)
    c = calls(log)
    check("sizes: paccache only dry (-d)", [x for x in c if x[0] == "paccache"] == [["paccache", "-d", "-k2"]])
    check("sizes: flatpak only with --assumeno", [x for x in c if x[0] == "flatpak"] == [["flatpak", "uninstall", "--unused", "--assumeno"]])
    check("sizes: gio is never called", not any(x[0] == "gio" for x in c))
    check("sizes: output has no file names", "old one" not in out and "semi" not in out)
    check("sizes: nothing deleted", len(list(shots.iterdir())) == len(old_names) + 2)
    rc, out, _ = sh(CLN, ["sizes", "x"], env)
    check("sizes: shotDays must be an integer (exit 2)", rc == 2)
    rc, out, _ = sh(CLN, ["sizes", "30; touch pwned"], env)
    check("sizes: hostile shotDays exit 2", rc == 2 and not (home / "pwned").exists())

    # run
    rc, out, _ = sh(CLN, ["run", "pacman-cache", "30"], env)
    check("run: pacman-cache prints the doas command and runs nothing", rc == 0 and json.loads(out) == {"terminal": "doas paccache -r -k2"} and [x for x in calls(log) if x[0] == "paccache"] == [["paccache", "-d", "-k2"]])
    rc, out, _ = sh(CLN, ["run", "orphans", "30"], env)
    check("run: orphans prints the doas command", rc == 0 and json.loads(out) == {"terminal": "doas pacman -Rns $(pacman -Qdtq)"} and not any(x[:2] == ["pacman", "-Rns"] for x in calls(log)))
    log.write_text("")
    rc, out, _ = sh(CLN, ["run", "shots", "30"], env)
    g = [x for x in calls(log) if x[0] == "gio"]
    trashed = sorted(a for x in g for a in x[2:]) if g else []
    check("run shots: gio trash called once with only the old files", rc == 0 and len(g) == 1 and g[0][1] == "trash" and trashed == sorted(str(shots / n) for n in old_names))
    check("run shots: hostile names stayed single arguments, nothing executed", not (home / "pwned").exists() and not (shots / "pwned2").exists() and not (home / "pwned2").exists() and not Path("pwned").exists())
    check("run shots: new files are not passed", not any("new" in a for a in trashed))
    log.write_text("")
    rc, out, _ = sh(CLN, ["run", "trash", "30"], env)
    check("run trash is refused: exit 2 and nothing is called", rc == 2 and calls(log) == [])
    log.write_text("")
    rc, out, _ = sh(CLN, ["run", "flatpak-unused", "30"], env)
    check("run flatpak-unused: uninstall --unused -y", rc == 0 and calls(log) == [["flatpak", "uninstall", "--unused", "-y"]])
    log.write_text("")
    for bad in (["run", "bogus", "30"], ["run", "shots", "abc"], ["run", "shots; touch pwned", "30"], ["run", "../x", "1"], ["run"], ["nope"], []):
        rc, out, _ = sh(CLN, bad, env)
        check("run: bad arguments %r exit 2" % (bad,), rc == 2)
    check("run: bad arguments ran no tool", calls(log) == [] and not (home / "pwned").exists())

    # missing tools
    d = scratch / "c2"
    d.mkdir()
    env2, log2 = make_env({}, d)
    rc, out, _ = sh(CLN, ["sizes", "30"], env2)
    rows = {r["id"]: r for r in json.loads(out)}
    check("sizes: missing tools give null bytes and 'not installed', no error",
          rc == 0 and all(rows[i]["bytes"] is None and rows[i]["note"] == "not installed" for i in ("pacman-cache", "orphans", "flatpak-unused")) and rows["shots"]["bytes"] == 0 and rows["trash"]["bytes"] == 0)

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

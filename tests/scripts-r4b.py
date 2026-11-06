#!/usr/bin/env python3
"""Tests of the round-4b scripts: procs.py GPU / VRAM / disk fields, defaultapps.sh, fixes.sh, loginreport.py, solaar.sh,
games.py flatpak entries and secaudit.sh.
  python3 tests/scripts-r4b.py     (prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
Every external tool (xdg-settings, xdg-mime, dinitctl, pkill, solaar, flatpak, arch-audit, ...) is a fake on an isolated PATH that
logs its arguments; the real ones are never run. HOME, XDG_RUNTIME_DIR and the fake /proc are scratch folders."""
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


tmp_ctx = tempfile.TemporaryDirectory()
tmp = Path(tmp_ctx.name)
fake = tmp / "fake"
fake.mkdir()
home = tmp / "home"
home.mkdir()
run = tmp / "run"
run.mkdir()
log = tmp / "log"
log.write_text("")
for tool in ("sh", "env", "python3", "cat", "printf", "sleep", "grep", "sed", "head", "tr", "id", "dirname", "basename", "mkdir", "date", "wc", "sort", "cut", "awk", "tail"):
    for d in ("/usr/bin", "/bin"):
        if (Path(d) / tool).exists():
            (fake / tool).symlink_to(Path(d) / tool)
            break


def fakecmd(name, body):
    p = fake / name
    p.write_text("#!/bin/sh\n" + body + "\n")
    p.chmod(0o755)


def logger(name, extra=""):
    """A fake tool that logs `name args...` one line per call"""
    fakecmd(name, f'echo "{name} $*" >> "{log}"\n{extra}')


def sh(script, *args, env=None):
    e = {"PATH": str(fake), "HOME": str(home), "XDG_RUNTIME_DIR": str(run), "LC_ALL": "C"}
    e.update(env or {})
    return subprocess.run([str(S / script), *args], env=e, capture_output=True, text=True, timeout=30)


def calls():
    return [l for l in log.read_text().splitlines() if l]


def reset():
    log.write_text("")


def load(name, path, env=None):
    for k, v in (env or {}).items():
        os.environ[k] = v
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# ---------------------------------------------------------------- items 14 / 15: procs.py GPU, VRAM, disk I/O
def procs_tests():
    fp = tmp / "proc"
    (fp / "net").mkdir(parents=True)
    (fp / "stat").write_text("cpu  100 0 100 800 0 0 0 0 0 0\n")
    (fp / "meminfo").write_text("MemTotal: 1000 kB\nMemAvailable: 500 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n")
    (fp / "net/dev").write_text("Inter-|\n face |\n  lo: 1 0 0 0 0 0 0 0 1 0\n")

    def mkproc(pid, comm, client=None, vram_kib=None, eng=None, rd=None, wr=None, fdlink="/dev/dri/renderD128", drm=True):
        d = fp / str(pid)
        (d / "fd").mkdir(parents=True, exist_ok=True)
        (d / "fdinfo").mkdir(exist_ok=True)
        (d / "stat").write_text(f"{pid} ({comm}) S 1 1 1 0 -1 4194304 0 0 0 0 10 10 0 0 20 0 1 0 1 1 1\n")
        (d / "statm").write_text("10 5 0 0 0 0 0\n")
        (d / "cmdline").write_bytes(f"/usr/bin/{comm}\0".encode())
        if not (d / "exe").is_symlink():
            (d / "exe").symlink_to(f"/usr/bin/{comm}")
        if drm:
            (d / "fd/7").unlink(missing_ok=True)
            (d / "fd/7").symlink_to(fdlink)
            (d / "fd/3").unlink(missing_ok=True)
            (d / "fd/3").symlink_to("/dev/null")
            lines = ["pos:\t0", "drm-driver:\tamdgpu", "drm-pdev:\t0000:03:00.0", f"drm-client-id:\t{client}"]
            if eng is not None:
                lines += [f"drm-engine-gfx:\t{eng} ns", "drm-engine-capacity-gfx:\t1", "drm-engine-compute:\t0 ns"]
            if vram_kib is not None:
                lines.append(f"drm-memory-vram:\t{vram_kib} KiB")
            (d / "fdinfo/7").write_text("\n".join(lines) + "\n")
            (d / "fdinfo/3").write_text("pos:\t0\n")
        if rd is not None:
            (d / "io").write_text(f"rchar: 1\nwchar: 2\nread_bytes: {rd}\nwrite_bytes: {wr}\n")

    mkproc(100, "game", client=11, vram_kib=1024, eng=0, rd=1000, wr=0)
    mkproc(101, "game", client=11, vram_kib=1024, eng=0, rd=1000, wr=0)       # same client as 100: counted once
    mkproc(102, "noisy", rd=0, wr=0, drm=False)
    mkproc(103, "nodrm", drm=False)
    mkproc(104, "wrongfd", client=12, vram_kib=64, eng=5, fdlink="/dev/null", rd=1, wr=1)
    m = load("procs_fake", S / "procs.py", {"PROCS_ROOT": str(fp)})
    clock = {"t": 100.0}
    m.time.monotonic = lambda: clock["t"]
    state = {"total": 0, "idle": 0, "ticks": {}, "extras": {}, "t": 0}
    r1, state = m.sample(state, None)
    g1 = {g["name"]: g for g in r1["groups"]}
    check("procs: first sample has no rates yet (gpu / read / write null), vram already known", g1["game"]["gpu"] is None and g1["game"]["read"] is None and g1["game"]["vram"] == 1048576)
    check("procs: a client shared by two processes counts once in VRAM", g1["game"]["vram"] == 1048576 and g1["game"]["count"] == 2)
    check("procs: a process without a GPU client has vram null", g1["noisy"]["vram"] is None and g1["nodrm"]["vram"] is None)
    check("procs: a fd that is not /dev/dri is ignored", g1["wrongfd"]["vram"] is None)
    clock["t"] = 102.0
    mkproc(100, "game", client=11, vram_kib=2048, eng=1_000_000_000, rd=3000, wr=2000)
    mkproc(101, "game", client=11, vram_kib=2048, eng=1_000_000_000, rd=1000, wr=0)
    mkproc(102, "noisy", rd=0, wr=20480, drm=False)
    r2, state = m.sample(state, None)
    g2 = {g["name"]: g for g in r2["groups"]}
    check("procs: gpu is the busiest engine's percent over the interval (1e9 ns in 2 s = 50)", g2["game"]["gpu"] == 50.0)
    check("procs: vram follows the latest fdinfo (2 MiB)", g2["game"]["vram"] == 2 * 1048576)
    check("procs: read / write are bytes per second over the interval", g2["game"]["read"] == 1000 and g2["game"]["write"] == 1000)
    check("procs: a plain process has gpu null but disk rates", g2["noisy"]["gpu"] is None and g2["noisy"]["read"] == 0 and g2["noisy"]["write"] == 10240)
    check("procs: an unreadable io file is null, never an error", g2["nodrm"]["read"] is None and g2["nodrm"]["write"] is None)
    check("procs: every group carries the four fields and the output is JSON", all(k in g for g in r2["groups"] for k in ("gpu", "vram", "read", "write")) and bool(json.dumps(r2)))
    clock["t"] = 104.0
    mkproc(100, "game", client=11, vram_kib=2048, eng=1_000_000_000, rd=100, wr=0)   # io counters went down
    r3, state = m.sample(state, None)
    g3 = {g["name"]: g for g in r3["groups"]}
    check("procs: counters that went down count as 0, not negative", g3["game"]["read"] == 0 and g3["game"]["gpu"] == 0.0)
    check("procs: a vanished pid gives all-null extras", m.pid_extras(99999, set()) == {"vram": None, "eng": None, "rd": None, "wr": None})
    d = m.fdinfo_drm("drm-client-id:\t4\ndrm-pdev:\tx\ndrm-memory-vram:\t3 MiB\ndrm-engine-enc:\t77 ns\ndrm-engine-capacity-enc:\t2\njunk\ndrm-memory-gtt:\tbad\n")
    check("procs: fdinfo parser reads MiB and engines, skips capacity and junk", d == (("x", "4"), 3 * 1048576, {"enc": 77}))
    check("procs: fdinfo with no drm usage keys is None", m.fdinfo_drm("pos:\t0\nflags:\t02\n") is None)


procs_tests()

for tool in ("timeout",):
    (fake / tool).symlink_to(Path("/usr/bin") / tool)


# ---------------------------------------------------------------- item 16: solaar.sh
SOLAAR_OLD = """Solaar version 1.1.9

USB and Bluetooth Receiver
  Device path  : /dev/hidraw4
  1: Wireless Keyboard K270
     Kind          : keyboard
     Battery: 40%, discharging.
  2: MX Master 3 Wireless Mouse
     Codename     : MX Master 3
     Kind          : mouse
     Battery: 80%, discharging.
"""
SOLAAR_NEW = """Unifying Receiver
  Device path  : /dev/hidraw2
  1: G502 LIGHTSPEED Wireless Gaming Mouse
     Kind          : mouse
     Polling rate  : 1 ms (1000Hz)
     Battery: 55% (recharging), 4012mV
"""
SOLAAR_FULL = "Receiver\n  1: MX Anywhere 2S\n     Kind: mouse\n     Battery: full\n"
SOLAAR_OFFLINE = "Receiver\n  1: MX Master 3\n     Kind: mouse\n     Battery: unknown (device is offline).\n"
SOLAAR_KBD = "Receiver\n  1: K270\n     Kind: keyboard\n     Battery: 90%, discharging.\n"


def solaar(text):
    fakecmd("solaar", f"cat <<'EOF'\n{text}EOF\n")
    r = sh("solaar.sh")
    try:
        return r.returncode, json.loads(r.stdout)
    except ValueError:
        return r.returncode, None


(fake / "solaar").unlink(missing_ok=True)
rc, o = sh("solaar.sh").returncode, json.loads(sh("solaar.sh").stdout)
check("solaar.sh: no solaar installed is present false, exit 0", rc == 0 and o["present"] is False)
rc, o = solaar(SOLAAR_OLD)
check("solaar.sh: old format, the mouse wins over the keyboard", rc == 0 and o == {"present": True, "name": "MX Master 3 Wireless Mouse", "percent": 80, "charging": False})
rc, o = solaar(SOLAAR_NEW)
check("solaar.sh: new format with 'recharging' is charging", o == {"present": True, "name": "G502 LIGHTSPEED Wireless Gaming Mouse", "percent": 55, "charging": True})
rc, o = solaar(SOLAAR_FULL)
check("solaar.sh: 'Battery: full' is 100 percent", o["present"] is True and o["percent"] == 100)
rc, o = solaar(SOLAAR_OFFLINE)
check("solaar.sh: an offline device (no percent) is not present", o["present"] is False and o["percent"] is None)
rc, o = solaar(SOLAAR_KBD)
check("solaar.sh: only a keyboard is not present", o["present"] is False)
rc, o = solaar("garbage\n\x00\xff not solaar at all")
check("solaar.sh: garbage is not present and exits 0", rc == 0 and o is not None and o["present"] is False)
fakecmd("solaar", "echo oops >&2; exit 3")
r = sh("solaar.sh")
check("solaar.sh: a failing solaar is not present, exit 0", r.returncode == 0 and json.loads(r.stdout)["present"] is False)

# ---------------------------------------------------------------- item 17: games.py Flatpak entries
def games(*extra, path=None):
    e = {"PATH": path if path is not None else str(fake), "HOME": str(home), "LC_ALL": "C"}
    r = subprocess.run([sys.executable, "-I", str(S / "games.py"), "--steam-root", str(tmp / "no-steam"), *extra], env=e, capture_output=True, text=True, timeout=30)
    return r.returncode, json.loads(r.stdout)


fakecmd("flatpak", f'echo "flatpak $*" >> "{log}"\nprintf "org.mozilla.firefox\\tFirefox\\ncom.vinegarhq.Sober\\tSober\\n"')
reset()
rc, g = games("--flatpak", "com.vinegarhq.Sober,org.not.Installed,bad id;rm,../x")
check("games.py: only the installed, valid Flatpak ids become entries", rc == 0 and len(g) == 1 and g[0]["id"] == "flatpak:com.vinegarhq.Sober" and g[0]["title"] == "Sober")
check("games.py: Flatpak entry has kind flatpak, source flatpak and `flatpak run <id>`", g[0]["kind"] == "flatpak" and g[0]["source"] == "flatpak" and g[0]["launch"] == ["flatpak", "run", "com.vinegarhq.Sober"])
check("games.py: the scan is `flatpak list --app --columns=application,name`", calls() == ["flatpak list --app --columns=application,name"])
reset()
rc, g = games()
check("games.py: no --flatpak ids runs no flatpak at all", g == [] and calls() == [])
fakecmd("flatpak", "exit 1")
rc, g = games("--flatpak", "com.vinegarhq.Sober")
check("games.py: a failing flatpak is no entries, no error", rc == 0 and g == [])
(fake / "flatpak").unlink()
rc, g = games("--flatpak", "com.vinegarhq.Sober")
check("games.py: flatpak missing is no entries, no error", rc == 0 and g == [])

# ---------------------------------------------------------------- item 19: secaudit.sh
r = sh("secaudit.sh")
check("secaudit.sh: arch-audit missing is ##not-installed, exit 0", r.returncode == 0 and r.stdout.strip() == "##not-installed")
fakecmd("arch-audit", f'echo "arch-audit $*" >> "{log}"\n'
        'if [ "$1" = "--upgradable" ]; then echo "Package gnutls is affected by CVE-1-1. High risk! Update to 3.8-1!"; exit 1; fi\n'
        'echo "Package gnutls is affected by CVE-1-1. High risk!"; exit 1')
reset()
r = sh("secaudit.sh")
check("secaudit.sh: prints the plain and the upgradable section even though arch-audit exits 1", r.returncode == 0
      and r.stdout.splitlines() == ["##plain", "Package gnutls is affected by CVE-1-1. High risk!", "##upgradable", "Package gnutls is affected by CVE-1-1. High risk! Update to 3.8-1!"])
check("secaudit.sh: runs arch-audit and arch-audit --upgradable only", [c.strip() for c in calls()] == ["arch-audit", "arch-audit --upgradable"])
fakecmd("arch-audit", "echo 'could not reach security.archlinux.org' >&2; exit 2")
r = sh("secaudit.sh")
check("secaudit.sh: a failing arch-audit is ##error with its first line, exit 0", r.returncode == 0 and r.stdout.strip() == "##error could not reach security.archlinux.org")
fakecmd("arch-audit", "exit 0")
r = sh("secaudit.sh")
check("secaudit.sh: nothing affected is two empty sections", r.returncode == 0 and r.stdout.startswith("##plain") and "##upgradable" in r.stdout)

# ---------------------------------------------------------------- item 13: loginreport.py
def loginreport(text=None, name="qs-login-times"):
    f = run / name
    f.unlink(missing_ok=True)
    if text is not None:
        f.write_text(text)
    r = subprocess.run([sys.executable, "-I", str(S / "loginreport.py")], env={"XDG_RUNTIME_DIR": str(run), "PATH": str(fake)}, capture_output=True, text=True, timeout=30)
    return r.returncode, json.loads(r.stdout)


rc, out = loginreport("1000 session-start\n1500 hyprpaper\n4500 waybar up\nbad line\nxyz nope\n5000\n4600 quickshell\n")
check("loginreport: slowest step first, names with spaces kept", rc == 0 and [r["name"] for r in out] == ["waybar up", "hyprpaper", "quickshell", "session-start"])
check("loginreport: ms is from the first line, since_previous_ms from the line before in time order",
      out[0] == {"name": "waybar up", "ms": 3500, "since_previous_ms": 3000} and out[-1] == {"name": "session-start", "ms": 0, "since_previous_ms": 0}
      and [r for r in out if r["name"] == "quickshell"][0] == {"name": "quickshell", "ms": 3600, "since_previous_ms": 100})
rc, out = loginreport(None)
check("loginreport: a missing file is [] and exit 0", rc == 0 and out == [])
rc, out = loginreport("")
check("loginreport: an empty file is []", rc == 0 and out == [])
rc, out = loginreport("2000 b\n1000 a\n")
check("loginreport: lines out of order are sorted by time", [r["name"] for r in out] == ["b", "a"] and out[0]["ms"] == 1000)

# ---------------------------------------------------------------- item 11: defaultapps.sh
apps_sys = tmp / "apps-sys"
apps_usr = tmp / "apps-usr"
apps_sys.mkdir()
apps_usr.mkdir()


def desktop(d, fn, name, mimes, extra=""):
    (d / fn).write_text(f"[Desktop Entry]\nType=Application\nName={name}\nName[sv]=Svenska\nMimeType={mimes}\n{extra}\n[Desktop Action x]\nName=Not me\n")


desktop(apps_sys, "firefox.desktop", "Firefox", "text/html;x-scheme-handler/http;x-scheme-handler/https;")
desktop(apps_sys, "zen.desktop", "Zen Browser", "x-scheme-handler/http;")
desktop(apps_sys, "imv.desktop", "imv", "image/png;image/jpeg;")
desktop(apps_sys, "vlc.desktop", "VLC", "video/mp4;video/webm;")
desktop(apps_sys, "mpv.desktop", "mpv", "video/mp4;", "NoDisplay=true")
desktop(apps_sys, "nemo.desktop", "Nemo", "inode/directory;")
desktop(apps_sys, "kate.desktop", "Kate", "text/plain;")
desktop(apps_usr, "kate.desktop", "Kate (mine)", "text/plain;")
desktop(apps_sys, "bad name.desktop", "Spaced", "text/plain;")
fakecmd("xdg-settings", f'echo "xdg-settings $*" >> "{log}"\ncase "$1" in get) echo firefox.desktop;; esac')
fakecmd("xdg-mime", f'echo "xdg-mime $*" >> "{log}"\ncase "$1" in query) case "$3" in image/png) echo imv.desktop;; video/mp4) echo "not an id";; inode/directory) echo nemo.desktop;; esac;; esac')
DENV = {"DEFAULTAPPS_DIRS": f"{apps_sys}:{apps_usr}"}
reset()
r = sh("defaultapps.sh", "list", env=DENV)
lst = json.loads(r.stdout) if r.returncode == 0 else []
byk = {c["key"]: c for c in lst}
check("defaultapps: list has the five kinds", [c["key"] for c in lst] == ["browser", "image", "video", "files", "editor"])
check("defaultapps: current defaults come from xdg-settings / xdg-mime, a non-id answer is empty", byk["browser"]["current"] == "firefox.desktop" and byk["image"]["current"] == "imv.desktop" and byk["video"]["current"] == "" and byk["files"]["current"] == "nemo.desktop")
check("defaultapps: browser candidates by http handler, sorted by name", [c["id"] for c in byk["browser"]["candidates"]] == ["firefox.desktop", "zen.desktop"])
check("defaultapps: NoDisplay apps and ids with spaces are skipped, localized Name= and actions ignored", [c["id"] for c in byk["video"]["candidates"]] == ["vlc.desktop"] and byk["browser"]["candidates"][0]["name"] == "Firefox" and all("bad" not in c["id"] for c in byk["editor"]["candidates"]))
check("defaultapps: the user's folder wins on equal ids", byk["editor"]["candidates"] == [{"id": "kate.desktop", "name": "Kate (mine)"}])
check("defaultapps: list only reads (xdg-settings get, xdg-mime query)", all(c.startswith(("xdg-settings get", "xdg-mime query")) for c in calls()))
reset()
r = sh("defaultapps.sh", "set", "browser", "zen.desktop", env=DENV)
check("defaultapps: set browser runs xdg-settings set default-web-browser", r.returncode == 0 and r.stdout.strip() == "ok" and calls() == ["xdg-settings set default-web-browser zen.desktop"])
reset()
r = sh("defaultapps.sh", "set", "image", "imv.desktop", env=DENV)
check("defaultapps: set image runs xdg-mime default for png, jpeg, gif, webp", r.returncode == 0 and calls() == [f"xdg-mime default imv.desktop {m}" for m in ("image/png", "image/jpeg", "image/gif", "image/webp")])
for bad_key, bad_id in (("browser", "zen"), ("browser", "../zen.desktop"), ("browser", "zen.desktop;rm"), ("browser", "a b.desktop"), ("browser", ""), ("nokind", "zen.desktop"), ("browser", "ghost.desktop"), ("browser", "-x.desktop")):
    reset()
    r = sh("defaultapps.sh", "set", bad_key, bad_id, env=DENV)
    check(f"defaultapps: set {bad_key!r} {bad_id!r} is refused and runs nothing", r.returncode == 1 and r.stderr.strip() != "" and calls() == [])
fakecmd("xdg-mime", "echo 'xdg-mime: no such file' >&2; exit 4")
r = sh("defaultapps.sh", "set", "files", "nemo.desktop", env=DENV)
check("defaultapps: a failing xdg-mime gives exit 1 and its first line", r.returncode == 1 and r.stderr.strip() == "xdg-mime: no such file")
(fake / "xdg-settings").unlink()
(fake / "xdg-mime").unlink()
r = sh("defaultapps.sh", "list", env=DENV)
check("defaultapps: without xdg tools list still works, currents empty", r.returncode == 0 and all(c["current"] == "" for c in json.loads(r.stdout)))

# ---------------------------------------------------------------- item 12: fixes.sh
(fake / "sleep").unlink()
fakecmd("sleep", "exit 0")
LIST_ALL = "[{+}     ] pipewire (pid: 11)\n[{+}     ] wireplumber (pid: 12)\n[{+}     ] pipewire-pulse (pid: 13)\n[{+}     ] xdg-desktop-portal (pid: 14)\n[{+}     ] hyprpaper (pid: 15)\n[     {-}] easyeffects\n"


def fixes(fid, dinit_list, installed=(), restart_fails=False):
    for n in ("pipewire", "wireplumber", "xdg-desktop-portal", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "hyprpaper", "easyeffects"):
        (fake / n).unlink(missing_ok=True)
    for n in installed:
        fakecmd(n, f'echo "run {n} $*" >> "{log}"')
    fakecmd("dinitctl", f'echo "dinitctl $*" >> "{log}"\ncase "$2" in list) cat <<\'EOF\'\n{dinit_list}EOF\n;; restart) exit {1 if restart_fails else 0};; esac')
    logger("pkill")
    logger("setsid")
    reset()
    r = sh("fixes.sh", fid, env={"FIXES_LIBDIR": str(tmp / "nolib")})
    return r, [c.strip() for c in calls()]


r, c = fixes("pipewire", LIST_ALL)
check("fixes: pipewire with user services restarts pipewire, wireplumber, pipewire-pulse through dinitctl, no pkill",
      r.returncode == 0 and c == ["dinitctl --user list", "dinitctl --user restart pipewire", "dinitctl --user restart wireplumber", "dinitctl --user restart pipewire-pulse"] and r.stdout.startswith("Restarted"))
r, c = fixes("pipewire", "", installed=("pipewire", "wireplumber"))
check("fixes: pipewire without services: pkill -x then setsid -f relaunch, for both programs",
      r.returncode == 0 and c == ["dinitctl --user list", "pkill -x pipewire", "setsid -f pipewire", "pkill -x wireplumber", "setsid -f wireplumber"])
r, c = fixes("portals", LIST_ALL)
check("fixes: portals restarts only the listed xdg-desktop-portal service", r.returncode == 0 and c == ["dinitctl --user list", "dinitctl --user restart xdg-desktop-portal"])
r, c = fixes("portals", "", installed=("xdg-desktop-portal", "xdg-desktop-portal-hyprland"))
check("fixes: portals fallback kills and relaunches the installed portals only (hyprland first)", r.returncode == 0 and c == [
    "dinitctl --user list", "pkill -x xdg-desktop-portal-hyprland", "setsid -f xdg-desktop-portal-hyprland", "pkill -x xdg-desktop-portal", "setsid -f xdg-desktop-portal"])
r, c = fixes("hyprpaper", LIST_ALL)
check("fixes: hyprpaper service restart", r.returncode == 0 and c == ["dinitctl --user list", "dinitctl --user restart hyprpaper"])
r, c = fixes("hyprpaper", "", installed=("hyprpaper",))
check("fixes: hyprpaper fallback pkill + relaunch", r.returncode == 0 and c == ["dinitctl --user list", "pkill -x hyprpaper", "setsid -f hyprpaper"])
r, c = fixes("easyeffects", "[{+}     ] pipewire (pid: 1)\n", installed=("easyeffects",))
check("fixes: easyeffects relaunches with --gapplication-service", r.returncode == 0 and c == ["dinitctl --user list", "pkill -x easyeffects", "setsid -f easyeffects --gapplication-service"])
r, c = fixes("easyeffects", LIST_ALL)
check("fixes: a stopped easyeffects service is still restarted through dinitctl", r.returncode == 0 and "dinitctl --user restart easyeffects" in c)
for bad in ("quickshell", "", "pipewire; rm -rf x", "../pipewire", "PIPEWIRE", "all"):
    r, c = fixes(bad, LIST_ALL, installed=("pipewire",))
    check(f"fixes: id {bad!r} is refused, nothing is restarted", r.returncode == 1 and r.stderr.strip() != "" and not any(x.startswith(("dinitctl --user restart", "pkill", "setsid", "run ")) for x in c))
r, c = fixes("hyprpaper", "", installed=())
check("fixes: nothing installed and no service is an error, not a silent ok", r.returncode == 1 and "not installed" in r.stderr)
r, c = fixes("hyprpaper", LIST_ALL, restart_fails=True)
check("fixes: a failing dinitctl restart is exit 1 with the reason", r.returncode == 1 and "could not restart hyprpaper" in r.stderr)

# (further sections are added below, one per item)

print(f"TEST done failures={failures}")
tmp_ctx.cleanup()
sys.exit(1 if failures else 0)

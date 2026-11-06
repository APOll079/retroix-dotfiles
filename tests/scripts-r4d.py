#!/usr/bin/env python3
"""Tests quickshell/scripts/appearance.sh (cursor and icon themes) and quickshell/theme/apply.py's "custom" palette.
  python3 tests/scripts-r4d.py     (prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
gsettings and hyprctl are fakes on an isolated PATH that log their arguments; the real ones never run. HOME and
XDG_CONFIG_HOME are scratch folders made here, so nothing outside them is touched."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
S = ROOT / "quickshell/scripts/appearance.sh"
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
    sysicons = tmp / "sysicons"
    log = tmp / "log"

    def link(tool):
        for d in ("/usr/bin", "/bin"):
            if (Path(d) / tool).exists():
                (fake / tool).symlink_to(Path(d) / tool)
                return

    for tool in ("sh", "env", "cat", "grep", "sort", "head", "tr", "python3"):
        link(tool)

    def fakecmd(name, body):
        p = fake / name
        if p.exists() or p.is_symlink():
            p.unlink()
        p.write_text("#!/bin/sh\n" + body)
        p.chmod(0o755)

    def mk(base, name, cursors=False, index=None):
        d = base / name
        d.mkdir(parents=True)
        if cursors:
            (d / "cursors").mkdir()
        if index is not None:
            (d / "index.theme").write_text(index)

    ICON = "[Icon Theme]\nName=x\nDirectories=16x16/apps\n"
    mk(home / ".local/share/icons", "posy-black", cursors=True, index="[Icon Theme]\nName=posy\n")
    mk(home / ".icons", "Bibata", cursors=True)
    mk(sysicons, "Adwaita", cursors=True, index="[Icon Theme]\nDirectories=\n")  # has cursors/: a cursor theme only
    mk(sysicons, "Papirus", index=ICON)
    mk(sysicons, "hicolor", index=ICON)
    mk(sysicons, "NoDirs", index="[Icon Theme]\nName=nothing\n")  # index.theme without Directories=
    mk(sysicons, "NoIndex")
    mk(sysicons, "bad name", cursors=True)  # hostile folder names are skipped
    mk(sysicons, "x;touch", cursors=True)
    mk(sysicons, "$(id)", index=ICON)
    mk(sysicons, "-rf", index=ICON)
    mk(sysicons, ".hidden", index=ICON)

    def run(*args, env=None, tools=True):
        e = {"PATH": str(fake), "HOME": str(home), "APPEARANCE_SYSTEM_ICONS": str(sysicons)}
        if env:
            e.update(env)
        r = subprocess.run([str(S), *args], env=e, capture_output=True, text=True, timeout=20)
        return r

    # ---- listing ----
    r = run("list-cursors")
    check("list-cursors: JSON of cursor themes from all three folders", r.returncode == 0 and json.loads(r.stdout) == ["Adwaita", "Bibata", "posy-black"])
    r = run("list-icons")
    check("list-icons: only index.theme with Directories= and no cursors/", json.loads(r.stdout) == ["Papirus", "hicolor"])
    check("list: hostile folder names never appear", all(bad not in run("list-cursors").stdout + run("list-icons").stdout
                                                         for bad in ("bad name", "touch", "$(id)", "-rf", ".hidden")))
    check("list: nothing was executed by a hostile folder name", not Path("touch").exists())
    r = run("list-cursors", env={"HOME": str(tmp / "nohome"), "APPEARANCE_SYSTEM_ICONS": str(tmp / "nowhere")})
    check("list: missing folders give an empty array", r.returncode == 0 and r.stdout.strip() == "[]")

    # ---- get ----
    fakecmd("gsettings", f'echo "$@" >> {log}\ncase "$2 $3" in\n*cursor-theme) echo "\'posy-black\'";;\n*cursor-size) echo "32";;\n*icon-theme) echo "\'Papirus\'";;\nesac\n')
    r = run("get-cursor")
    check("get-cursor: theme and size", json.loads(r.stdout) == {"theme": "posy-black", "size": 32})
    r = run("get-icons")
    check("get-icons: theme", json.loads(r.stdout) == {"theme": "Papirus"})
    fakecmd("gsettings", 'echo "\'bad name; rm -rf\'"\n')
    check("get-icons: a hostile value from gsettings is blanked", json.loads(run("get-icons").stdout) == {"theme": ""})
    (fake / "gsettings").unlink()
    check("get-cursor: without gsettings it is empty, not an error", run("get-cursor").returncode == 0 and json.loads(run("get-cursor").stdout) == {"theme": "", "size": 0})

    # ---- set ----
    fakecmd("gsettings", f'echo "gsettings $@" >> {log}\n')
    fakecmd("hyprctl", f'echo "hyprctl $@" >> {log}\n')
    log.write_text("")
    r = run("set-cursor", "Bibata", "48")
    lines = log.read_text().splitlines()
    check("set-cursor: gsettings theme + size, then hyprctl setcursor", r.returncode == 0 and lines == [
        "gsettings set org.gnome.desktop.interface cursor-theme 'Bibata'",
        "gsettings set org.gnome.desktop.interface cursor-size 48",
        "hyprctl setcursor Bibata 48"])
    log.write_text("")
    r = run("set-icons", "Papirus")
    check("set-icons: gsettings icon-theme", r.returncode == 0 and log.read_text().splitlines() == ["gsettings set org.gnome.desktop.interface icon-theme 'Papirus'"])
    (fake / "hyprctl").unlink()
    log.write_text("")
    r = run("set-cursor", "Bibata", "24")
    check("set-cursor: a missing hyprctl is skipped, not an error", r.returncode == 0 and "hyprctl" not in log.read_text())
    (fake / "gsettings").unlink()
    r = run("set-cursor", "Bibata", "24")
    check("set-cursor: no tool at all is still exit 0", r.returncode == 0 and "none" in r.stdout)

    # ---- hostile arguments ----
    fakecmd("gsettings", f'echo "gsettings $@" >> {log}\n')
    fakecmd("hyprctl", f'echo "hyprctl $@" >> {log}\n')
    log.write_text("")
    bad = ["x'; touch pwn; '", "a b", "$(touch pwn)", "`touch pwn`", "-rf", "--help", "..", ".x", "a/b", "", "x\ny"]
    codes = [run("set-cursor", n, "24").returncode for n in bad] + [run("set-icons", n).returncode for n in bad]
    check("hostile names are refused with exit 2", all(c == 2 for c in codes))
    check("hostile names never reach gsettings or hyprctl", log.read_text() == "")
    sizes = ["", "abc", "24; touch pwn", "-1", "7", "257", "2 4", "0x20"]
    check("bad sizes are refused with exit 2", all(run("set-cursor", "Bibata", s).returncode == 2 for s in sizes))
    check("bad sizes never reach a tool", log.read_text() == "")
    check("nothing was created by an injection", not (Path("pwn").exists() or (tmp / "pwn").exists() or (home / "pwn").exists()))
    check("an unknown command is a usage error", run("frobnicate").returncode == 2 and run().returncode == 2)

# ---- apply.py: the "custom" palette (theme editor) from a file, against a scratch HOME only ----
APPLY = ROOT / "quickshell/theme/apply.py"
with tempfile.TemporaryDirectory() as t:
    tmp = Path(t)
    home = tmp / "home"
    cfg = home / ".config"
    home.mkdir()
    pal = {"base": "#f4c9ef", "shadow": "#c7a4cc", "highlight": "#fefafd", "urgent": "#a86147", "accent": "#2a6f97",
           "text": "#321d32", "outline": "#20091d", "outlineGradientFade": "#3e233e", "defaultWallpaperPath": ""}
    pfile = tmp / "custom-theme.json"

    def apply(*args):
        env = {"PATH": "/usr/bin:/bin", "HOME": str(home), "XDG_CONFIG_HOME": str(cfg), "XDG_STATE_HOME": str(tmp / "state"), "PYTHONDONTWRITEBYTECODE": "1"}
        return subprocess.run(["python3", "-I", str(APPLY), *args], env=env, capture_output=True, text=True, timeout=60)

    pfile.write_text(json.dumps(pal))
    r = apply("custom", "--palette", str(pfile), "--no-reload")
    kitty = cfg / "kitty/theme-colors.conf"
    check("apply.py custom --palette: renders the app files from the file's colours", r.returncode == 0 and kitty.exists() and "2a6f97" in kitty.read_text().lower() and "theme custom" in r.stdout)
    check("apply.py custom: everything was written under the scratch config only", all(str(cfg) in line or str(home) in line for line in r.stdout.splitlines() if "wrote" in line))
    r = apply("custom", "--palette", str(pfile), "--no-reload")
    check("apply.py custom: a second run changes nothing", r.returncode == 0 and "wrote" not in r.stdout)
    before = kitty.read_text()
    pfile.write_text(json.dumps(dict(pal, text="#c0b0c0")))
    r = apply("custom", "--palette", str(pfile), "--no-reload")
    check("apply.py custom: a palette that fails the contrast rules is refused, nothing written", r.returncode != 0 and "refused" in r.stderr and kitty.read_text() == before)
    pfile.write_text(json.dumps({k: v for k, v in pal.items() if k != "accent"}))
    r = apply("custom", "--palette", str(pfile), "--no-reload")
    check("apply.py custom: a palette missing a colour is refused", r.returncode != 0 and "accent" in r.stderr)
    r = apply("custom", "--no-reload")
    check("apply.py custom without --palette says where the palette comes from", r.returncode != 0 and "custom-theme.json" in r.stderr and "--palette" in r.stderr)
    r = apply("wallpaper", "--no-reload")
    check("apply.py wallpaper without --palette says the same for its file", r.returncode != 0 and "wallpaper-theme.json" in r.stderr)
    r = apply("nosuchtheme", "--no-reload")
    check("apply.py: an unknown theme still lists the known ones", r.returncode != 0 and "known:" in r.stderr)
    r = apply("cherry", "--no-reload")
    check("apply.py: a shipped theme still renders as before", r.returncode == 0 and "theme cherry" in r.stdout)

print("TEST done failures=%d" % failures)
sys.exit(1 if failures else 0)

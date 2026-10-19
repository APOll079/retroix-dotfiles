#!/usr/bin/env python3
"""List installed games as one JSON array for the Games menu (popups/GamesMenu.qml).

    python3 -I games.py [--steam-root DIR] [--custom FILE] [--cache FILE]

Sources:
  steam     installed games from every Steam library folder's appmanifest files
  shortcut  non-Steam games added through Steam (userdata/*/config/shortcuts.vdf)
  custom    the user's own entries from the "custom" list in --custom (games.json in
            Quickshell's state dir, written by the menu's Add game form)

Each item: {id, title, source, launch: [argv], cwd, dir, art, lastPlayed}.
Steam and shortcut games launch through `steam steam://rungameid/<id>`, so Steam (and Proton
for shortcuts) does the work. Missing files are skipped quietly; this never raises on bad data,
it just lists less. Each extra library folder is scanned in a child process that gets LIB_TIMEOUT seconds
(NAS off, stale NFS mount); if it fails or hangs, its games come from --cache (the last good scan of it).
 Steam's file formats are not documented by Valve: if art or a source stops
showing up after a Steam update, this file is the place to look (see MAINTENANCE.md).
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys

HOME = os.path.expanduser("~")
STEAM_ROOTS = [
    os.path.join(HOME, ".local/share/Steam"),
    os.path.join(HOME, ".steam/steam"),
    os.path.join(HOME, ".var/app/com.valvesoftware.Steam/.local/share/Steam"),
]
# Steam's own tools show up as installed "apps"; they are not games
TOOL_NAME = re.compile(r"^(Proton\b|Steam Linux Runtime|Steamworks Common)", re.I)
ART_NAMES = ["library_600x900.jpg", "library_capsule.jpg", "header.jpg", "library_header.jpg"]
ART_EXTS = [".png", ".jpg", ".jpeg", ".webp"]
LIB_TIMEOUT = 5           # seconds a library folder gets to answer


# --- Steam text VDF (appmanifest_*.acf, libraryfolders.vdf) ---

def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def parse_vdf(text):
    """Nested dict from Valve's text KeyValues format."""
    tokens = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    pos = 0

    def block():
        nonlocal pos
        out = {}
        while pos < len(tokens):
            s, brace = tokens[pos]
            pos += 1
            if brace == "}":
                return out
            key = unescape(s)
            if pos >= len(tokens):
                break
            s2, brace2 = tokens[pos]
            pos += 1
            if brace2 == "{":
                out[key] = block()
            else:
                out[key] = unescape(s2)
        return out

    return block()


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


# --- Steam binary VDF (shortcuts.vdf) ---

def parse_binary_vdf(data):
    """Nested dict from the binary KeyValues format: 0 map, 1 string, 2 int32, 8 end."""
    pos = 0

    def cstr():
        nonlocal pos
        end = data.index(b"\x00", pos)
        s = data[pos:end].decode("utf-8", errors="replace")
        pos = end + 1
        return s

    def block():
        nonlocal pos
        out = {}
        while pos < len(data):
            t = data[pos]
            pos += 1
            if t == 8:
                return out
            key = cstr()
            if t == 0:
                out[key] = block()
            elif t == 1:
                out[key] = cstr()
            elif t == 2:
                out[key] = struct.unpack_from("<I", data, pos)[0]
                pos += 4
            else:
                raise ValueError("unknown type %d" % t)
        return out

    return block()


def find_art_in(folder):
    """First cover found in a Steam librarycache/<appid> folder, directly or one level down
    (Steam changed the layout over time)."""
    try:
        entries = list(os.scandir(folder))
    except OSError:
        return ""
    dirs = [folder] + [e.path for e in entries if e.is_dir()]
    for name in ART_NAMES:
        for d in dirs:
            p = os.path.join(d, name)
            if os.path.isfile(p):
                return p
    return ""


# --- sources ---

def steam_roots(override):
    if override:
        return [override]
    seen, out = set(), []
    for r in STEAM_ROOTS:
        real = os.path.realpath(r)
        if os.path.isdir(real) and real not in seen:
            seen.add(real)
            out.append(real)
    return out


def timed_child(args, timeout=LIB_TIMEOUT):
    """Stdout of this script run with args in a child process, or None when it fails or doesn't answer
    within timeout. A child hung on a dead NFS server (uninterruptible) is killed and abandoned, never
    waited for, so the scan goes on."""
    try:
        child = subprocess.Popen([sys.executable, "-I", os.path.abspath(__file__)] + args,
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        return None
    try:
        out, _ = child.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            child.kill()
        except OSError:
            pass
        return None
    return out.decode("utf-8", errors="replace") if child.returncode == 0 else None


def safe_isfile(path):
    """os.path.isfile, but a path outside HOME (maybe a network mount) is probed in a timed child."""
    if not path:
        return False
    path = os.path.abspath(path)
    if path.startswith(HOME + os.sep):
        return os.path.isfile(path)
    return timed_child(["--probe-file", path]) == "1"


def scan_library(lib, root):
    """Installed games of one library folder. Raises OSError when its steamapps can't be listed."""
    apps = os.path.join(lib, "steamapps")
    found = []
    for fn in sorted(os.listdir(apps)):
        if not (fn.startswith("appmanifest_") and fn.endswith(".acf")):
            continue
        st = parse_vdf(read_text(os.path.join(apps, fn))).get("AppState")
        if not isinstance(st, dict):
            continue
        try:
            appid = int(st["appid"])
            installed = int(st.get("StateFlags", "0")) & 4
            last = int(st.get("LastPlayed", "0") or 0)
        except (KeyError, ValueError, TypeError):
            continue
        title = st.get("name", "")
        if not installed or not isinstance(title, str) or not title or TOOL_NAME.search(title):
            continue
        found.append({
            "id": "steam:%d" % appid,
            "title": title,
            "source": "steam",
            "launch": ["steam", "steam://rungameid/%d" % appid],
            "cwd": "",
            "dir": os.path.join(apps, "common", str(st.get("installdir", ""))),
            "art": find_art_in(os.path.join(root, "appcache", "librarycache", str(appid))),
            "lastPlayed": last,
        })
    return found


def good_game(g):
    return (isinstance(g, dict) and isinstance(g.get("id"), str) and isinstance(g.get("title"), str)
            and isinstance(g.get("launch"), list) and isinstance(g.get("lastPlayed"), int))


def good_games(items):
    return [g for g in items if good_game(g)] if isinstance(items, list) else []


def steam_games(root, cache):
    libs = {root}
    lf = parse_vdf(read_text(os.path.join(root, "steamapps", "libraryfolders.vdf")))
    top = lf.get("libraryfolders")
    entries = top if isinstance(top, dict) else lf
    for entry in entries.values():
        if isinstance(entry, dict) and isinstance(entry.get("path"), str) and entry["path"]:
            libs.add(entry["path"])
    games = []
    for lib in sorted(libs):
        if lib == root:
            try:
                found = scan_library(lib, root)
            except OSError:
                continue
        else:
            # Other library folders may sit on a network drive: the whole scan of one runs in a timed
            # child; when it doesn't answer (or fails) the last good list of that folder is used
            out = timed_child(["--scan-library", lib, "--steam-root", root])
            try:
                found = good_games(json.loads(out)) if out is not None else None
            except ValueError:
                found = None
            if found is None:
                games += good_games(cache.get(lib, []))
                continue
        cache[lib] = found
        games += found
    return games


def grid_art(config_dir, appid):
    """Art set for a shortcut in Steam's UI: userdata/<uid>/config/grid/<appid>p.<ext>."""
    for stem in ("%dp" % appid, "%d" % appid):
        for ext in ART_EXTS:
            p = os.path.join(config_dir, "grid", stem + ext)
            if os.path.isfile(p):
                return p
    return ""


def shortcut_games(root):
    games = []
    userdata = os.path.join(root, "userdata")
    try:
        users = sorted(os.listdir(userdata))
    except OSError:
        return games
    for uid in users:
        cfg = os.path.join(userdata, uid, "config")
        try:
            with open(os.path.join(cfg, "shortcuts.vdf"), "rb") as f:
                data = parse_binary_vdf(f.read())
        except (OSError, ValueError, IndexError, struct.error):
            continue
        for sc in (data.get("shortcuts") or {}).values():
            if not isinstance(sc, dict):
                continue
            # keys differ in case between Steam versions
            sc = {k.lower(): v for k, v in sc.items()}
            title, appid = sc.get("appname", ""), sc.get("appid")
            if not title or not isinstance(title, str) or not isinstance(appid, int):
                continue
            try:
                last = int(sc.get("lastplaytime") or 0)
            except (ValueError, TypeError):
                last = 0
            icon = sc.get("icon")
            gameid = (appid << 32) | 0x02000000
            games.append({
                "id": "shortcut:%d" % gameid,
                "title": title,
                "source": "shortcut",
                "launch": ["steam", "steam://rungameid/%d" % gameid],
                "cwd": "",
                "dir": str(sc.get("startdir") or "").strip('"'),
                "art": grid_art(cfg, appid) or (icon if isinstance(icon, str) and safe_isfile(icon) else ""),
                "lastPlayed": last,
            })
    return games


def custom_games(path):
    if not path:
        return []
    try:
        data = json.loads(read_text(path) or "{}")
        entries = data.get("custom") or []
    except (ValueError, AttributeError):
        return []
    if not isinstance(entries, list):
        return []
    games = []
    for e in entries:
        if not isinstance(e, dict):
            continue
        name, command = e.get("name"), e.get("command")
        if not isinstance(name, str) or not name or not isinstance(command, str) or not command:
            continue
        try:
            last = int(e.get("lastPlayed") or 0)
        except (ValueError, TypeError):
            last = 0
        folder = e.get("dir") if isinstance(e.get("dir"), str) else ""
        cover = os.path.expanduser(e.get("cover") if isinstance(e.get("cover"), str) else "")
        games.append({
            "id": "custom:%s" % name,
            "title": name,
            "source": "custom",
            "launch": ["sh", "-c", command],
            "cwd": os.path.expanduser(folder),
            "dir": os.path.expanduser(folder),
            "art": cover if safe_isfile(cover) else "",
            "lastPlayed": last,
        })
    return games


def run(args):
    cache = {}
    if args.cache:
        try:
            cache = json.loads(read_text(args.cache) or "{}")
        except ValueError:
            cache = {}
        if not isinstance(cache, dict):
            cache = {}
    games, seen = [], set()
    for root in steam_roots(args.steam_root):
        try:
            found = steam_games(root, cache) + shortcut_games(root)
        except Exception as e:  # one broken root never hides the rest
            print("games.py: %s: %s" % (root, e), file=sys.stderr)
            continue
        for g in found:
            if g["id"] not in seen:
                seen.add(g["id"])
                games.append(g)
    try:
        games += [g for g in custom_games(args.custom) if g["id"] not in seen]
    except Exception as e:
        print("games.py: custom: %s" % e, file=sys.stderr)
    games.sort(key=lambda g: (-g["lastPlayed"], g["title"].lower()))
    return games, cache


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steam-root")
    ap.add_argument("--custom")
    ap.add_argument("--cache")
    ap.add_argument("--scan-library")   # internal: one library folder, run in a timed child
    ap.add_argument("--probe-file")     # internal: prints 1 when the path is a file, run in a timed child
    args, _ = ap.parse_known_args()
    if args.probe_file:
        print("1" if os.path.isfile(args.probe_file) else "0")
        return
    if args.scan_library:
        try:
            out = scan_library(args.scan_library, args.steam_root or args.scan_library)
        except Exception as e:  # nonzero exit tells the parent to use its cached list
            print("games.py: %s" % e, file=sys.stderr)
            sys.exit(1)
        print(json.dumps(out), flush=True)
        return
    try:
        games, cache = run(args)
    except Exception as e:  # always print a list
        print("games.py: %s" % e, file=sys.stderr)
        games, cache = [], None
    print(json.dumps(games), flush=True)
    if args.cache and cache is not None:
        try:
            tmp = args.cache + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(cache, f)
            os.replace(tmp, args.cache)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        print("games.py: %s" % e, file=sys.stderr)
        print("[]")

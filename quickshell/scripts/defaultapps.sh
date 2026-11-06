#!/bin/sh
# Default applications for DefaultApps.qml (Start > Default apps).
#   defaultapps.sh list                  JSON array, one object per kind:
#                                        [{"key","label","current":"<id>.desktop or empty","candidates":[{"id","name"}]}]
#   defaultapps.sh set <key> <id>        make <id> (a name like firefox.desktop) the default for <key>; prints "ok", exit 0
#                                        on failure prints the reason on stderr and exits 1
# Keys: browser (xdg-settings default-web-browser), image (image/png jpeg gif webp), video (video/mp4 x-matroska webm),
#       files (inode/directory), editor (text/plain).
# Candidates come from the .desktop files in /usr/share/applications and ~/.local/share/applications (read only: Name= and MimeType=;
# NoDisplay / Hidden entries skipped; the user's folder wins on equal ids). Test hook: DEFAULTAPPS_DIRS="dir:dir" replaces those two.
# The id must match ^[A-Za-z0-9._-]+\.desktop$ (and not start with a dot or dash) and be one of the files found; the key must be one of the five. Arguments only ever
# reach python as sys.argv and xdg-settings / xdg-mime as separate arguments, never inside script text.
exec python3 -I -c '
import json, os, re, subprocess, sys

CATS = [
    ("browser", "Web browser", ["x-scheme-handler/http", "text/html"], ["x-scheme-handler/http"]),
    ("image", "Image viewer", ["image/png"], ["image/png", "image/jpeg", "image/gif", "image/webp"]),
    ("video", "Video player", ["video/mp4"], ["video/mp4", "video/x-matroska", "video/webm"]),
    ("files", "File manager", ["inode/directory"], ["inode/directory"]),
    ("editor", "Text editor", ["text/plain"], ["text/plain"]),
]
ID = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*\.desktop$")


def dirs():
    env = os.environ.get("DEFAULTAPPS_DIRS")
    if env:
        return [d for d in env.split(":") if d]
    return ["/usr/share/applications", os.path.join(os.path.expanduser("~"), ".local/share/applications")]


def apps():
    """id -> (name, [mime types]) for the visible applications"""
    found = {}
    for d in dirs():
        try:
            names = sorted(os.listdir(d))
        except OSError:
            continue
        for fn in names:
            if not ID.match(fn):
                continue
            name, mimes, section, hidden, kind = "", [], None, False, "Application"
            try:
                with open(os.path.join(d, fn), encoding="utf-8", errors="replace") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("["):
                            section = line
                            continue
                        if section != "[Desktop Entry]" or "=" not in line:
                            continue
                        k, _, v = line.partition("=")
                        if k == "Name" and not name:
                            name = v.strip()
                        elif k == "MimeType":
                            mimes = [m for m in v.split(";") if m]
                        elif k in ("NoDisplay", "Hidden") and v.strip().lower() == "true":
                            hidden = True
                        elif k == "Type":
                            kind = v.strip()
            except OSError:
                continue
            if hidden or kind != "Application":
                found.pop(fn, None)
                continue
            found[fn] = (name or fn[:-8], mimes)
    return found


def run(args):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError) as e:
        return 127, "", str(e)
    return r.returncode, r.stdout, r.stderr


def current(key, probe):
    if key == "browser":
        rc, out, _ = run(["xdg-settings", "get", "default-web-browser"])
    else:
        rc, out, _ = run(["xdg-mime", "query", "default", probe[0]])
    out = out.strip().splitlines()[0].strip() if out.strip() else ""
    return out if rc == 0 and ID.match(out) else ""


def do_list():
    found = apps()
    out = []
    for key, label, probe, _ in CATS:
        cands = sorted(({"id": i, "name": n} for i, (n, m) in found.items() if any(p in m for p in probe)), key=lambda c: (c["name"].lower(), c["id"]))
        out.append({"key": key, "label": label, "current": current(key, probe), "candidates": cands})
    print(json.dumps(out))


def do_set(key, app):
    cat = [c for c in CATS if c[0] == key]
    if not cat:
        sys.stderr.write("unknown kind\n")
        return 1
    if not ID.match(app or ""):
        sys.stderr.write("not a valid application id\n")
        return 1
    if app not in apps():
        sys.stderr.write("that application is not installed\n")
        return 1
    if key == "browser":
        steps = [["xdg-settings", "set", "default-web-browser", app]]
    else:
        steps = [["xdg-mime", "default", app, m] for m in cat[0][3]]
    for s in steps:
        rc, _, err = run(s)
        if rc != 0:
            sys.stderr.write((err.strip().splitlines() or [s[0] + " failed"])[0] + "\n")
            return 1
    print("ok")
    return 0


argv = sys.argv[1:]
if argv[:1] == ["list"]:
    do_list()
elif len(argv) == 3 and argv[0] == "set":
    sys.exit(do_set(argv[1], argv[2]))
else:
    sys.stderr.write("usage: defaultapps.sh list | set <key> <id>.desktop\n")
    sys.exit(2)
' "$@"

#!/bin/sh
# Disk clean-up for CleanupState.qml.
#   cleanup.sh sizes              READ-ONLY. JSON [{id, label, bytes, count, needsRoot, note}] for
#                                 pacman-cache, orphans, flatpak-unused, trash. A missing tool
#                                 gives bytes null and note "not installed", never an error.
#   cleanup.sh run <id>           the ONLY deleting path. pacman-cache / orphans need root and are NOT run
#                                 here: prints {"terminal": "<command line>"} for the UI to run in a terminal.
#                                 flatpak-unused: flatpak uninstall --unused -y. The Trash itself is only measured, never emptied here (it is opened in the file manager instead). Prints {"ok": bool, "message": ""}.
#                                 Unknown id: exit 2, nothing runs.
# Arguments are never put into script text.
export LC_ALL=C
TRASH="${HOME}/.local/share/Trash"

usage() { echo "usage: cleanup.sh sizes | run <id>" >&2; exit 2; }

sizes() {
    exec python3 -I -c '
import json, os, re, shutil, subprocess, sys
trash = sys.argv[1]
UNITS = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}

def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=dict(os.environ, LC_ALL="C"))
        return r.returncode, r.stdout
    except Exception:
        return 1, ""

def row(id, label, bytes_, count, root, note=""):
    return {"id": id, "label": label, "bytes": bytes_, "count": count, "needsRoot": root, "note": note}

def missing(id, label, root):
    return row(id, label, None, None, root, "not installed")

def to_bytes(num, unit):
    return int(float(num) * UNITS.get(unit, 1))

out = []

if shutil.which("paccache"):
    rc, text = run(["paccache", "-d", "-k2"])
    m = re.search(r"(\d+) candidates?.*?would be saved: ([\d.]+) (\w+)", text)
    out.append(row("pacman-cache", "Old package cache", to_bytes(m.group(2), m.group(3)) if m else 0, int(m.group(1)) if m else 0, True))
else:
    out.append(missing("pacman-cache", "Old package cache", True))

if shutil.which("pacman"):
    rc, text = run(["pacman", "-Qdtq"])
    names = [l.strip() for l in text.splitlines() if l.strip()]
    total = 0
    if names:
        rc, info = run(["pacman", "-Qi"] + names)
        for m in re.finditer(r"^Installed Size\s*:\s*([\d.]+) (\w+)", info, re.M):
            total += to_bytes(m.group(1), m.group(2))
    out.append(row("orphans", "Orphaned packages", total, len(names), True))
else:
    out.append(missing("orphans", "Orphaned packages", True))

if shutil.which("flatpak"):
    rc, text = run(["flatpak", "uninstall", "--unused", "--assumeno"])
    n = len(re.findall(r"^\s*\d+\.\s", text, re.M))
    out.append(row("flatpak-unused", "Unused Flatpak runtimes", None, n, False, "size unknown"))
else:
    out.append(missing("flatpak-unused", "Unused Flatpak runtimes", False))

tb = 0
if os.path.isdir(trash):
    rc, text = run(["du", "-sb", trash])
    f = text.split()
    tb = int(f[0]) if f and f[0].isdigit() else 0
out.append(row("trash", "Trash", tb, None, False))

print(json.dumps(out))
' "$TRASH"
}

fail() { echo "{\"ok\": false, \"message\": \"$1\"}"; exit 1; }
ok() { echo "{\"ok\": true, \"message\": \"$1\"}"; exit 0; }

run_one() {
    id=$1
    case "$id" in
        pacman-cache) echo '{"terminal": "doas paccache -r -k2"}'; exit 0 ;;
        orphans) echo '{"terminal": "doas pacman -Rns $(pacman -Qdtq)"}'; exit 0 ;;
        flatpak-unused)
            command -v flatpak >/dev/null 2>&1 || fail "flatpak is not installed"
            flatpak uninstall --unused -y >/dev/null 2>&1 || fail "flatpak failed"
            ok "Removed unused Flatpak runtimes"
            ;;
        *) usage ;;
    esac
}

case "${1:-}" in
    sizes) sizes ;;
    run) [ -n "${2:-}" ] || usage; run_one "$2" ;;
    *) usage ;;
esac

#!/bin/sh
# NAS / network mounts for NasWatch.qml.
#   nas.sh status <mount> [<mount> ...]
#       prints [{"path":"/mnt/disk1","state":"mounted"}, ...]. state: mounted (listed in the mount table and a
#       `timeout 3 stat` of it answers), stale (listed, but the stat hangs or fails: a dead NFS server), unmounted (not in
#       the table). Only the mount point itself is stat-ed; no directory is listed and no file is opened.
#   nas.sh remount <mount> <configured mount> [<configured mount> ...]
#       runs `mount -- <mount>` (the fstab line is noauto,user) and prints {"ok":true|false,"message":""}. The mount
#       must be one of the configured ones given after it, else exit 2 and nothing runs.
# Paths must be absolute and made of letters, digits and . _ - / only (no `..`); anything else exits 2.
# NAS_MOUNTS overrides /proc/self/mounts and NAS_TIMEOUT the 3 s, for tests. Arguments never enter script text.
exec python3 -I -c '
import json, os, re, subprocess, sys

mode, args = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
limit = os.environ.get("NAS_TIMEOUT", "3")
table = os.environ.get("NAS_MOUNTS", "/proc/self/mounts")
SAFE = re.compile(r"^/[A-Za-z0-9._/-]*$")

def usage():
    print("usage: nas.sh status <mount>... | remount <mount> <configured mount>...", file=sys.stderr)
    sys.exit(2)

def safe(p):
    return bool(SAFE.match(p)) and ".." not in p.split("/") and p != "/"

def mounted_set():
    out = set()
    try:
        with open(table) as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    # the kernel writes a space in a path as \\040
                    out.add(re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), parts[1]))
    except OSError:
        pass
    return out

if mode == "status":
    if not args or not all(safe(a) for a in args):
        usage()
    mounted = mounted_set()
    res = []
    for p in args:
        norm = p.rstrip("/") or "/"
        if norm not in mounted:
            res.append({"path": p, "state": "unmounted"})
            continue
        try:
            r = subprocess.run(["timeout", limit, "stat", "--", p], capture_output=True, timeout=float(limit) + 2)
            ok = r.returncode == 0
        except Exception:
            ok = False
        res.append({"path": p, "state": "mounted" if ok else "stale"})
    print(json.dumps(res))
elif mode == "remount":
    if len(args) < 2 or not all(safe(a) for a in args) or args[0] not in args[1:]:
        usage()
    try:
        r = subprocess.run(["mount", "--", args[0]], capture_output=True, text=True, timeout=30)
        msg = (r.stderr or r.stdout).strip().splitlines()
        print(json.dumps({"ok": r.returncode == 0, "message": "" if r.returncode == 0 else (msg[-1] if msg else "mount failed")}))
    except Exception as e:
        print(json.dumps({"ok": False, "message": "mount failed"}))
else:
    usage()
' "$@"

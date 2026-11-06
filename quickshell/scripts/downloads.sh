#!/bin/sh
# File names and sizes in one folder, for DownloadWatch.qml.
#   downloads.sh [<folder>]        default $HOME/Downloads
# Prints [{"name":"movie.mkv","size":1234}, ...] for the regular files directly in the folder (no subfolders, no
# recursion), skipping hidden files and unfinished downloads (*.part, *.crdownload, *.tmp, any case). Only
# directory entries and their sizes are read: a file is never opened. A missing folder gives [].
exec python3 -I -c '
import json, os, sys

folder = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "" else os.path.join(os.environ.get("HOME", ""), "Downloads")
SKIP = (".part", ".crdownload", ".tmp")
out = []
try:
    with os.scandir(folder) as it:
        for e in it:
            n = e.name
            if n.startswith(".") or n.lower().endswith(SKIP):
                continue
            try:
                if e.is_symlink() or not e.is_file(follow_symlinks=False):
                    continue
                out.append({"name": n, "size": e.stat(follow_symlinks=False).st_size})
            except OSError:
                continue
except OSError:
    pass
out.sort(key=lambda r: r["name"])
print(json.dumps(out))
' "$@"

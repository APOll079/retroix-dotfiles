#!/bin/sh
# File and folder NAME search for the launcher (its Files tab and "/ report").
#   filesearch.sh <query> [folder]
# Prints up to 50 paths, one per line (a folder has a trailing "/"), found under `folder` (default $HOME) with the
# first of: fd, plocate, find. Hidden files and folders, node_modules and .git are skipped; matching is case-insensitive
# and on the NAME only. The query is a plain string (never a pattern): leading dash, control characters and more than
# 100 characters are refused (exit 2); the glob / regex characters in it are escaped for each tool. A path that
# contains a newline cannot be listed one per line and is skipped. `folder` must be an existing folder ("~" and "~/x"
# allowed; exit 4 when it is not). An empty query is allowed only with a folder (lists the first 50 names there).
# Exit codes: 0 done (maybe nothing found), 2 bad query, 3 none of fd, plocate, find is installed, 4 bad folder.
# Arguments are passed to the tools as arguments, never spliced into script text. Nothing is changed.
exec python3 -I -c '
import os, re, shutil, subprocess, sys

LIMIT = 50
SKIP = ("node_modules", ".git")


def valid_query(q):
    return len(q) <= 100 and not q.startswith("-") and not re.search(r"[\x00-\x1f\x7f]", q)


def resolve_folder(arg, home):
    if arg is None:
        return home
    if arg == "~" or arg.startswith("~/"):
        arg = home + arg[1:]
    if not os.path.isabs(arg) or re.search(r"[\x00-\x1f\x7f]", arg):
        return None
    arg = os.path.realpath(arg)
    return arg if os.path.isdir(arg) else None


def glob_escape(q):
    return re.sub(r"([*?\[\]\\])", r"\\\1", q)


def regex_escape(q):
    return re.sub(r"([.\[\]\\*+?(){}|^$])", r"\\\1", q)


def command(tool, q, folder):
    if tool == "fd":
        c = ["fd", "--fixed-strings", "--ignore-case", "--max-results", str(LIMIT), "--print0"]
        for s in SKIP:
            c += ["--exclude", s]
        return c + ["--", q, folder]
    if tool == "plocate":
        # names only, under the folder, no hidden component; node_modules / .git are dropped after
        rx = "^" + regex_escape(folder.rstrip("/")) + "/([^/.][^/]*/)*[^/]*" + regex_escape(q) + "[^/]*$"
        return ["plocate", "-i", "-l", str(LIMIT), "--null", "--regex", "--", rx]
    prune = ["(", "-name", ".*"]
    for s in SKIP:
        prune += ["-o", "-name", s]
    prune += [")", "-prune", "-o"]
    return ["find", folder, "-maxdepth", "6", "-mindepth", "1"] + prune + ["-iname", "*" + glob_escape(q) + "*", "-print0"]


def main():
    args = sys.argv[1:]
    if len(args) not in (1, 2):
        return 2
    q = args[0]
    home = os.environ.get("HOME", "")
    if not valid_query(q) or (q == "" and len(args) < 2) or not home.startswith("/"):
        return 2
    folder = resolve_folder(args[1] if len(args) == 2 else None, home)
    if folder is None:
        return 4
    tool = next((t for t in ("fd", "plocate", "find") if shutil.which(t)), None)
    if tool is None:
        return 3
    p = subprocess.Popen(command(tool, q, folder), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    out, n = [], 0
    buf = b""
    done = False
    while not done:
        chunk = os.read(p.stdout.fileno(), 65536)
        if not chunk:
            break
        buf += chunk
        parts = buf.split(b"\0")
        buf = parts.pop()
        for raw in parts:
            path = os.fsdecode(raw)
            if not path or "\n" in path or "\r" in path or not path.startswith("/"):
                continue
            rel = path[len(folder):].split("/") if path.startswith(folder) else path.split("/")
            if any(s in rel for s in SKIP) or any(c.startswith(".") for c in rel if c):
                continue
            if tool == "plocate" and q.lower() not in os.path.basename(path).lower():
                continue
            out.append(path + "/" if os.path.isdir(path) else path)
            if len(out) >= LIMIT:
                done = True
                break
    if done:
        p.kill()
    p.stdout.close()
    p.wait()
    sys.stdout.write("".join(o + "\n" for o in out))
    return 0


sys.exit(main())
' "$@"

#!/usr/bin/env python3
"""Repo checks for the retro desktop. Stdlib only.

  python3 scripts/check.py              full check (contract + your uncommitted changes vs HEAD)
  python3 scripts/check.py --hook edit  Claude Code PostToolUse hook (reads the hook JSON on stdin)
  python3 scripts/check.py --hook stop  Claude Code Stop hook (reads the hook JSON on stdin)

FAIL = something is broken or a listed behaviour is gone (blocks).
WARN = probably wrong; say in the report whether it was on purpose (blocks the Stop hook once).
The behaviour contract lives in tests/behaviours.tsv: one line per behaviour that must not
silently disappear. Removing or changing one on purpose = edit that file in the same commit
and say so in the report.
"""
import json, os, re, shutil, subprocess, sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QMLLINT = "/usr/lib/qt6/bin/qmllint"
PUA = re.compile("[\ue000-\uf8ff\U000f0000-\U000ffffd]")
ESC = re.compile(r"\\u\{?([0-9a-fA-F]{4,6})\}?")
SIZE_PROP = re.compile(r"\b(pixelSize|width|height|implicitWidth|implicitHeight|spacing|(?:left|right|top|bottom)?[Mm]argins?|padding|radius)\s*:\s*(\d+)\b")
BEHAVIOUR = re.compile(r"acceptedButtons|on\w*Clicked|onPressed|Keys\.on|Qt\.Key_|hl\.bind\(|IpcHandler|function \w+\(|-- help:")
HALF_POS = re.compile(r"\b(?:x|y|width|height|pixelSize|implicitWidth|implicitHeight|\w*[Oo]ffset|\w*[Mm]argins?)\s*:[^/\n]*/\s*[23]\b")
CONST_HALF = re.compile(r"(?:MenuStyle\.\w+|\b\d+)\s*(?:\*\s*\d+\s*)?/\s*[23]\b")  # constants divide to whole numbers
SPACING_PROP = re.compile(r"readonly property int (\w*(?:[Pp]ad|[Gg]ap|[Ii]nset|[Ss]pacing)\w*)\s*:\s*(\d+)\b")
SPACE_STEPS = (0, 2, 4, 6, 8, 12)   # MenuStyle.space*
SECRET = re.compile(r"(access_token|refresh_token|client_secret)\s*[\"':=]+\s*[\"']?[A-Za-z0-9_\-]{16,}")

fails, warns = [], []
MODE = None   # "edit" inside the PostToolUse hook, "stop" in the Stop hook, None for a plain run


def git(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def glyphs(text):
    n = len(PUA.findall(text))
    n += sum(1 for h in ESC.findall(text) if PUA.match(chr(int(h, 16))))
    return n


def changed_files():
    files = set(git("diff", "--name-only", "HEAD").split())
    files |= set(git("ls-files", "--others", "--exclude-standard").split())
    return sorted(f for f in files if (ROOT / f).exists())


def diff_lines(only=None):
    """(file, added_lines, removed_lines) against HEAD; untracked files count as all added."""
    out = {}
    cur = None
    for line in git("diff", "-U0", "HEAD", *( ["--", only] if only else [] )).splitlines():
        if line.startswith("+++ "):
            cur = line[6:] if line.startswith("+++ b/") else None
            if cur:
                out.setdefault(cur, ([], []))
        elif line.startswith("--- a/"):
            cur = line[6:]
            out.setdefault(cur, ([], []))
        elif cur and line.startswith("+") and not line.startswith("+++"):
            out[cur][0].append(line[1:])
        elif cur and line.startswith("-") and not line.startswith("---"):
            out[cur][1].append(line[1:])
    for f in git("ls-files", "--others", "--exclude-standard").split():
        if only and f != only:
            continue
        p = ROOT / f
        if p.is_file() and p.suffix in (".qml", ".lua", ".py", ".sh", ".js", ".json", ".md"):
            out[f] = (p.read_text(encoding="utf-8", errors="replace").splitlines(), [])
    return out


# ---------- checks ----------

def check_contract():
    path = ROOT / "tests/behaviours.tsv"
    if not path.exists():
        warns.append("tests/behaviours.tsv is missing: no behaviour contract checked")
        return
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            fails.append(f"tests/behaviours.tsv:{n}: needs file<TAB>regex<TAB>description")
            continue
        f, rx, desc = parts[0], parts[1], parts[2]
        p = ROOT / f
        if not p.exists():
            fails.append(f"BEHAVIOUR GONE: {desc}  ({f} no longer exists; contract line {n})")
        elif not re.search(rx, p.read_text(encoding="utf-8", errors="replace")):
            fails.append(f"BEHAVIOUR GONE: {desc}  ({f} no longer matches /{rx}/; contract line {n})")


_SINGLETONS = None


def singletons():
    """Names of the `pragma Singleton` QML files under quickshell/ (Config, MenuStyle, ...)."""
    global _SINGLETONS
    if _SINGLETONS is None:
        _SINGLETONS = sorted(q.stem for q in ROOT.glob("quickshell/**/*.qml")
                             if re.search(r"^\s*pragma\s+Singleton", q.read_text(encoding="utf-8", errors="replace"), re.M))
    return _SINGLETONS or ["NoSingletons"]


def check_design():
    """docs/DESIGN.md is generated from MenuStyle.qml and themes.json; a stale one is a WARN while
    editing (so changing MenuStyle isn't blocked every time) and a FAIL in the full run and at stop."""
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "gen-design.py"), "--check"], capture_output=True, text=True)
    if r.returncode:
        msg = "docs/DESIGN.md is stale (MenuStyle.qml or themes.json changed): run python3 scripts/gen-design.py"
        (warns if MODE == "edit" else fails).append(msg)


def check_interaction():
    """tests/interaction/*.qml: real simulated clicks and keys on the shared components, offscreen. Slow (a few
    seconds), so not in the per-edit hook."""
    if MODE == "edit":
        return
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "run-interaction-tests.py")], capture_output=True, text=True)
    if r.returncode:
        bad = [l for l in r.stdout.splitlines() if "TEST FAIL" in l]
        fails.append("interaction tests failed (python3 scripts/run-interaction-tests.py):\n      " + "\n      ".join(bad[:6]))


def check_qmldir():
    for qmldir in ROOT.glob("quickshell/**/qmldir"):
        listed = set(re.findall(r"^(?:singleton\s+)?\w+\s+[\d.]+\s+(\S+\.qml)", qmldir.read_text(), re.M))
        for q in qmldir.parent.glob("*.qml"):
            if q.name not in listed:
                fails.append(f"{q.relative_to(ROOT)} is not listed in {qmldir.relative_to(ROOT)} (gives 'X is not a type')")


def lint_problems(path):
    """The qmllint warnings / errors that matter for one file (header lines only, not code excerpts)."""
    r = subprocess.run([QMLLINT, "-I", "/usr/lib/qt6/qml", str(path)], capture_output=True, text=True)
    # qmllint can't see a singleton's members (no root qmldir), so "Member x not found on type
    # Config" is noise for every `pragma Singleton` file; the offscreen renders cover those.
    return [l for l in (r.stdout + r.stderr).splitlines()
            if re.match(r"(Warning|Error)\b", l)
            and re.search(r"error|is not a type|Expected token|Syntax|not found", l, re.I)
            and not re.search(r'Member ".*" not found on type "(%s)"' % "|".join(singletons()), l)]


def lint_key(line):
    """A lint line without its file name and position, so the same message compares equal after edits."""
    return re.sub(r"^\w+:\s*\S+\.qml:\d+:\d+:\s*", "", line)


def check_syntax(files):
    for f in files:
        p = ROOT / f
        if p.suffix == ".py":
            r = subprocess.run([sys.executable, "-m", "py_compile", str(p)], capture_output=True, text=True)
            if r.returncode:
                fails.append(f"{f}: Python syntax: {r.stderr.strip().splitlines()[-1]}")
        elif p.suffix == ".sh" or (p.parent.name == "scripts" and p.suffix == "" and p.read_text(errors="replace").startswith("#!/bin/bash")):
            r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
            if r.returncode:
                fails.append(f"{f}: bash syntax: {r.stderr.strip()}")
        elif p.suffix == ".lua":
            luac = shutil.which("luac") or shutil.which("luac5.4")
            if luac:
                r = subprocess.run([luac, "-p", str(p)], capture_output=True, text=True)
                if r.returncode:
                    fails.append(f"{f}: Lua syntax: {r.stderr.strip()}")
        elif p.suffix == ".json":
            try:
                json.loads(p.read_text(encoding="utf-8"))
            except Exception as e:
                fails.append(f"{f}: invalid JSON: {e}")
        elif p.suffix == ".qml" and os.path.exists(QMLLINT):
            bad = lint_problems(p)
            if bad:
                # Lint noise that was already in the committed file doesn't count: only what this change adds
                old = git("show", f"HEAD:{f}")
                if old:
                    tmp = p.with_name("_headlint_" + p.name)   # same folder, so its imports resolve
                    try:
                        tmp.write_text(old, encoding="utf-8")
                        before = Counter(lint_key(l) for l in lint_problems(tmp))
                    finally:
                        tmp.unlink(missing_ok=True)
                    fresh = []
                    for l in bad:
                        k = lint_key(l)
                        if before[k] > 0:
                            before[k] -= 1
                        else:
                            fresh.append(l)
                    bad = fresh
            if bad:
                fails.append(f"{f}: qmllint:\n      " + "\n      ".join(bad[:5]))


def check_diff(files):
    d = diff_lines()
    added_anywhere = {l.strip() for a, _ in d.values() for l in a}
    for f in files:
        if f not in d:
            continue
        added, removed = d[f]
        p = ROOT / f
        if p.suffix == ".qml":
            old = git("show", f"HEAD:{f}")
            if old:
                before, after = glyphs(old), glyphs(p.read_text(encoding="utf-8", errors="replace"))
                if after < before:
                    warns.append(f"{f}: {before - after} icon glyph(s) fewer than in HEAD. Lost in a rewrite? If on purpose, say which.")
            for l in added:
                if PUA.search(l):
                    warns.append(f"{f}: raw icon glyph added, write it as a \\uXXXX escape: {l.strip()[:80]}")
                if not l.lstrip().startswith("//") and not re.search(r"Math\.(round|floor|ceil)\(", l) \
                        and HALF_POS.search(CONST_HALF.sub("0", l)):
                    warns.append(f"{f}: position or size divided without rounding (blurs 1px bevels), wrap it in Math.round: {l.strip()[:80]}")
                if "MenuStyle.qml" in f:
                    for name, val in SPACING_PROP.findall(l):
                        if int(val) not in SPACE_STEPS:
                            warns.append(f"{f}: spacing '{name}: {val}' is off the scale {SPACE_STEPS[1:]}, use a space* step")
                if "MenuStyle.qml" not in f:
                    for prop, val in SIZE_PROP.findall(l):
                        if prop == "radius" and int(val) > 0:
                            fails.append(f"{f}: radius {val}: no rounding in this theme")
                        elif prop != "radius" and int(val) > 2:
                            warns.append(f"{f}: magic number '{prop}: {val}', use a MenuStyle name: {l.strip()[:80]}")
                elif re.search(r"(Font|font|Title|title)Size\s*:\s*(\d+)", l):
                    v = int(re.search(r"(?:Font|font|Title|title)Size\s*:\s*(\d+)", l).group(1))
                    if v not in (12, 16) and "Liberation" not in l:
                        warns.append(f"{f}: font size {v}: Monaco only hints at 12 / 16 (add 'Liberation' in the comment if it's that font)")
        for l in removed:
            s = l.strip()
            if BEHAVIOUR.search(s) and s not in added_anywhere:
                warns.append(f"{f}: behaviour line removed (moved? say so; removed? the task must name it): {s[:90]}")
        for l in added:
            if SECRET.search(l):
                fails.append(f"{f}: looks like a token or secret: {l.strip()[:60]}...")


def run(files):
    check_contract()
    check_design()
    check_qmldir()
    check_interaction()
    check_syntax(files)
    check_diff(files)


def report():
    lines = []
    for x in fails:
        lines.append(f"FAIL  {x}")
    for x in dict.fromkeys(warns):
        lines.append(f"WARN  {x}")
    return "\n".join(lines)


def main():
    global MODE
    hook = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "--hook" else None
    MODE = hook
    data = {}
    if hook:
        try:
            data = json.load(sys.stdin)
        except Exception:
            data = {}
    if hook == "edit":
        fp = (data.get("tool_input") or {}).get("file_path", "")
        try:
            rel = str(Path(fp).resolve().relative_to(ROOT))
        except ValueError:
            return 0
        run([rel])
        global warns
        warns = [w for w in warns if w.startswith(rel)]
        if fails:
            print(report() + "\n(scripts/check.py: fix the FAIL lines before going on)", file=sys.stderr)
            return 2
        return 0  # WARNs wait for the Stop hook, so mid-refactor edits aren't nagged
    run(changed_files())
    out = report()
    if hook == "stop":
        if not out:
            return 0
        if data.get("stop_hook_active"):
            # Already blocked once: let it finish, but the report must carry these.
            print(out)
            return 0
        print(out + "\n\nscripts/check.py: fix every FAIL. For each WARN, fix it or say in your report why it is on purpose. "
              "A behaviour removed on purpose also needs its line in tests/behaviours.tsv changed.", file=sys.stderr)
        return 2
    print(out or "check: all good")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

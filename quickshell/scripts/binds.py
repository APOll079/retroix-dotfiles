#!/usr/bin/env python3
"""List the Hyprland keybinds for the cheat sheet (popups/CheatSheet.qml).

Usage: binds.py <file.lua> [<file.lua> ...]
Reads every `hl.bind(<keys>, ...)` call and prints a JSON list of {keys, group, label}.
The text comes from a trailing comment on the line of the bind:

    hl.bind(mainMod .. " + " .. "Q", ...)  -- help: Windows | Close menu or window

"Windows" is the group, "Close menu or window" the label; the group is optional. A bind without
a help comment is listed under "Other" with a label made from its dispatcher.
A `for i = 1, 4 do` loop around a bind turns `i` into "1-4".
Plain Python, standard library only.
"""
import json
import re
import sys

MAIN_MOD = "SUPER"
KEY_NAMES = {
    "super": "Super", "shift": "Shift", "ctrl": "Ctrl", "control": "Ctrl", "alt": "Alt",
    "return": "Enter", "enter": "Enter", "space": "Space", "escape": "Esc", "period": ".",
    "comma": ",", "left": "Left", "right": "Right", "up": "Up", "down": "Down",
    "print": "Print", "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "xf86audioplay": "Media Play", "xf86audiopause": "Media Pause", "xf86audionext": "Media Next",
    "xf86audioprev": "Media Previous", "xf86audiostop": "Media Stop", "xf86audiomute": "Mute",
    "xf86audiomicmute": "Mic mute", "xf86audioraisevolume": "Volume up", "xf86audiolowervolume": "Volume down",
    "xf86monbrightnessup": "Brightness up", "xf86monbrightnessdown": "Brightness down",
    "mouse:272": "Left drag", "mouse:273": "Right drag", "mouse:275": "Side button 1", "mouse:276": "Side button 2",
}
GROUP_ORDER = ["Apps", "Windows", "Workspaces", "Screen", "Desktop", "Mouse", "Media"]
HELP = re.compile(r"--\s*help:\s*(?:([^|]+?)\s*\|\s*)?(.+?)\s*$")
FOR = re.compile(r"^\s*for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do\b")


def first_arg(text):
    """The first argument of a call: text after `(` up to the top-level comma."""
    depth, quote, i = 0, None, 0
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return text[:i]
            depth -= 1
        elif c == "," and depth == 0:
            return text[:i]
        i += 1
    return text


def evaluate(expr, loop):
    out = ""
    for part in expr.split(".."):
        part = part.strip()
        if part == "mainMod":
            out += MAIN_MOD
        elif len(part) >= 2 and part[0] in "\"'" and part[-1] == part[0]:
            out += part[1:-1]
        elif loop and part == loop[0]:
            out += "%s-%s" % (loop[1], loop[2])
        else:
            out += part
    return out


def pretty(keys):
    names = []
    for k in (p.strip() for p in keys.split("+")):
        k = k.strip()
        low = k.lower()
        if low in KEY_NAMES:
            names.append(KEY_NAMES[low])
        elif re.fullmatch(r"[A-Za-z]", k):
            names.append(k.upper())
        else:
            names.append(k if re.search(r"\d|XF86|^F\d+$", k) else k.capitalize())
    return "+".join(names)


DIRECTIONS = ["Left", "Right", "Up", "Down"]


def fold(binds):
    """Fold duplicate rows (rule based, order kept):
    - four direction rows ("Super+Left" ... "Super+Down", "Focus left" ... "Focus down") -> "Super+Arrows | Move focus"
    - rows with the same group and label but other keys -> one row, keys joined with " / "
      (a side-button row keeps its own line: "<label> (side button)")."""
    out = []
    # directions: same group, same modifier prefix, labels "<word> <direction>"
    seen = {}
    for b in binds:
        prefix, _, last = b["keys"].rpartition("+")
        m = re.match(r"^(.*\S)\s+(left|right|up|down)$", b["label"], re.I)
        if last in DIRECTIONS and m and m.group(2).lower() == last.lower():
            seen.setdefault((b["group"], prefix, m.group(1).lower()), {})[last] = b
    folded = {k for k, v in seen.items() if len(v) == 4}
    done = set()
    for b in binds:
        prefix, _, last = b["keys"].rpartition("+")
        m = re.match(r"^(.*\S)\s+(left|right|up|down)$", b["label"], re.I)
        key = (b["group"], prefix, m.group(1).lower()) if m else None
        if key in folded and last in DIRECTIONS:
            if key not in done:
                done.add(key)
                out.append({"keys": (prefix + "+" if prefix else "") + "Arrows", "group": b["group"], "label": "Move " + m.group(1).lower()})
            continue
        out.append(b)
    # same label, other keys
    merged, index = [], {}
    for b in out:
        k = (b["group"], b["label"])
        if k not in index:
            index[k] = len(merged)
            merged.append(dict(b))
            continue
        first = merged[index[k]]
        side = lambda x: x["keys"].lower().startswith("side button")
        if side(b) != side(first):
            # a side-button twin of a keyboard / mouse row stays separate
            (b if side(b) else first)["label"] += " (side button)"
            merged.append(dict(b))
        elif b["keys"] not in first["keys"].split(" / "):
            first["keys"] += " / " + b["keys"]
    return merged


def dispatcher_label(rest):
    m = re.search(r"hl\.dsp\.([\w.]+)", rest)
    return m.group(1).replace(".", " ").replace("_", " ") if m else "custom action"


def parse(path):
    binds, loop = [], None
    # errors="replace": one odd byte in a comment must not hide the whole file
    for line in open(path, encoding="utf-8", errors="replace"):
        m = FOR.match(line)
        if m:
            loop = (m.group(1), m.group(2), m.group(3))
            continue
        if re.match(r"^end\b", line):
            loop = None
            continue
        m = re.search(r"\bhl\.bind\(", line)
        if not m or line.lstrip().startswith("--"):
            continue
        rest = line[m.end():]
        keys = pretty(evaluate(first_arg(rest), loop))
        h = HELP.search(line)
        group, label = ("Other", dispatcher_label(rest)) if not h else (h.group(1) or "Other", h.group(2))
        binds.append({"keys": keys, "group": group, "label": label})
    return binds


if __name__ == "__main__":
    result = []
    for p in sys.argv[1:]:
        try:
            result += parse(p)
        except Exception as e:  # a missing / unreadable / odd file must not hide the others
            print("binds.py: %s: %s" % (p, e), file=sys.stderr)
    result = fold(result)
    rank = lambda b: GROUP_ORDER.index(b["group"]) if b["group"] in GROUP_ORDER else len(GROUP_ORDER)
    result.sort(key=rank)  # stable: file order inside a group
    print(json.dumps(result))

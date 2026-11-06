#!/bin/sh
# Battery of a Logitech mouse through Solaar, for MouseState.qml.
#   solaar.sh                 prints one JSON line  {"present": bool, "name": str, "percent": int|null, "charging": bool}
# Runs `solaar show` (read only, one short call) and parses it defensively: the format differs between Solaar versions
# ("Battery: 80%, discharging.", "Battery: 55% (recharging)", "Battery: full", "Battery level: 70", "unknown (device is offline)").
# Devices are the blocks that start with "<n>: <name>"; a block whose "Kind" is mouse wins, a block without a Kind line
# counts too. Anything it cannot read (no solaar, no device, offline, no percent) is {"present": false}; it never fails.
# Exit status is always 0.
command -v solaar >/dev/null 2>&1 || { echo '{"present":false,"name":"","percent":null,"charging":false}'; exit 0; }
timeout 15 solaar show 2>/dev/null </dev/null | python3 -I -c '
import json, re, sys

def parse(text):
    blocks, cur = [], None
    for line in text.splitlines():
        m = re.match(r"^\s*\d+:\s+(\S.*?)\s*$", line)
        if m:
            cur = {"name": m.group(1), "kind": "", "percent": None, "charging": False, "seen": False}
            blocks.append(cur)
            continue
        if cur is None:
            continue
        k = re.match(r"^\s*Kind\s*:\s*(\S.*?)\s*$", line)
        if k:
            cur["kind"] = k.group(1).lower()
            continue
        b = re.match(r"^\s*Battery(?:\s+level)?\s*:\s*(.*)$", line, re.I)
        if b:
            rest = b.group(1).lower()
            cur["seen"] = True
            p = re.search(r"(\d{1,3})\s*%", rest) or re.match(r"^\s*(\d{1,3})\b", rest)
            if p and int(p.group(1)) <= 100:
                cur["percent"] = int(p.group(1))
            elif re.match(r"^\s*full\b", rest):
                cur["percent"] = 100
            cur["charging"] = bool(re.search(r"(?<!dis)charging", rest))
    cands = [b for b in blocks if b["percent"] is not None and b["kind"] in ("", "mouse", "trackball")]
    cands.sort(key=lambda b: 0 if b["kind"] in ("mouse", "trackball") else 1)
    if not cands:
        return {"present": False, "name": "", "percent": None, "charging": False}
    b = cands[0]
    return {"present": True, "name": b["name"][:60], "percent": b["percent"], "charging": b["charging"]}

try:
    out = parse(sys.stdin.read())
except Exception:
    out = {"present": False, "name": "", "percent": None, "charging": False}
print(json.dumps(out))
'
exit 0

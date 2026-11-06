#!/bin/sh
# Listening ports for the Task Manager's Ports tab.
#   ports.sh
# Runs `ss -ltunp` (listening TCP and UDP sockets with their process) and prints JSON
# [{"proto":"tcp","port":22,"addr":"0.0.0.0","pid":1234,"name":"sshd"}, ...] sorted by port, then protocol.
# pid is null and name "" for a socket whose owner ss may not show (other users' processes). Lines that are not a
# socket (headers, junk) are skipped; the same socket listed twice (IPv4 + IPv6 copies of one pid) stays. No
# argument is used; nothing is changed. Without ss the output is [].
exec python3 -I -c '
import json, re, subprocess, sys

def parse(text):
    out = []
    seen = set()
    for line in text.splitlines():
        f = line.split(None, 6)
        if len(f) < 5:
            continue
        proto = f[0].lower()
        if proto not in ("tcp", "udp"):
            continue
        local = f[4]
        if ":" not in local:
            continue
        addr, port = local.rsplit(":", 1)
        if not port.isdigit() or not (0 < int(port) < 65536):
            continue
        addr = addr.strip("[]").split("%", 1)[0]
        pid, name = None, ""
        if len(f) > 6:
            m = re.search(r"\(\(\"(.*?)\",pid=(\d+)", f[6])
            if m:
                name, pid = m.group(1), int(m.group(2))
        key = (proto, int(port), addr, pid)
        if key in seen:
            continue
        seen.add(key)
        out.append({"proto": proto, "port": int(port), "addr": addr, "pid": pid, "name": name})
    out.sort(key=lambda r: (r["port"], r["proto"], r["addr"]))
    return out

try:
    r = subprocess.run(["ss", "-ltunp"], capture_output=True, text=True, timeout=10)
    text = r.stdout
except Exception:
    text = ""
print(json.dumps(parse(text)))
'

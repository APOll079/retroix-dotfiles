#!/usr/bin/env python3
"""VPN status for VpnState.qml.

  vpn-status.sh      (wrapper for this file) prints {"up": bool, "names": [..]}
                     names = active NetworkManager connections of type vpn or wireguard
                     (`nmcli -t -f NAME,TYPE connection show --active`). Only when NetworkManager lists none,
                     wireguard interfaces (`ip -j link`, linkinfo.info_kind == "wireguard") are used as a fallback.
A missing tool is skipped; nothing installed prints {"up": false, "names": []}. Always exits 0.
"""
import json, re, subprocess

KEEP = ("vpn", "wireguard")


def split_terse(line):
    """nmcli -t escapes ':' and '\\' in fields with a backslash; returns the fields."""
    out, cur, i = [], "", 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line):
            cur += line[i + 1]
            i += 2
            continue
        if c == ":":
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def parse_nmcli(text):
    names = []
    for line in text.splitlines():
        f = split_terse(line)
        if len(f) == 2 and f[1] in KEEP and f[0] and f[0] not in names:
            names.append(f[0])
    return names


def parse_ip(text):
    try:
        return [l["ifname"] for l in json.loads(text) if (l.get("linkinfo") or {}).get("info_kind") == "wireguard" and l.get("ifname")]
    except Exception:
        return []


def run(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return ""


def main():
    names = parse_nmcli(run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]))
    if not names:
        names = parse_ip(run(["ip", "-j", "link"]))
    names = [re.sub(r"[\x00-\x1f]", "", n) for n in names]
    print(json.dumps({"up": bool(names), "names": names}))


main()

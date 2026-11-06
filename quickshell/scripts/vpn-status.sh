#!/bin/sh
# VPN status for VpnState.qml: prints {"up": bool, "names": [..]}. See vpn-status.py (the parsing lives there).
exec python3 -I "$(dirname "$0")/vpn-status.py"

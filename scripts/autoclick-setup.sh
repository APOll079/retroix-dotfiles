#!/usr/bin/env bash
# One-time root-level setup for the autoclicker (hypr/scripts/autoclick, F8): ydotool, uinput permissions.
#   bash scripts/autoclick-setup.sh --dry-run    print every step and command, change nothing (start here)
#   bash scripts/autoclick-setup.sh              do it (asks doas for the password)
# Idempotent: a step that is already done is skipped and says so. Never deletes anything.
# Afterwards log out and in again, so the input group applies to your session.

set -u

DRY=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

# Same helpers as install.sh
say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf '   \033[33m! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

run() {
    if (( DRY )); then
        printf '   [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# Write stdin to a root-owned file, unless it already holds exactly that
write_root_file() {
    local dest="$1" body
    body="$(cat)"
    if [[ -f "$dest" && "$(cat "$dest")" == "$body" ]]; then
        note "already there: $dest"
        return 1
    fi
    if [[ -e "$dest" ]]; then
        warn "$dest exists with other content: leaving it alone (never overwritten); check it by hand"
        return 1
    fi
    if (( DRY )); then
        printf '   [dry-run] write %s:\n' "$dest"
        printf '%s\n' "$body" | sed 's/^/      | /'
    else
        printf '%s\n' "$body" | doas tee "$dest" >/dev/null && note "wrote $dest"
    fi
    return 0
}

have doas || { echo "doas not found: this script uses doas (as install.sh does)." >&2; exit 1; }
have pacman || { echo "pacman not found: this script is for Artix / Arch." >&2; exit 1; }
(( DRY )) && note "DRY RUN: nothing will be changed"

USER_NAME="${USER:-$(id -un)}"
DONE=() SKIPPED=()
did()  { DONE+=("$1"); }
skip() { SKIPPED+=("$1"); }
reload_udev=0

# 1. ydotool
say "ydotool"
if pacman -Q ydotool >/dev/null 2>&1; then
    note "ydotool is installed"; skip "ydotool"
else
    run doas pacman -S --needed ydotool && did "installed ydotool"
fi

# 2. udev rule: /dev/uinput belongs to the input group
say "udev rule"
if write_root_file /etc/udev/rules.d/80-uinput.rules <<'RULE'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
RULE
then did "wrote /etc/udev/rules.d/80-uinput.rules"; reload_udev=1; else skip "udev rule"; fi

# 3. load uinput at boot
say "module at boot"
if write_root_file /etc/modules-load.d/uinput.conf <<'CONF'
uinput
CONF
then did "wrote /etc/modules-load.d/uinput.conf"; else skip "modules-load.d"; fi

# 4. input group (counts only once you log in again, but the file is what matters here)
say "input group"
if getent group input | cut -d: -f4 | tr ',' '\n' | grep -qx "$USER_NAME"; then
    note "$USER_NAME is already in the input group"; skip "input group"
else
    run doas usermod -aG input "$USER_NAME" && did "added $USER_NAME to the input group (log out and in again)"
fi

# 5. the module, now
say "uinput module"
if lsmod | grep -q '^uinput '; then
    note "uinput is loaded"; skip "modprobe uinput"
else
    run doas modprobe uinput && did "loaded uinput"
    reload_udev=1
fi

# 6. udev: only when the rule is new or /dev/uinput is not the input group's yet
say "udev reload"
if [[ -e /dev/uinput && "$(stat -c %G /dev/uinput 2>/dev/null)" != input ]]; then reload_udev=1; fi
if (( reload_udev )); then
    run doas udevadm control --reload-rules && run doas udevadm trigger --name-match=uinput && did "reloaded udev"
else
    note "nothing to reload"; skip "udev reload"
fi

say "Summary"
(( DRY )) && note "(dry run: these are the steps it would take)"
(( ${#DONE[@]} )) && printf '   done:    %s\n' "${DONE[@]}"
(( ${#SKIPPED[@]} )) && printf '   skipped: %s\n' "${SKIPPED[@]}"
note "Next: log out and in again (input group), then press F8 on a safe spot to test."

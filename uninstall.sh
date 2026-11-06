#!/usr/bin/env bash
# Puts back what install.sh backed up: ~/config-backup-<stamp>/<name> -> ~/.config/<name>.
#   bash uninstall.sh [--yes] [backup-folder]
# Without --yes it only shows what it would copy. With no folder it takes the newest ~/config-backup-*.
# It copies the backup over the current files; files that install.sh added and the backup never had stay (remove
# them by hand). Nothing outside ~/.config (or $XDG_CONFIG_HOME) is touched.
set -u
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
yes=0
[ "${1:-}" = "--yes" ] && { yes=1; shift; }
backup="${1:-}"
[ -n "$backup" ] || backup=$(ls -d "$HOME"/config-backup-* 2>/dev/null | sort | tail -n 1)
[ -n "$backup" ] && [ -d "$backup" ] || { echo "no backup folder found (looked for ~/config-backup-*)"; exit 1; }
echo "Backup: $backup"
[ "$yes" = 1 ] || echo "(dry run: add --yes to copy)"
for item in "$backup"/*; do
    [ -e "$item" ] || continue
    name=$(basename "$item")
    if [ "$yes" = 1 ]; then
        if [ -d "$item" ]; then
            mkdir -p "$CONFIG/$name" && cp -r "$item/." "$CONFIG/$name/" && echo "  restored $name"
        else
            mkdir -p "$CONFIG" && cp "$item" "$CONFIG/$name" && echo "  restored $name"
        fi
    else
        echo "  would restore $name"
    fi
done
[ "$yes" = 1 ] && echo "Done. Restart quickshell and run hyprctl reload."
exit 0

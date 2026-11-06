#!/bin/sh
# Cursor and icon themes for the Themes menu. Every name and size is checked first and passed as ONE argument, never
# put into script text. A tool that is not installed (gsettings, hyprctl) is skipped, never an error.
#   appearance.sh list-cursors        JSON array of installed cursor themes (a folder with cursors/)
#   appearance.sh list-icons          JSON array of installed icon themes (index.theme with Directories=, no cursors/)
#   appearance.sh get-cursor          {"theme":"name","size":24} from gsettings ("" and 0 when unknown)
#   appearance.sh get-icons           {"theme":"name"}
#   appearance.sh set-cursor <name> <size>   gsettings cursor-theme + cursor-size, then hyprctl setcursor (runtime only), and the
#                                            choice is saved as "<name> <size>" in ${XDG_STATE_HOME:-$HOME/.local/state}/qs-cursor,
#                                            which hypr/env.lua reads at the next Hyprland start, so the cursor survives it
#   appearance.sh set-icons <name>           gsettings icon-theme
# Searched: $HOME/.local/share/icons, $HOME/.icons and $APPEARANCE_SYSTEM_ICONS (default /usr/share/icons).
# A name must match ^[A-Za-z0-9._-]+$ and not start with "." or "-". Exit codes: 0 ok, 2 bad usage or bad name.

export LC_ALL=C
SCHEMA=org.gnome.desktop.interface

valid_name() {
    case $1 in
        "" | .* | -* | *[!A-Za-z0-9._-]*) return 1 ;;
    esac
    return 0
}

dirs() {
    printf '%s\n' "${HOME:-/nonexistent}/.local/share/icons" "${HOME:-/nonexistent}/.icons" "${APPEARANCE_SYSTEM_ICONS:-/usr/share/icons}"
}

# kind = cursor | icon; one name per line, sorted, unique
scan() {
    dirs | while IFS= read -r base; do
        [ -d "$base" ] || continue
        for d in "$base"/*/; do
            [ -d "$d" ] || continue
            name=${d%/}
            name=${name##*/}
            valid_name "$name" || continue
            if [ "$1" = cursor ]; then
                [ -d "$d/cursors" ] && printf '%s\n' "$name"
            else
                [ -d "$d/cursors" ] && continue
                [ -f "$d/index.theme" ] && grep -q '^Directories=' "$d/index.theme" 2>/dev/null && printf '%s\n' "$name"
            fi
        done
    done | sort -u
}

json_list() {
    first=1
    printf '['
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        [ $first = 1 ] || printf ','
        first=0
        printf '"%s"' "$n"
    done
    printf ']\n'
}

# gsettings get prints 'name' (quoted); strip the quotes
gs_get() {
    command -v gsettings >/dev/null 2>&1 || return 0
    v=$(gsettings get "$SCHEMA" "$1" 2>/dev/null | head -n 1 | tr -d "'")
    printf '%s' "$v"
}

case $1 in
    list-cursors) scan cursor | json_list ;;
    list-icons) scan icon | json_list ;;
    get-cursor)
        t=$(gs_get cursor-theme)
        valid_name "$t" || t=""
        s=$(gs_get cursor-size | tr -dc '0-9')
        [ -n "$s" ] || s=0
        printf '{"theme":"%s","size":%s}\n' "$t" "$s"
        ;;
    get-icons)
        t=$(gs_get icon-theme)
        valid_name "$t" || t=""
        printf '{"theme":"%s"}\n' "$t"
        ;;
    set-cursor)
        valid_name "$2" || { echo "bad cursor theme name" >&2; exit 2; }
        case $3 in
            "" | *[!0-9]*) echo "bad cursor size" >&2; exit 2 ;;
        esac
        [ "$3" -ge 8 ] && [ "$3" -le 256 ] || { echo "bad cursor size" >&2; exit 2; }
        done_list=""
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set "$SCHEMA" cursor-theme "'$2'" >/dev/null 2>&1
            gsettings set "$SCHEMA" cursor-size "$3" >/dev/null 2>&1
            done_list=" gsettings"
        fi
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl setcursor "$2" "$3" >/dev/null 2>&1
            done_list="$done_list hyprctl"
        fi
        # remembered for hypr/env.lua (Hyprland reads the cursor from its environment at start)
        state=${XDG_STATE_HOME:-${HOME:-/nonexistent}/.local/state}
        if mkdir -p "$state" 2>/dev/null; then
            printf '%s %s\n' "$2" "$3" > "$state/qs-cursor" 2>/dev/null && done_list="$done_list state"
        fi
        echo "applied:${done_list:- none}"
        ;;
    set-icons)
        valid_name "$2" || { echo "bad icon theme name" >&2; exit 2; }
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set "$SCHEMA" icon-theme "'$2'" >/dev/null 2>&1
            echo "applied: gsettings"
        else
            echo "applied: none"
        fi
        ;;
    *)
        echo "usage: appearance.sh list-cursors|list-icons|get-cursor|get-icons|set-cursor <name> <size>|set-icons <name>" >&2
        exit 2
        ;;
esac

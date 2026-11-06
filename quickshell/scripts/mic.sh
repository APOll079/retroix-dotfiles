#!/bin/sh
# Microphone mute over WirePlumber's wpctl (the default source, so EasyEffects and every app hear it).
#   mic.sh toggle   flips the mute of the default source, then prints the new state
#   mic.sh status   prints {"muted":true|false}
# Exit codes: 0 ok, 1 failed (no default source, wpctl error), 2 wpctl is not installed, 64 bad usage.
# Used by AudioState.toggleMic() (the Super+Ctrl+M bind and the OSD). Arguments are never spliced into text.

export LC_ALL=C
src=@DEFAULT_AUDIO_SOURCE@

command -v wpctl >/dev/null 2>&1 || { echo "wpctl is not installed" >&2; exit 2; }

status() {
    out=$(wpctl get-volume "$src" 2>/dev/null) || { echo "no default microphone" >&2; exit 1; }
    case $out in
        *MUTED*) printf '{"muted":true}\n' ;;
        *) printf '{"muted":false}\n' ;;
    esac
}

case $1 in
    toggle)
        wpctl set-mute "$src" toggle || { echo "could not change the microphone mute" >&2; exit 1; }
        status
        ;;
    status) status ;;
    *) echo "usage: mic.sh toggle|status" >&2; exit 64 ;;
esac

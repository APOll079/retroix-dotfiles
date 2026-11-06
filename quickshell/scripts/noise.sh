#!/bin/sh
# EasyEffects preset loader for the Home tab's "Noise filter" button: the same call the EQ preset buttons use.
#   noise.sh load <preset>   easyeffects -l <preset>   (the flatpak com.github.wwmm.easyeffects when installed,
#                            else a native `easyeffects` on PATH; QS_EASYEFFECTS_CMD replaces both: tests use a fake)
# UNVERIFIED live: that loading the preset named in settings audio.noisePreset switches the input noise reduction on,
# and that audio.noiseOffPreset (or the EQ preset loaded before) switches it off again.
# Exit codes: 0 ok, 1 failed or bad name, 2 EasyEffects is not installed, 64 bad usage.
# The preset name is one argument, never part of script text; a name starting with "-" is refused.

export LC_ALL=C

[ "$1" = load ] && [ $# -eq 2 ] || { echo "usage: noise.sh load <preset>" >&2; exit 64; }
name=$2
case $name in
    "" | -*) echo "bad preset name" >&2; exit 1 ;;
esac

if [ -n "$QS_EASYEFFECTS_CMD" ]; then
    exec "$QS_EASYEFFECTS_CMD" -l "$name"
elif command -v flatpak >/dev/null 2>&1 && flatpak info com.github.wwmm.easyeffects >/dev/null 2>&1; then
    exec flatpak run com.github.wwmm.easyeffects -l "$name"
elif command -v easyeffects >/dev/null 2>&1; then
    exec easyeffects -l "$name"
fi
echo "EasyEffects is not installed" >&2
exit 2

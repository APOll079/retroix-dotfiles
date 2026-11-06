#!/usr/bin/env python3
"""Tests quickshell/scripts/{mic,noise,ocr,gif,colorpick}.sh with fakes (wpctl, easyeffects, grim, tesseract, wl-copy,
ffmpeg, hyprpicker) that log their arguments. Isolated PATH, scratch HOME and XDG_RUNTIME_DIR; nothing real is run.

  python3 tests/media-scripts-test.py        prints TEST pass|FAIL lines and "TEST done failures=N"
"""
import json, os, re, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "quickshell/scripts"
TOOLS = ("sh", "sed", "grep", "tr", "head", "mktemp", "rm", "basename", "dirname", "cat", "env", "printf", "python3", "tail")

FAKES = {
    # wpctl: get-volume prints MUTED when the state file says so; set-mute toggle flips it
    "wpctl": '''#!/bin/sh
echo "wpctl $*" >> "$FAKE_LOG"
st="$FAKE_DIR/muted"
case $1 in
  get-volume) if [ -e "$st" ]; then echo "Volume: 0.40 [MUTED]"; else echo "Volume: 0.40"; fi ;;
  set-mute) if [ -e "$st" ]; then rm -f "$st"; else : > "$st"; fi ;;
esac
''',
    "easyeffects": '''#!/bin/sh
echo "easyeffects $*" >> "$FAKE_LOG"
[ -n "$FAKE_FAIL" ] && exit 1
exit 0
''',
    "grim": '''#!/bin/sh
echo "grim $*" >> "$FAKE_LOG"
for last; do :; done
: > "$last"
''',
    "tesseract": '''#!/bin/sh
echo "tesseract $*" >> "$FAKE_LOG"
cat "$FAKE_DIR/ocr.txt"
''',
    "wl-copy": '''#!/bin/sh
cat > "$FAKE_DIR/clip"
echo "wl-copy" >> "$FAKE_LOG"
''',
    "ffmpeg": '''#!/bin/sh
echo "ffmpeg $*" >> "$FAKE_LOG"
[ -n "$FAKE_FAIL" ] && { for last; do :; done; echo partial > "$last"; exit 1; }
for last; do :; done
echo gif > "$last"
''',
    # notify-send: logs its arguments, answers the next chosen action from the file $FAKE_DIR/actions (one per call)
    "notify-send": '''#!/bin/sh
echo "notify-send $*" >> "$FAKE_LOG"
a=$(head -n 1 "$FAKE_DIR/actions" 2>/dev/null)
sed -i 1d "$FAKE_DIR/actions" 2>/dev/null
[ -n "$a" ] && echo "$a"
exit 0
''',
    "xdg-open": '''#!/bin/sh
echo "xdg-open $*" >> "$FAKE_LOG"
''',
    "hyprpicker": '''#!/bin/sh
echo "hyprpicker $*" >> "$FAKE_LOG"
printf '%s\\n' "$FAKE_COLOR"
''',
}

failures = 0


def check(name, cond):
    global failures
    print("TEST " + ("pass " if cond else "FAIL ") + name)
    if not cond:
        failures += 1


def main():
    work = Path(tempfile.mkdtemp(prefix="qsmedia-"))
    try:
        bin_, home, rt, fd = work / "bin", work / "home", work / "run", work / "fake"
        for d in (bin_, home, rt, fd):
            d.mkdir()
        rt.chmod(0o700)
        for tool in TOOLS:
            p = shutil.which(tool)
            if p:
                (bin_ / tool).symlink_to(p)
        log = work / "fake.log"
        log.write_text("")

        def install(*names):
            for n in names:
                f = bin_ / n
                f.write_text(FAKES[n])
                f.chmod(0o755)

        def run(script, *a, **extra):
            env = {"PATH": str(bin_), "HOME": str(home), "XDG_RUNTIME_DIR": str(rt), "FAKE_LOG": str(log), "FAKE_DIR": str(fd)}
            env.update(extra)
            return subprocess.run(["sh", str(SCRIPTS / script), *a], env=env, capture_output=True, text=True, timeout=30)

        def lines():
            return log.read_text().splitlines()

        # ---- mic.sh ----
        check("mic: wpctl missing is exit 2", run("mic.sh", "status").returncode == 2)
        install("wpctl")
        r = run("mic.sh", "status")
        check("mic status: unmuted", r.returncode == 0 and json.loads(r.stdout) == {"muted": False})
        r = run("mic.sh", "toggle")
        check("mic toggle: muted, wpctl got the default source", json.loads(r.stdout) == {"muted": True} and "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" in lines())
        check("mic status asks the default source", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@" in lines())
        r = run("mic.sh", "toggle")
        check("mic toggle again: unmuted", json.loads(r.stdout) == {"muted": False})
        check("mic: bad usage is 64", run("mic.sh", "x").returncode == 64 and run("mic.sh").returncode == 64)

        # ---- noise.sh ----
        check("noise: EasyEffects missing is exit 2", run("noise.sh", "load", "Denoise").returncode == 2)
        install("easyeffects")
        log.write_text("")
        r = run("noise.sh", "load", "Denoise; touch PWNED")
        check("noise: easyeffects -l <preset> with the name as one argument", r.returncode == 0 and lines() == ["easyeffects -l Denoise; touch PWNED"] and not list(work.glob("PWNED")))
        check("noise: a failing load is exit 1", run("noise.sh", "load", "x", FAKE_FAIL="1").returncode == 1)
        check("noise: an option-looking or empty name is refused", run("noise.sh", "load", "-q").returncode == 1 and run("noise.sh", "load", "").returncode == 1)
        check("noise: usage", run("noise.sh").returncode == 64)
        log.write_text("")
        fake = bin_ / "fake-ee"
        fake.write_text('#!/bin/sh\necho "override $*" >> "$FAKE_LOG"\n')
        fake.chmod(0o755)
        run("noise.sh", "load", "P", QS_EASYEFFECTS_CMD=str(fake))
        check("noise: QS_EASYEFFECTS_CMD replaces the call", lines() == ["override -l P"])

        # ---- ocr.sh ----
        check("ocr: tesseract missing is exit 2", run("ocr.sh", "10x10+0+0").returncode == 2)
        install("tesseract", "grim", "wl-copy")
        (fd / "ocr.txt").write_text("Hello world\nsecond line\n")
        log.write_text("")
        r = run("ocr.sh", "100x50+20+30")
        check("ocr: prints and copies the text", r.returncode == 0 and r.stdout == "Hello world\nsecond line\n" and (fd / "clip").read_text() == "Hello world\nsecond line\n")
        g = [l for l in lines() if l.startswith("grim ")][0].split()
        check("ocr: grim gets '-g \"x,y WxH\" <png in the runtime dir>'", g[1] == "-g" and g[2] == "20,30" and g[3] == "100x50" and g[4].startswith(str(rt) + "/qs-ocr-"))
        check("ocr: tesseract reads the png to stdout with swe+eng", any(l.startswith("tesseract ") and l.endswith("- -l swe+eng") for l in lines()))
        check("ocr: the temp png is removed", not list(rt.glob("qs-ocr-*")))
        (fd / "ocr.txt").write_text("  \n\n")
        (fd / "clip").write_text("keep")
        r = run("ocr.sh", "10x10+0+0")
        check("ocr: nothing recognised is exit 3 and the clipboard is kept", r.returncode == 3 and (fd / "clip").read_text() == "keep" and not list(rt.glob("qs-ocr-*")))
        check("ocr: a bad region is refused", run("ocr.sh", "1;2").returncode == 1 and run("ocr.sh", "10x10+0+0; touch PWNED").returncode == 1 and not list(work.glob("PWNED")))
        check("ocr: usage", run("ocr.sh").returncode == 64)

        # ---- gif.sh ----
        check("gif: ffmpeg missing is exit 2", run("gif.sh", str(work / "a.mp4")).returncode == 2)
        install("ffmpeg")
        clips = work / "clips dir"
        clips.mkdir()
        mp4 = clips / "firefox_2026-11-06_10-00.mp4"
        mp4.write_bytes(b"\0")
        log.write_text("")
        r = run("gif.sh", str(mp4))
        gif = clips / "firefox_2026-11-06_10-00.gif"
        check("gif: writes <name>.gif next to the video and prints the path", r.returncode == 0 and r.stdout.strip() == str(gif) and gif.is_file())
        a = lines()[0]
        check("gif: first 15 s, 12 fps, width 640, palettegen / paletteuse", "-t 15" in a and "fps=12" in a and "scale=640:-1" in a and "palettegen" in a and "paletteuse" in a)
        r = run("gif.sh", str(mp4))
        check("gif: never overwrites (-2)", r.stdout.strip() == str(clips / "firefox_2026-11-06_10-00-2.gif") and gif.read_text() == "gif\n")
        r = run("gif.sh", str(mp4))
        check("gif: then -3", r.stdout.strip().endswith("-3.gif"))
        r = run("gif.sh", str(mp4), )
        n = len(list(clips.glob("*.gif")))
        r = run("gif.sh", str(mp4), FAKE_FAIL="1")
        check("gif: an ffmpeg failure is exit 1 and leaves no partial file", r.returncode == 1 and len(list(clips.glob("*.gif"))) == n)
        check("gif: a missing input is exit 1", run("gif.sh", str(work / "nope.mp4")).returncode == 1)
        weird = clips / "a b'c; touch PWNED.mp4"
        weird.write_bytes(b"\0")
        r = run("gif.sh", str(weird))
        check("gif: a hostile name stays one argument", r.returncode == 0 and Path(r.stdout.strip()).is_file() and not list(work.glob("PWNED*")))

        # ---- colorpick.sh ----
        check("colorpick: hyprpicker missing is exit 2", run("colorpick.sh").returncode == 2)
        install("hyprpicker")
        log.write_text("")
        r = run("colorpick.sh", FAKE_COLOR="#A1B2C3")
        check("colorpick: prints the colour lowercase and runs hyprpicker -a", r.returncode == 0 and r.stdout == "#a1b2c3\n" and lines() == ["hyprpicker -a"])
        check("colorpick: a cancelled pick prints nothing, exit 1", run("colorpick.sh", FAKE_COLOR="").returncode == 1 and run("colorpick.sh", FAKE_COLOR="nonsense").stdout == "")

        # ---- the "Recording saved" toast (RecordState.savedToastCommand), run with fakes ----
        qml = (ROOT / "quickshell/RecordState.qml").read_text()
        body = qml[qml.index("function savedToastCommand"):]
        body = body[:body.index("return [")]
        script = "".join(re.findall(r"'([^']*)'", body))
        install("notify-send", "xdg-open", "ffmpeg")
        vid = clips / "rec one.mp4"
        vid.write_bytes(b"\0")

        def toast(actions):
            log.write_text("")
            (fd / "actions").write_text("".join(a + "\n" for a in actions))
            e = {"PATH": str(bin_), "HOME": str(home), "XDG_RUNTIME_DIR": str(rt), "FAKE_LOG": str(log), "FAKE_DIR": str(fd)}
            subprocess.run(["sh", "-c", script, "sh", "Recording saved", "rec one.mp4", str(vid), str(SCRIPTS / "gif.sh")], env=e, capture_output=True, text=True, timeout=30)
            return lines()

        l = toast(["default"])
        check("saved toast: Open runs xdg-open on the video", l[-1] == "xdg-open " + str(vid) and "gif=Save as GIF" in l[0])
        before = set(clips.glob("*.gif"))
        l = toast(["gif", "default"])
        new = set(clips.glob("*.gif")) - before
        check("saved toast: Save as GIF makes the gif, toasts GIF saved, Open opens it", len(new) == 1 and any("GIF saved" in x and next(iter(new)).name in x for x in l) and l[-1] == "xdg-open " + str(next(iter(new))))
        check("saved toast: no action does nothing more", len(toast([])) == 1)
        (bin_ / "ffmpeg").unlink()
        l = toast(["gif"])
        check("saved toast: no ffmpeg says so", any("GIF failed" in x and "ffmpeg is not installed" in x for x in l))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("TEST done failures=%d" % failures)
    raise SystemExit(1 if failures else 0)


main()

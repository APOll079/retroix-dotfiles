#!/usr/bin/env python3
"""Render the theme templates for one theme and reload the apps that changed.

    python3 ~/.config/quickshell/theme/apply.py dusty
    python3 ~/.config/quickshell/theme/apply.py dusty --no-reload   (write files only)
    python3 ~/.config/quickshell/theme/apply.py wallpaper --palette FILE   (palette from wallcolors.py)
    python3 ~/.config/quickshell/theme/apply.py custom --palette FILE      (palette from the theme editor: custom-theme.json)

Reads themes.json next to this file (or, with --palette FILE, the one palette in FILE, a JSON
object like an entry of themes.json; the theme name is only used for {{theme}}), fills every template in templates/ and writes the
results into $XDG_CONFIG_HOME (default ~/.config). Quickshell runs this when the theme changes
in the Themes menu and once at start; it also works from a terminal with nothing else running.
Only files whose content changed are rewritten, and only their apps are reloaded.

Placeholders: {{role}} = #rrggbb, {{role.hex}} = rrggbb, {{role.rgba}} = rrggbbaa,
{{role.rgb}} = r;g;b, {{theme}} = the theme name. Roles are the palette keys plus the
derived light/dark bevel tones and select_bar/select_text (same rules as MenuStyle.qml).
"""
import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I leaves the script's folder off sys.path
# gtkgen / icongen need Pillow: imported in their own steps, so a missing Pillow only skips those

REQUIRED = ("base", "shadow", "highlight", "accent", "text", "outline")
# Palette rules (check_palette): highlight is the bevel's light edge and must stand out from the face;
# text must be readable on every surface it sits on. fall25 is about 1.4:1 here, Win95 1.8:1.
MIN_EDGE = 1.35
MIN_TEXT = 4.5
# urgent (warnings, errors, the privacy icons) must stand out from the face as a colour, not as body text
MIN_URGENT = 3.0
RELOAD_TIMEOUT = 10  # seconds per reload command
USAGE = "usage: apply.py <theme> [--no-reload] [--palette FILE]"
# Themes that are not in themes.json: their palette is a file (state dir) the shell makes, handed over with --palette
PALETTE_THEMES = {"wallpaper": "wallpaper-theme.json (the wallpaper browser's Set + colours)", "custom": "custom-theme.json (the theme editor's Save)"}

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")

# template -> (output path, app to reload when it changed[, folder that must exist]).
# Paths are under CONFIG, or under the home folder when they start with "~/". Third item: other
# apps' files are only written when the app has its folder (an app that isn't installed gets nothing).
OUTPUTS = {
    "kitty-colors.conf": ("kitty/theme-colors.conf", "kitty"),
    "hypr-theme_colors.lua": ("hypr/theme_colors.lua", "hyprland"),
    "hyprlock-colors.conf": ("hypr/hyprlock-colors.conf", None),
    "fastfetch.jsonc": ("fastfetch/config.jsonc", None),
    "btop.theme": ("btop/themes/current.theme", None),
    "fish-colors.fish": ("fish/conf.d/theme-colors.fish", "fish"),
    "hypremoji.css": ("hypremoji/style.css", None),
    # App themes (CSS / colour files only, never a profile folder). Each is a guess at what the app
    # reads until it was tried live; see CLAUDE.md "App themes".
    "vscodium-package.json": ("~/.vscode-oss/extensions/qs.qs-retro-theme-1.0.0/package.json", None, "~/.vscode-oss/extensions"),
    "vscodium-theme.json": ("~/.vscode-oss/extensions/qs.qs-retro-theme-1.0.0/themes/qs-retro-color-theme.json", None, "~/.vscode-oss/extensions"),
    "zen.css": ("zen-qs/theme.css", None, "~/.zen"),
    # Qt apps through qt6ct (colours only, qt6ct.conf is never touched)
    "qt6ct-colors.conf": ("qt6ct/colors/qsretro.conf", None, "qt6ct"),
}


def out_path(rel):
    return os.path.expanduser(rel) if rel.startswith("~/") else os.path.join(CONFIG, rel)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def luminance(h):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h)
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def darker(h, f):
    # Qt.darker: HSV value divided by the factor
    r, g, b = (v / 255 for v in rgb(h))
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    return hexs(c * 255 for c in colorsys.hsv_to_rgb(hh, s, v / f))


def lift_highlight(base, highlight, target=1.40):
    """highlight if its step from base is already enough, else base mixed towards white until the
    step reaches target (plain white if that is as far as this base goes)."""
    if contrast(base, highlight) >= MIN_EDGE:
        return highlight
    for i in range(101):
        c = hexs(v + (255 - v) * i / 100 for v in rgb(base))
        if contrast(base, c) >= target:
            return c
    return "#ffffff"


def darken_to(colour, bg, target):
    """colour, or colour darkened (HSV value, keeps the hue) until it reaches target:1 on bg."""
    f = 1.0
    c = colour
    while contrast(c, bg) < target and f < 4.0:
        f += 0.02
        c = darker(colour, f)
    return c


def check_palette(roles, name):
    """Refuse a palette whose bevel or text can't be read, before any file is written."""
    problems = []
    edge = contrast(roles["base"], roles["highlight"])
    if edge < MIN_EDGE:
        problems.append(f"highlight is only {edge:.2f}:1 lighter than base; the bevel's light edge needs {MIN_EDGE}:1 "
                        f"(try {lift_highlight(roles['base'], roles['highlight'])})")
    if "urgent" in roles and contrast(roles["urgent"], roles["base"]) < MIN_URGENT:
        u = contrast(roles["urgent"], roles["base"])
        problems.append(f"urgent is only {u:.2f}:1 on base, it needs {MIN_URGENT}:1 (try {darken_to(roles['urgent'], roles['base'], MIN_URGENT + 0.2)})")
    for surface in ("base", "highlight", "shadow"):
        c = contrast(roles["text"], roles[surface])
        if c < MIN_TEXT:
            problems.append(f"text on {surface} is {c:.2f}:1, it needs {MIN_TEXT}:1")
    if problems:
        sys.exit(f"theme {name!r} refused, nothing written:\n  " + "\n  ".join(problems))


def derive(p, name):
    missing = [k for k in REQUIRED if not (isinstance(p.get(k), str) and re.fullmatch(r"#[0-9a-fA-F]{6}", p[k]))]
    if missing:
        sys.exit(f"theme {name!r} is missing colour(s): {', '.join(missing)} (each needs #rrggbb in themes.json)")
    roles = {k: v.lower() for k, v in p.items() if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v)}
    check_palette(roles, name)
    # MenuStyle.bevelLight = highlight (checked above to stand out from base), bevelDark = Qt.darker(shadow, 1.7)
    roles["light"] = roles["highlight"]
    roles["dark"] = darker(roles["shadow"], 1.7)
    # Two-hue screen: the terminal background is the accent's hue turned very dark, and fastfetch's
    # accent is the accent moved until it reads on that background (4.5:1)
    hh, _, ss = colorsys.rgb_to_hls(*(v / 255 for v in rgb(roles["accent"])))
    roles["term_bg"] = hexs(c * 255 for c in colorsys.hls_to_rgb(hh, 0.10, min(max(ss, 0.30), 0.60)))
    roles["term_accent"] = readable(hh * 360, max(ss, 0.45), roles["term_bg"])
    # MenuStyle.selectPair: the accent with the best of base/text/outline, else darken the accent
    acc = roles["accent"]
    best = max((roles[k] for k in ("base", "text", "outline")), key=lambda c: contrast(c, acc))
    if contrast(best, acc) >= 4.5:
        roles["select_bar"], roles["select_text"] = acc, best
    else:
        f = 1.0
        while f < 2.0 and contrast(roles["base"], darker(acc, f)) < 4.5:
            f += 0.05
        roles["select_bar"], roles["select_text"] = darker(acc, f), roles["base"]
    # Syntax colours for editor themes (VSCodium): the accent's hue turned around the wheel, each
    # moved in lightness until it reads (4.5:1) on the lightest background (highlight)
    roles.update(syntax_roles(roles))
    return roles


def readable(hue, sat, bg):
    """A colour of this hue that reads on bg: darker on light backgrounds, lighter on dark ones."""
    light_bg = luminance(bg) > 0.4
    ls = [i / 100 for i in range(45, 14, -1)] if light_bg else [i / 100 for i in range(60, 91)]
    last = None
    for l in ls:
        r, g, b = colorsys.hls_to_rgb((hue % 360) / 360, l, sat)
        last = hexs((r * 255, g * 255, b * 255))
        if contrast(last, bg) >= 4.5:
            break
    return last


def syntax_roles(roles):
    hh, _, _ = colorsys.rgb_to_hls(*(v / 255 for v in rgb(roles["accent"])))
    hue = hh * 360
    bg = roles["highlight"]
    out = {}
    for name, off in (("keyword", 0), ("string", 120), ("number", 60), ("function", 200), ("type", -60)):
        out["syn_" + name] = readable(hue + off, 0.55, bg)
    # Comments: the text colour pulled towards the base until it is just readable
    t, b = rgb(roles["text"]), rgb(roles["base"])
    comment = roles["text"]
    for i in range(0, 101, 5):
        c = hexs(t[k] * (1 - i / 100) + b[k] * (i / 100) for k in range(3))
        if contrast(c, bg) < 4.5:
            break
        comment = c
    out["syn_comment"] = comment
    # Qt links sit on the window colour (base), not on highlight: 4.5:1 against base
    out["syn_link"] = readable(hue + 200, 0.55, roles["base"])
    out["syn_visited"] = readable(hue - 60, 0.55, roles["base"])
    return out


def render(text, roles, name):
    def sub(m):
        key, fmt = m.group(1), m.group(2)
        if key == "theme":
            return name
        if key not in roles:
            raise KeyError(f"unknown placeholder {{{{{m.group(0)[2:-2]}}}}}")
        h = roles[key]
        return {None: h, "hex": h[1:], "rgba": h[1:] + "ff", "rgb": ";".join(map(str, rgb(h)))}[fmt]
    return re.sub(r"\{\{(\w+)(?:\.(hex|rgba|rgb))?\}\}", sub, text)


def run(cmd, **kw):
    """Run a reload command; never hang or crash the theme switch."""
    try:
        return subprocess.run(cmd, timeout=RELOAD_TIMEOUT, **kw).returncode
    except (OSError, subprocess.TimeoutExpired):
        return -1


def reload(app, path):
    if app == "kitty":
        if run(["pkill", "-USR1", "-x", "kitty"]) == 0:
            return "kitty reloaded (SIGUSR1)"
        return "kitty not running"
    if app == "hyprland":
        if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") and shutil.which("hyprctl"):
            run(["hyprctl", "reload"], stdout=subprocess.DEVNULL)
            return "hyprctl reload"
        return "Hyprland not running"
    if app == "fish":
        if shutil.which("fish"):
            # Universal variables: running shells pick them up right away
            run(["fish", "--no-config", path])
            return "fish universal colours set"
        return "fish not installed"
    return None


def write(path, text):
    """Atomic write through a unique temp file in the same folder (two runs at once can't clash)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix="." + os.path.basename(path) + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise


def main():
    argv = sys.argv[1:]
    if any(a in ("-h", "--help") for a in argv):
        print(__doc__.strip())
        print("\n" + USAGE)
        return
    palette_file = None
    if "--palette" in argv:
        i = argv.index("--palette")
        if i + 1 >= len(argv):
            sys.exit(USAGE)
        palette_file = argv[i + 1]
        del argv[i:i + 2]
    flags = [a for a in argv if a.startswith("-")]
    unknown = [a for a in flags if a != "--no-reload"]
    if unknown:
        sys.exit(f"unknown option {unknown[0]}\n{USAGE}")
    args = [a for a in argv if not a.startswith("-")]
    no_reload = "--no-reload" in flags
    if len(args) != 1:
        sys.exit(USAGE)
    name = args[0]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
        sys.exit(f"bad theme name {name!r}: only letters, digits, - and _ are allowed")
    if palette_file:
        try:
            with open(palette_file, encoding="utf-8") as f:
                themes = {name: json.load(f)}
        except (OSError, ValueError) as e:
            sys.exit(f"palette {palette_file}: {e}")
        if not isinstance(themes[name], dict):
            sys.exit(f"palette {palette_file}: expected a JSON object")
    else:
        with open(os.path.join(HERE, "themes.json"), encoding="utf-8") as f:
            themes = json.load(f)
    if name not in themes:
        if name in PALETTE_THEMES:
            sys.exit(f"theme {name!r} has no palette in themes.json: give it its file, {PALETTE_THEMES[name]}, with --palette FILE")
        sys.exit(f"unknown theme {name!r}; known: {', '.join(themes)}")
    roles = derive(themes[name], name)

    # Render everything first: a broken template stops the run before any file is touched,
    # so apps are never left half on the old theme and half on the new one
    rendered = []
    for tpl, (rel, app, *rest) in OUTPUTS.items():
        try:
            with open(os.path.join(HERE, "templates", tpl), encoding="utf-8") as f:
                out = render(f.read(), roles, name)
        except (OSError, KeyError) as e:
            sys.exit(f"template {tpl}: {e}")
        needs = rest[0] if rest else None
        rendered.append((out_path(rel), out, app, needs))

    print(f"theme {name}")
    for path, out, app, needs in rendered:
        if needs and not os.path.isdir(out_path(needs)):
            print(f"  skipped    {path} ({needs} not found)")
            continue
        try:
            with open(path, encoding="utf-8") as f:
                same = f.read() == out
        except (FileNotFoundError, UnicodeDecodeError):
            same = False
        if same:
            print(f"  unchanged  {path}")
            continue
        write(path, out)
        print(f"  wrote      {path}")
        msg = None if no_reload else reload(app, path)
        if msg:
            print(f"  reload     {msg}")
    theme_changed = gtk_theme(roles, no_reload)
    icons_changed = icon_theme(roles)
    border_image(roles)
    if (theme_changed or icons_changed) and not no_reload:
        reload_gtk(theme_changed, icons_changed)


def gtk_theme(roles, no_reload):
    """The recoloured GTK theme (gtkgen.py): a new QsRetro folder next to the installed original."""
    try:
        import gtkgen
    except ImportError as e:
        print(f"  skipped    gtk theme ({e})")
        return 0
    themes = os.path.expanduser("~/.local/share/themes")
    src = os.path.join(themes, gtkgen.SOURCE)
    dst = os.path.join(themes, gtkgen.NAME)
    if not os.path.isdir(src):
        print(f"  skipped    {dst} ({gtkgen.SOURCE} not installed)")
        return 0
    try:
        changed = gtkgen.generate(roles, src, dst)
    except Exception as e:  # a broken GTK step must never fail the whole theme switch
        print(f"  gtk theme failed: {type(e).__name__}: {e}", file=sys.stderr)
        return 0
    print(f"  {'wrote' if changed else 'unchanged'}     {dst}" + (f" ({changed} files)" if changed else ""))
    # libadwaita / GTK 4 apps read ~/.config/gtk-4.0 itself: keep its links on the generated theme,
    # but only replace a link that points into one of the two themes (never a real file of yours)
    for name in ("gtk.css", "assets"):
        link = os.path.join(CONFIG, "gtk-4.0", name)
        want = os.path.join(dst, "gtk-4.0", name)
        if os.path.islink(link):
            old = os.readlink(link)
            if old == want or not any(os.sep + t + os.sep in old for t in (gtkgen.SOURCE, gtkgen.NAME)):
                continue
            os.remove(link)
        elif os.path.lexists(link):
            continue
        os.makedirs(os.path.dirname(link), exist_ok=True)
        os.symlink(want, link)
        print(f"  linked     {link}")
    return changed


def border_image(roles):
    """hypr/win95-border.png: the 3 px Win95 window bevel as a 9-slice image for the imgborders plugin (outer
    ring light / outline, inner ring light / dark, face). Needs Pillow; skipped without it or when the hypr
    folder isn't there. Returns True when the file changed."""
    try:
        from PIL import Image
    except ImportError:
        print("  skipped    hypr/win95-border.png (Pillow not installed)")
        return False
    dest = out_path("hypr/win95-border.png")
    if not os.path.isdir(os.path.dirname(dest)):
        return False
    inner = hexs(c * 0.5 + d * 0.5 for c, d in zip(rgb(roles["base"]), rgb(roles["highlight"])))
    # ring 0 (outside), 1, 2 (next to the window): top-left colours, bottom-right colours
    tl = [roles["highlight"], inner, roles["base"]]
    br = [roles["outline"], roles["dark"], roles["base"]]
    size = 7
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for ring in range(3):
        lo, hi = ring, size - 1 - ring
        for i in range(lo, hi + 1):
            img.putpixel((i, lo), rgb(tl[ring]) + (255,))   # top
            img.putpixel((lo, i), rgb(tl[ring]) + (255,))   # left
        for i in range(lo, hi + 1):
            img.putpixel((i, hi), rgb(br[ring]) + (255,))   # bottom
            img.putpixel((hi, i), rgb(br[ring]) + (255,))   # right
    import io
    buf = io.BytesIO()
    img.save(buf, "PNG")
    data = buf.getvalue()
    try:
        with open(dest, "rb") as f:
            if f.read() == data:
                print(f"  unchanged  {dest}")
                return False
    except FileNotFoundError:
        pass
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(data)
    print(f"  wrote      {dest}")
    return True


def icon_theme(roles):
    """The hue-shifted icon theme (icongen.py): a new QsRetroIcons folder next to RetroismIcons."""
    try:
        import icongen
    except ImportError as e:
        print(f"  skipped    icon theme ({e})")
        return 0
    icons = os.path.expanduser("~/.local/share/icons")
    src = os.path.join(icons, icongen.SOURCE)
    dst = os.path.join(icons, icongen.NAME)
    if not os.path.isdir(src):
        print(f"  skipped    {dst} ({icongen.SOURCE} not installed in ~/.local/share/icons)")
        return 0
    try:
        changed = icongen.generate(roles, src, dst)
    except Exception as e:  # never fail the whole theme switch over icons
        print(f"  icon theme failed: {type(e).__name__}: {e}", file=sys.stderr)
        return 0
    print(f"  {'wrote' if changed else 'unchanged'}     {dst}" + (f" ({changed} entries)" if changed else ""))
    return changed


def reload_gtk(theme_changed, icons_changed):
    """Running GTK apps only re-read a theme when its name changes: flip it away and back."""
    gs = shutil.which("gsettings")
    if not gs or not (theme_changed or icons_changed):
        return
    try:
        import gtkgen
        import icongen
    except ImportError:
        return
    for key, name, away, changed in (("gtk-theme", gtkgen.NAME, "Adwaita", theme_changed),
                                      ("icon-theme", icongen.NAME, "hicolor", icons_changed)):
        if changed:
            flip(gs, key, name, away)


def flip(gs, key, name, away):
    try:
        cur = subprocess.run([gs, "get", "org.gnome.desktop.interface", key], capture_output=True, text=True, timeout=RELOAD_TIMEOUT).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return
    if cur != f"'{name}'":
        return
    run([gs, "set", "org.gnome.desktop.interface", key, away])
    time.sleep(0.4)
    run([gs, "set", "org.gnome.desktop.interface", key, name])
    print(f"  reload     {key} (gsettings flip)")


if __name__ == "__main__":
    main()

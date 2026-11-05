# Design: inspiration and ideas

Every design idea in one place: the Design section from both idea lists, plus what's worth taking from three other retro rices, plus fixes from your current bar screenshot. All Claude's suggestions, nothing planned until it moves to FEATURES.md. ★ = starred in your idea lists.

Source column: **list** = from your idea lists, **fall25** / **hkrist** / **jef** = the rices below, **bar** = from your grey + teal bar screenshot.

## Do these first

These fix most of what looks ugly today, in this order:

1. Real bevels (A1 + A2): visible light edge and two rings, not black outlines.
2. One tray well on the bar (B1): replaces about eleven boxes.
3. Accent only where it means something (A3).
4. Centre title in Monaco (B4).

Render each one with the retro-design skill, compare against the fall25 and hkrist screenshots, then do the rest.

## Why yours looks busy and theirs don't

- **Outlines instead of bevels.** Your buttons have a black 1 px ring and no white edge, so they look like boxes drawn around text. In cherry, `highlight` (#f9d0f7) is barely lighter than `base` (#f4c9ef), so the light edge disappears there too. Win95 uses face #c0c0c0, white, #808080 and black; fall25 uses #dcdad5, white, #9e9a91 and black. Both have a big step from the face to the light edge.
- **Too many frames.** Your bar has about eleven boxes plus loose icons between them. hkrist's right side is only text labels, thin etched lines and one sunken clock box.
- **The accent is everywhere.** fall25 uses its accent in three places only: title bars, the selected row and the Start menu stripe.
- **Few colours.** hkrist's whole screen is Win95 grey plus teal: wallpaper, dark-teal terminal background and fastfetch keys all share one hue. Your grey + teal theme is already halfway there.
- **One font.** fall25 is Terminus everywhere. You have the Monaco 12/16 rule, but the centre title is a light-grey sans font, and Charcoal (Mac Platinum) sits next to Win95 bevels. Decide whether the mix is on purpose.

## A. Foundations: colours, bevels, sizes, rules

| | Idea | Size | Source |
|---|---|---|---|
| | **A1. Bevel and text contrast check**: `highlight` close to white in every theme, and `apply.py` refuses a palette where the face-to-highlight step is too small or text on any surface is under 4.5:1 | S | fall25, list |
| | **A2. Two-ring bevel on buttons**: `BarButton` and `BevelButton` use `thickness: 1` today; real Win95 buttons have white + black outside and light + dark grey inside | S | fall25 |
| | **A3. Accent only for title bars, the selection and "on"**: everything else uses the face colour. Today the accent is on fills, frames, sliders, tabs and titles | M | fall25 |
| ★ | **A4. Embossed disabled text**: greyed-out labels with the Win95 white offset under them, instead of only lower opacity | S | list |
| | **A5. Spacing scale**: name the steps (2, 4, 6, 8, 12) in MenuStyle and use only those; the check script flags any other number | S | list |
| | **A6. Two icon sizes only**: 16 in rows and menus, 20 on the bar and big buttons | S | list |
| | **A7. Fixed-width numbers, sized to fit**: every % and time label gets a fixed width so nothing shifts while it ticks, but sized to the widest real value. The CPU box today has about 30 px of nothing after "RAM 30%" | S | list, bar |
| | **A8. Motion tokens**: two durations only (fast for hover, normal for open) and one easing, named in MenuStyle, plus one Reduce motion setting that turns every animation off | S | list |
| | **A9. Whole-pixel layout**: no fractional positions (they blur the 1 px bevels); check.py can flag `/ 2` without rounding | S | list |
| | **A10. Standard window sizes**: S / M / L for windows like the menu widths, so Games, Wallpapers, History, Task Manager share sizes | S | list |
| | **A11. Fallback fonts**: Monaco has no Hangul / CJK; name a fallback (e.g. Noto Sans CJK) for lyrics and notifications so they don't fall to a random font | S | list |
| | **A12. One icon decision**: Material Symbols in the shell vs the pixel RetroismIcons in GTK. Either use RetroismIcons (16 / 32 px) in menus too, which looks more authentic, or keep Material everywhere and make the GTK icons match | M | list |
| | **A13. Two-hue screens**: the terminal background (a dark version of the accent) and the fastfetch accent follow the theme, so the screen has one hue plus the grey. `apply.py` already themes kitty and fastfetch | S | hkrist |
| | **A14. DESIGN.md generated from MenuStyle**: a script writes the table of sizes, fonts and colours so the doc can't drift; check.py fails if it's stale | S | list |

## B. The bar

| | Idea | Size | Source |
|---|---|---|---|
| | **B1. One sunken tray well**: CPU text, ETH, Bluetooth, the tray icons and weather / clock sit in one sunken box at the right, separated by etched lines (1 px dark + 1 px light), with no box per item and no `\|` characters. Short text labels ("CPU 2%"), tray icons loose inside the well, and optionally the clock in its own small sunken box in bold | M | fall25, hkrist, bar |
| | **B2. Start stays pressed while its menu is open**: `taskbar.toggleMenu` already knows when a menu is open | S | fall25 |
| | **B3. Fewer separators and grippers**: one gripper at most, and etched separators only between real groups | S | bar |
| | **B4. Centre title in Monaco 12, normal text colour**: it's the only sans, light-grey text on the bar today | S | bar |

## C. Windows and frames

| | Idea | Size | Source |
|---|---|---|---|
| ★ | **C1. Win95 frames on app windows**: `hyprbars` title bars with minimise / maximise / close in the theme colours, left-aligned title text, grey title bars on unfocused windows. For the frame, either the `imgborders` plugin with a 3 px bevel image recoloured by `apply.py` (check it works on 0.56; it needed hyprland-git) or, without a plugin, a 2 px grey border plus a hard dark shadow at the bottom right, like hkrist's terminal | M | list, fall25, hkrist, jef |
| | **C2. Title bars in the shell**: every window and popup title bar has its icon + name, left-aligned like Win95 (your side panel's "Home" is centred) | S | list, fall25 |
| ★ | **C3. One dialog template**: title bar, message, buttons right-aligned, the default button with the thick Win95 border, Enter = default, Esc = Cancel. Every confirm (power, End task, Forget, Clear all, Uninstall) uses it, instead of each one rolling its own | M | list |
| ★ | **C4. Win95 scrollbars**: one scrollbar component (arrow buttons, a bevelled thumb, a dithered track) for every list, instead of hidden or default ones | M | list |
| | **C5. Status bars on every big window**: Task Manager, Games, Wallpapers, Services, screenshot History get the same bottom status bar as the Spotify drawer (counts, hints, errors) | S | list |
| | **C6. Menu bars on big windows**: File / View / Help on Task Manager, Games, Wallpapers | M | list |
| | **C7. Settings window (Control Panel)**: a Win95 Control Panel for what's in settings.json today (idle timings, notification position, EQ presets, weather place, dither, wallpaper folder), instead of editing JSON by hand; typing "idle" or "notification position" in the launcher jumps to that setting | L | list |

## D. Menus, launcher and side panel

| | Idea | Size | Source |
|---|---|---|---|
| ★ | **D1. One right-click menu component**: every context menu (tray, Spotify rows, launcher options, history) looks and behaves the same | M | list |
| | **D2. Icon column in menus**: every menu row has a fixed-width icon slot, so labels line up | S | list |
| | **D3. Accent stripe on the Start menu and launcher**: a 24 px vertical accent stripe down the left side, the Win95 "Windows 95" banner, with "Retroix" or the theme name written up it | S | fall25 |
| | **D4. Launcher as a real window**: raised outer frame, sunken search field, sunken list well | S | jef |
| | **D5. Greyscale or tinted app icons (optional)**: colourful app icons are what breaks the palette most in a retro menu | S | jef |
| ★ | **D6. Side panel tabs as real tabs**: Home / Calendar / Phone look like buttons; use the same Win95 tab component as the Spotify drawer | S | list |
| ★ | **D7. Group boxes**: the side panel's Output / Microphone / Applications become Win95 group boxes (a thin etched frame with the label set into its top edge) instead of loose headings | S | list |
| | **D8. Win95 trackbar sliders**: a thin sunken groove with a raised thumb, no pink fill. The filled sliders are the most modern-looking thing in the side panel | S | Win95 |
| | **D9. Microphone row**: "AT2020 USB · Analog Stereo" as one label, not two columns with a gap | S | list |
| | **D10. Empty states**: one pattern everywhere: a dim icon + one line ("No notifications", "No drives") | S | list |
| | **D11. Notification well**: with only a few entries, end the list with a quiet "No older notifications" line instead of a tall empty well | S | list |
| | **D12. Balloon toasts**: an optional Win95 balloon-tip style for toasts, pointing at the tray | M | list |
| | **D13. Keyboard accelerators**: underlined letters in menus (Alt + letter), like real Win95 menus. Low value if you mostly use the mouse | M | list |
| | **D14. Tab order**: Tab / Shift+Tab move through every control in every window, with the dotted focus rect. Same caveat | M | list |

"Improve the side panel" stays in `ideas-starred.md` (section 8). D6, D7, D8, D9 and D11 are the design half of that pass.

## E. Wallpaper and terminal

| | Idea | Size | Source |
|---|---|---|---|
| | **E1. Grain over flat-colour wallpapers**: one dither or noise layer so a plain colour doesn't look dead; you already have `Dither.qml` | S | hkrist |
| | **E2. Classic terminal colours**: black or dark-hue background with the 16 VGA / Win16 colours, as fall25 and hkrist do (fits with A13) | S | fall25, hkrist |

## F. Keeping it consistent

| | Idea | Size | Source |
|---|---|---|---|
| ★ | **F1. Component gallery** (`gallery.qml`): every component in every state (normal, hover, pressed, on, disabled, focused) in cherry and dusty on one page; Claude Code renders it before and after UI work. The visual reference and the screenshot baseline | M | list |
| | **F2. Interaction tests**: offscreen click tests for the behaviour contract (right-click removes, second click closes, Esc closes), run by check.py | M | list |

## The three rices

| Source | What it is | Licence |
|---|---|---|
| **fall25** by cd3y (the zip, and the r/unixporn "Fall25" post) | Hyprland + Waybar + rofi + dunst, GTK Raleigh, Terminus, slate-blue accent | CC0: copy freely |
| **jefrecantuledesma/dotfiles** | Sway + Waybar + wofi, Chicago95 icons, navy title bars | GPL-3: ideas only, don't paste code into an MIT repo |
| **hkrist/dotfiles** | Hyprland (Lua config, like yours) + Waybar + wofi, Win95 grey, teal Tux wallpaper | No licence: ideas only. Keep the wallpaper out of your public repo |

**fall25**: bar at the bottom, 28 px, face #dcdad5 with a white line on top. Start button with a 16 px Tux and bold "Start", pressed while the menu is open. Workspaces as small raised buttons, the active one pressed. Etched separators between groups. Tray, layout, volume and clock in one sunken box. Start menu 240 px wide with a 24 px accent stripe, 24 px icons, accent-filled selection, "Search:" prompt. Windows get a 3 px bevel from `imgborders` and 24 px accent hyprbars title bars on floating windows, grey when inactive. Gaps 4/8, no rounding, shadow or animations. dunst bottom right, 280 px, 2 px frame, bold title. Matching GTK, icons, cursor, Firefox and Wine themes. A welcome dialog on first login. Black terminal with VGA colours.

**jef**: every window has a title bar, focused navy #000080 with white text, unfocused #c0c0c0 with black text. Bar #c0c0c0 where every module is its own raised button (the busy look to avoid). wofi launcher as a raised window with a sunken search field and list, greyscale icons, "Run..." prompt, top left. Plain #008080 wallpaper. PipeWire EQ files per headphone.

**hkrist**: bar at the top, 24 px, #c0c0c0, classic CSS bevel (`#fff #808080 #808080 #fff`). Start raised, active workspace sunken, tray in a sunken box. Right side: short text labels separated by etched lines, the clock bold in its own sunken box. Teal wallpaper with a white Tux and grain. Whole screen in two hues. The terminal looks like a raised window from a 2 px grey border plus a hard shadow. The config says rounding 10, but the screenshot corners look square. Uses blur, which isn't worth copying.

## Notes from the desktop-overhaul audit

Visual inconsistencies the audit found in code (check with a screenshot first): Theme menu cards and the screenshot toolbar are hand-rolled, raw TextFields in the Games form and the Phone tab, screenshot History sized by screen fraction, the bar's now-playing text has no hover.

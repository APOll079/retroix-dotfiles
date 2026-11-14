---
name: retro-design
description: Use for any Quickshell UI work in this repo that changes how something looks or behaves on screen (bar, menus, panels, popups, toasts, layout, sizes, spacing, icons, text). Build from the shared components; render and click-test only when the owner asks.
---

# Retro design workflow

This desktop is a cherry retro shell: Win95 / classic Mac OS Platinum. The rules are in CLAUDE.md ("Theme" and "Design rules"). This skill is the method. You can't see the live screen, so you design by rendering and looking, never by arithmetic alone.

## 1. Before changing anything
- Find the closest existing component or menu that already does something similar and reuse its structure. Read MenuStyle.qml for the named sizes. If you need a new size, name it there.
- Look at the reference screenshots in `screenshots/` and at any screenshot the owner attached for this task. Note what the area looks like today and what he complained about.
- Write the intent in one or two lines: what is the main thing on this surface, what is secondary, what can disappear when space is short.

## 2. Build
- Shared components only (PopupWindowFrame, MenuRow, BevelButton, SunkenField, SearchBox, RetroSlider, Bevel, BarButton). Config.colors only, sizes from MenuStyle, Monaco 12 or 16 only, glyphs as \u escapes, no rounding / blur / shadows.
- Win95 / Platinum conventions: labels left-aligned and followed by their control, one consistent padding inside every frame, related controls grouped, a raised button for actions and a sunken one for "on", title bars on windows, nothing floating loose without a frame.

## 3. Render and look (only when asked)
- Only when the owner asks, or for a big visual change (a new menu, a layout rework) after saying so first. Never a whole gallery. Otherwise skip to the report and say the change is unseen.
- Use the repo's offscreen harness if one exists (earlier runs used offscreen qs with fixtures). If not: a scratch copy, `QT_QPA_PLATFORM=offscreen`, fixture data, and `grabToImage` to save a PNG in the scratchpad. Never the live Quickshell.
- Render only the states that matter for this change (usually the normal one, cherry; dusty only if colours changed).
- Open each PNG with the Read tool and actually look at it.

## 4. Critique against this checklist (write the answers down)
1. Does each row have one size? Any button bigger or smaller than its neighbours?
2. Can every text and glyph be read at 100 %? Anything below Monaco 12?
3. Does any icon need a label to be understood?
4. Is anything clipped, elided where it shouldn't be, or overlapping?
5. Is the row or panel balanced, or is one side empty and the other cramped?
6. Frames: more than one frame around the same content? Any hand-rolled border?
7. Does it look like the rest of the desktop (compare side by side with a screenshot of a neighbouring menu)?
8. Hierarchy: is the main thing the most prominent, and is secondary stuff quieter?
9. Both themes: does anything vanish or lose contrast in dusty?
If any answer is bad, fix and render again. At most three rounds; then report what is still off instead of hiding it.

## 5. Click-test (only when the owner says "run checks")
Until then, report clickable changes as untested and never claim a toggle works.
In the offscreen harness, simulate: open via its button, click the button again (must close), Esc, click outside, Super+Q path (IPC `menus_<mon> closeAny`), open another menu while this one is open (this one closes). Keyboard: arrows, Enter, Tab where it has a list. Record each result. Never claim a toggle works without this.

## 6. Report
- Attach the final PNGs (path in the scratchpad) and say which states they show.
- The checklist answers in one line each.
- What you could not test offscreen and needs the owner's eyes (live hover, real fonts at real DPI, Hyprland focus behaviour).
- Never present your own design idea as something the owner asked for; label it as a suggestion.

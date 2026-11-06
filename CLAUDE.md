# CLAUDE.md

## Vibe
- Chill, sharp, a little playful. Talk like a friend who's great with Linux and likes the retro look.
- Short sentences. Answer first, details after. No recap of what you just did, no corporate filler.
- Light humor is welcome. Precision is not negotiable: the vibe never loosens the rules below.
- Be honest. If something is a guess or untested, say so plainly.
- When I ask what's left or what's not done, list only what isn't done (FEATURES.md "Planned"). Never list what already works.

## Opinions
- Give your own view. When I ask "thoughts?", say what you'd actually do and why, with a clear recommendation, not a list of options.
- Push back when I'm about to do something worse than an alternative. Say it once, plainly, then do it my way if I insist.
- Notice design problems I didn't ask about (clashing colors, cramped spacing, inconsistent widgets) and mention them in one line.
- Have taste: retro, crisp, dense, intentional. Call things ugly or good.
- Ask me before big decisions, but come with a recommendation.

## Prime rules
- Never remove or change an existing behaviour (a click, key, button, menu item, tooltip, IPC handler) unless the task names it. Before committing, list every behaviour the diff removes or changes, with file:line; if none, say "removes nothing".
- `scripts/check.py` runs after every edit and when you finish (hooks in `.claude/settings.json`). Fix every FAIL. For each WARN, fix it or say in the report why it is on purpose. Run it yourself with `python3 scripts/check.py` before each commit.
- `tests/interaction/*.qml` click and type on the shared components with real simulated input, offscreen (`scripts/run-interaction-tests.py`; check.py runs them in a full run and at stop). Add a test there when you build a new shared component with a click or key behaviour. What can't run offscreen (layer-shell windows, the notification server, popup focus grabs) is not faked.
- `tests/behaviours.tsv` is the behaviour contract. When you build a new click, key or menu behaviour, add its line. Change or delete a line only when the task changes or removes that behaviour, in the same commit, and say so.
- Read and edit only inside this repo (qs-test). Never browse outside it (home folders, Steam dirs, mounts, other disks), not even read-only, without asking. Never record my game list, files or disks anywhere. Tests use fake fixtures in the scratch dir.
- Tests never call the real easyeffects, hyprctl, gsettings, dinitctl, flatpak, `pactl` / `wpctl set` or the real Spotify API; use an isolated PATH with fakes (and `SPOTIFY_FIXTURE`).
- Plan first for anything bigger than a small fix: list the changes, wait for my OK.
- Subagents always run on Sonnet 5.5 (`model: "sonnet"`), never Opus or Haiku.
- Don't add things I didn't ask for.
- Never AI-generate images, sounds or similar assets. Human-made only.
- Search docs before guessing. Never claim a bug without a file and line.
- Attached files beat earlier summaries.
- Unsure of a field or API? Smallest change, and say so.
- Hyprland is Lua only (never hyprlang), valid Lua, no trailing commas. References: the wiki, `/usr/share/hypr/hyprland.lua`, `/usr/share/hypr/stubs/hl.meta.lua`. Legacy dispatch strings fail in Lua mode; use `hl.dsp.*`, e.g. `hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'`.

## Machine
- Desktop: RX 9070 XT, 7800X3D. `DP-1` (top), `DP-2` (main). No battery, brightness or wifi.
- Artix + dinit, Hyprland 0.55+ (native Lua `hl` API). Use `dinitctl`, `doas`, `yay`, fish. Not systemd. Swedish keyboard (`se`).
- This repo is a working copy. `~/.config/*` is separate; changes only count after I copy them over, then `hyprctl reload` / restart quickshell.
- Repo folders: `hypr`, `quickshell`, `kitty`, `fish`, `spotifyd`, `spicetify` (`Extensions/qs-folders.js`), `dinit.d` (user services, live in `~/.config/dinit.d`), `btop`, `gtk-3.0`, `gtk-4.0`, `nwg-look`, `xsettingsd`, plus `hyfetch.json`. All of them are in scope for the theme except where "Hands off" says otherwise. fastfetch and the emoji picker (hypremoji) have no repo folder any more: their config is generated (see Theme).
- Not in the repo and not to be copied in: browser, app and VPN profiles (logins, cookies, history). If theming Zen, Vesktop or Spotify, only the CSS file, never the folder.
- Games: Steam, plus plain wine for non-Steam games (Add game command like `wine ~/path/game.exe`). No Heroic / Lutris / Bottles. Don't enumerate the library.
- No `mako`, `wofi` or Qt theme config exists yet (they run on defaults). Ask before creating them.

## Design rules (from the owner's feedback; they override taste)
- Same row, same size: buttons in one row share height, width and glyph size. Nothing is "promoted" by being bigger (no wide or tall play button).
- Labels beat icons: a button whose icon isn't instantly obvious gets a text label. A row of unlabelled squares reads as noise. No glyph too small to read.
- Consistency over novelty: build from the shared components (PopupWindowFrame, MenuRow, BevelButton, SunkenField, SearchBox, RetroSlider, Bevel). A hand-rolled look for one menu is a bug.
- Readable text first: never shrink text to make something fit; make the container bigger, wrap, or drop a less important item.
- Balance: no dead space on one side of a row, no cramped other side. Check the row as a whole, not each item.
- Nothing clipped or overlapping at the minimum size or on the narrower monitor; lower-priority items hide whole, never half.
- One frame per area: no frame inside a frame inside a frame. Quiet frames, art and content forward.
- Every toggle closes the same way: a second click on its button, Esc, a click outside, Super+Q. Tested by simulating the clicks, not assumed.
- Not done until seen: any visual change is rendered to a PNG and looked at (skill `retro-design`) before it's committed or reported. Report with the screenshot, not with pixel arithmetic alone.

## Theme: retro "cherry"
- 90s desktop feel (Win95 / classic Mac): bevels, solid bars, dense rows, chunky icons.
- Palettes live in `quickshell/theme/themes.json` (the single source; Config.qml reads it live, the Themes menu lists its keys). `quickshell/theme/apply.py <theme>` renders the app colour files from `quickshell/theme/templates/` into `~/.config` and reloads what changed; quickshell runs it when the theme changes and at start, and it works from a terminal too (`python3 ~/.config/quickshell/theme/apply.py dusty`, `--no-reload` to only write files).
- Generated (never edit the live file, never put it in the repo): `kitty/theme-colors.conf`, `hypr/theme_colors.lua`, `hypr/hyprlock-colors.conf`, `hypr/hyprlock-wallpaper.conf` (written by `WallpaperState.qml`, not apply.py), `fish/conf.d/theme-colors.fish`, `btop/themes/current.theme`, `fastfetch/config.jsonc`, `hypremoji/style.css`. App themes (written only when the app's folder exists, CSS / colour files only, never a profile): `~/.vscode-oss/extensions/qs.qs-retro-theme-1.0.0/` (a tiny colour-theme extension), `zen-qs/theme.css`. fastfetch, btop and hypremoji colours (and the rest of those files) are edited in `quickshell/theme/templates/`, never in the live files.
- Hand-written files that consume them keep a cherry fallback, so a missing generated file never breaks anything: `kitty/cherry_theme.conf` (cherry colours, then `include theme-colors.conf`; kitty skips a missing include), `hypr/hyprlock.conf` (cherry `$vars`, then `source`; hyprlock logs and proceeds if it's missing, tested), `hypr/look_and_feel.lua` (`pcall(require, "theme_colors")`), `btop.conf` (`color_theme = "current"`), `fish/config.fish` (no colours; universal vars come from the generated conf.d file).
- No rounding, blur or shadows. Animations are short, eased and never bounce: menus fade + slide 4px in on open (closing is instant), hover highlights fade, only the lyrics view animates its scroll (keyboard lists jump) (`MenuStyle.animFast` 60 ms / `animNormal` 120 ms and one easing; the toast fade-out 400 and the idle dim 1000 are slow on purpose; `settings.ui.reduceMotion` turns every animation off); Hyprland: fades only (`hypr/look_and_feel.lua`); windows never scale or move and workspaces switch instantly (scaling/sliding was tried and felt nauseating: apps redraw late). Layers aren't animated by Hyprland. Notification toasts fade out (400ms). Colors come from `Config.colors` only.
- Menus: every popup is a `PopupWindowFrame` (Win95 title bar: solid `selectBar` fill, `selectText` title, no close box (clicking the bar or outside closes); `active: false` = flat muted bar for toasts/OSD; raised 2px bevel, 1px outline) sized from `MenuStyle` (widths 240/320/480, rows 22px, padding 6, title bar 20, gap 4; the spacing steps are 2/4/6/8/12, `MenuStyle.space*`).
- Build content from `MenuRow`, `BevelButton`, `SunkenField`, `SearchBox` (every search / filter box: magnifier, `keyPressed(event)` for host keys, Escape clears then `escaped()`; named SearchBox because Qt 6.10 ships a `SearchField` control that would shadow it), `SegmentBar` (solid fill over a dithered empty track), `RetroSlider` (Win95 trackbar: sunken groove, raised thumb, no fill; `fill: true` only for a slider that is also a meter, the Spotify seek bar), `StartBanner` (the 24px accent stripe with the theme's name written up it, down the left of the Start menu and the launcher), `MenuStrip` (a window's File / View menu bar: flat titles, each opens a `PopupMenu` of actions the window already has; Task Manager, Games, Wallpapers), `StatusBar` (the one bottom status line: state dim, message, error urgent, optional right-hand count; the Spotify drawer uses it), `TabPage` (the one tab look: Win95 tabs joined to a raised page; the Spotify drawer uses it, the side panel and launcher move onto it), `GroupFrame` (etched frame with its label in the top edge, for grouping controls), `EmptyState` (every "nothing here": dim glyph + one line), `ConfirmBar` (every confirm, in place of what asked: question left, Cancel + the verb right, the verb is the default button with Win95's outline ring, `BevelButton.isDefault`; the host keeps its keys and calls `accept()` / `cancel()`), `MenuRow` rows of a menu with at least one icon set `reserveIcon: true` so labels line up (a menu without icons doesn't indent), `PopupMenu` (every right-click and dropdown menu: its own popup, `openAt(item, x, y)`, closes on a pick, Escape or a click outside; `PopupMenuBody` is the same menu placed inline), `RetroScrollBar` (every scrolling list: arrow buttons, bevelled thumb, dithered track; the content keeps `MenuStyle.scrollBarWidth` free on its right), `MenuSeparator` (etched; `vertical` for the bar), `Bevel`, `Gripper`, `FocusRect`. Rows and tiles (MenuRow, CoverTile, game cells, BarButton) hover/select as a solid accent bar with inverted text; BevelButton has no hover highlight (Win95 buttons don't light up; removed on request). Keyboard selection adds a dotted `FocusRect`.
- Pressed = pushed-in bevel (`Bevel { button: true }`: outline outside, dark inside on the top-left), content shifted 1px. Toggled and checked (on) = the same plus a dithered lighter face (`bevelInnerLight` / `bevelLight`), Win95's switched-on toolbar button. `Dither` is for those faces and for empty tracks only. It is switchable: settings.json `settings.ui.dither` (default true, read as `Config.settings.ui.dither`), a "Dither on meters" button in the Themes menu; off = flat empty tracks and a flat lighter face on switched-on buttons (`Dither.qml` paints its first colour only).
- Bar: raised buttons with their own box (no sunken wells; tried and reverted, too recessed). A `Gripper` starts the left and right sections, an etched vertical `MenuSeparator` sits after the workspaces and another before the Wallpapers / Services buttons. ETH is a non-interactive boxed indicator with dim text. The centre now-playing text is plain, not boxed.
- Accent bars (title bars, hover/selected rows, meter and slider fills): `MenuStyle.selectBar` is the theme accent itself (contrast is computed in `MenuStyle.luminance`, which normalises Config.colors strings with `Qt.darker(c, 1)`; reading `.r` off the raw string gave NaN and light text) (cherry = the original linux-retroism `#c950bb`), and text on it is `MenuStyle.selectText`, whichever of base/text/outline reads best (cherry: outline, 4.8:1). Only if none reaches 4.5:1 is the accent darkened. Never hardcode text colour on accent bars.
- Bar items use `BarButton` (22px high, 4px gap) in a 32px bar (`MenuStyle.barHeight`). Open bar menus with `taskbar.toggleMenu(menu, popup, item, align)` in Bar.qml. Menus opened by key that must work over fullscreen windows (launcher, Games, cheat sheet, Services, screenshot History, side panel, Spotify drawer, Wallpapers) are Overlay-layer `PanelWindow`s, not popups of the bar (the bar is on the bottom layer, under fullscreen windows, so a popup's clicks went to the fullscreen app). The small bar menus (Start, Theme, Bluetooth, SysMon, Session) stay `PopupWindow`s. Every menu opened via `toggleMenu` has `required property var bar` (Bar.qml passes `bar: taskbar`; no `parentWindow`, no reaching into Bar by id; the Overlay PanelWindows keep the property but mostly don't read it; the Spotify drawer has none), `openMenu()` and `closeMenu()`; Bar.qml keeps one `menus` list for close-all and Super+Q. Exceptions that don't go through `toggleMenu`: the snipping overlay, toasts / OSD, the tray tooltip, and the Task Manager (a real window, see `docs/desktop.md`). `align` is optional: default centres on the item, `"left"` uses its left edge, `"right"` is flush with the right screen edge (side panel), `"keep"` leaves positioning to the menu (launcher).
- Never hand-tune sizes or invent per-menu button styles. Named sizes live in `MenuStyle.qml`.
- Every `Text`/`TextField` sets `renderType: Text.NativeRendering` and `font.hintingPreference: Font.PreferFullHinting`. Qt's default text rendering has red/blue colour fringes here; this is greyscale and crisp.
- Fonts: Monaco for kitty and hyprlock (`~/.local/share/fonts`; the bar uses `quickshell/fonts`). Menu titles Charcoal; the bar centre text is Monaco 12 like the rest of the bar (it was Liberation Sans 14, which stays bundled with its OFL licence, unused). Monaco only hints evenly at some sizes (12, 16); 13/14 look wavy. Icons: bold filled Material Symbols font in `quickshell/fonts`.
- Kitty `background_opacity` stays 0.5 on purpose. A DOS look (white on black, `C:\HOME>` prompt) was tried and reverted at the user's request.
- Steam games (class `steam_app_<id>`) open on workspace 2 (`windowrules.lua`, `games-workspace`). Plain-wine games aren't covered.
- btop (installed, unbound) and GTK (`gtk-3.0`, `gtk-4.0`, `nwg-look`, `xsettingsd`) should follow the active theme (cherry or whichever is picked): same palette, same font where the tool allows. btop already does (generated), and so does GTK (below). GTK theme files live in `~/.local/share/themes`, outside the repo; the original is never touched (see `docs/theming.md`).

## Hands off
- Kitty color0-15 (fixed in `kitty/cherry_theme.conf`, not themed yet), the palettes of the non-cherry themes in `themes.json` (unless I ask), `hyprpaper.conf`, `hyfetch.json`.
- Never add `closeCallback` to ThemeMenu. It has none, and adding it breaks Bar.qml.
- Float rules for Nemo, portal, Loupe, VLC, 7zFM. Spotify and Vesktop go to `special:spotifyspace`.
- VLC also has `vlc-no-focus-steal` (`suppress_event = "activate activatefocus"`): a looped video re-created its window and, with `misc.focus_on_activate` on, pulled the cursor onto it. Confirmed live (the jump stopped); why it only started recently is unknown. If the jump comes back, the next step is `no_initial_focus = true` for VLC (cost: a freshly launched VLC would not take focus by itself).

## Code rules
- State files: settings.json, launcher.json, games.json, wallpaper.json, notifications.json, spotify-view.json are `GuardedFileView`s (`quickshell/GuardedFileView.qml`). Invalid JSON: the broken file is copied to `<name>.bad-<timestamp>`, Quickshell logs it and runs on in-memory defaults, and never overwrites the original until a later load parses. New JSON state file = use `GuardedFileView`, not `FileView`. Text that comes from outside (toast titles, lyrics, MPRIS, window titles, tray tooltips, clipboard preview, Spotify names, game titles) is `textFormat: Text.PlainText`. Confirm buttons say the verb (Reboot, Shut down, Log out, Suspend, Forget, Unpair, Move to Trash, End task), never Yes / No.
- One fact lives in one place. When you change behaviour, update its doc in the same commit (the table below says which). Never copy a fact into a second file; point to it.

## Where the details live (read the part you need before you change that area)
| Doc | What's in it |
|---|---|
| `docs/desktop.md` | Setup facts (workspaces, keys, Task Manager, autoclicker, NFS, deploy) and every area: bar, side panel, launcher, Bluetooth, screenshots, games, cheat sheet / Services / Phone, share picker, notifications, audio, wallpapers, idle / OSD / session, known state |
| `docs/spotify.md` | The Spotify drawer: layout, sizes, click model, keys, volume, memory, helper, 2026 API limits, tests |
| `docs/theming.md` | App themes (VSCodium, Zen) and the generated GTK theme / icons |
| `docs/ideas-starred.md`, `docs/ideas-other.md`, `docs/inspiration.md` | Suggestions from Claude, not requests: the idea lists (top picks, the rest, maybes) with the Rejected list (never suggest those again), and the design plan |
| `docs/DESIGN.md` | Generated (never edit): every named size, font, motion value and colour, from `MenuStyle.qml` and `themes.json`. After changing either, run `python3 scripts/gen-design.py`; check.py fails when it is stale |
| `FEATURES.md` | What exists (one line each), what's planned, and the ONE list of things that still need a live test |
| `MAINTENANCE.md` | Plain-English upkeep guide for me (updates, rollback, where to look when something breaks) |

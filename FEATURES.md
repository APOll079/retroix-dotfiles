# Features

What exists, what's left and what still needs testing on the real desktop. One line per feature; how each part works is in `docs/` (`CLAUDE.md` has the table).

Style: cherry retro, bevels, no rounding / blur / shadows, `Config.colors` only. Desktop only (no battery, brightness or wifi).

**Contents:** [Planned](#planned) · [Needs a live test](#needs-a-live-test) · [Done](#done) · [Removed](#removed-built-then-taken-out) · [Not wanted](#not-wanted)

## Planned

### Next up
- Design pass (`design-pass-prompt.md`): waves 1 and 2 are merged to main; wave 3 (`design-pass-w3`) put the Task Manager tabs on `TabPage` and dropped the grey / tint launcher icon code (colour stays). Left: the live tests below. Follow-ups noticed, none started: the Spotify row menu covers rows under it; the Themes menu has no Reduce motion button (not wanted); the font fallback for CJK is blocked (Qt 6.12 has no QML fallback list, see git log A11). E1 grain, C7 Control Panel, D12 balloons, D13 accelerators (Alt+F was built and dropped), D14 tab order and E2 VGA colours were skipped on purpose.
- From the old audit: lazy-loaded popups (tried: no way to measure the gain headless; if wanted, start with Spotify, launcher, screenshots, wallpapers, games).
- spotifyd upgrade: commands and checks are written in `docs/spotify.md`, yours to run.

### Small open items
- Spotify notification filter: `NotificationDaemon.qml` drops `appName` "spotify" (a guess). If Spotify track toasts still show, use the real app name.
- Portal float rule (`windowrules.lua`, `windowrule-4`, `^(xdg-desktop-portal.*)$`): check that a Zen file picker floats.
- Old files left in the live `~/.config/quickshell` (not in the repo, unused): `popups/MenuFrame.qml`, `popups/NetworkMenu.qml`, `taskbar/TaskbarButton.qml`, `preview.qml`, `fonts/MaterialSymbolsSharp_Filled_36pt-Regular.ttf`. The sync doesn't delete, so remove them by hand.

## Needs a live test
Built, not yet confirmed on the desktop. Tick a box when it works; move a broken one to "Next up" with what went wrong.

### Desktop overhaul (merged)
- [x] Task Manager window (window confirmed working; the rest of this line not individually checked): opens floating and centred, a resize sticks, Super+Q closes it, the title bar drags it, Ctrl+Shift+Esc again focuses it, from a fullscreen game it leaves fullscreen first; End task / Kill on your own apps; core-process confirm; Performance graphs
- [ ] CPU button: left = Task Manager on Performance, right = temperatures, the GPU part hides only when the lyric line needs the room
- [ ] Side panel: Home runs full height, the history scrolls, the chevron unfolds, times line up
- [ ] Clock: temperature with its unit ("8°C") in the label, right-click toggles DND; the Calendar tab shows the weather and the next days again; the DND button in the history header toggles the same switch (sunken while on)
- [ ] Super+Shift+H opens and closes Screenshot History; keypad Enter shoots in the snipping overlay (Screen / All) and confirms in the Task Manager; Esc in the Task Manager filter backs out of an open End / Kill confirm first
- [ ] Notification history: right-click an entry removes it without opening it; the rest stay, and it is gone after a Quickshell restart
- [ ] Services: a failing Start / Stop / Restart shows the dinitctl error above the buttons; a `session.customActions` entry shows by name in the side panel power row
- [ ] Wallpapers / Services buttons: a click opens, the same click closes, any bar click closes
- [ ] EQ preset row: fill `audio.eqPresets`, a click loads the preset, the sunken one survives a restart

### Design pass, wave 1 (branch design-pass-w1, rendered offscreen only)
- [ ] Buttons at real DPI: two bevel rings on bar and menu buttons (white / light top-left, black / grey bottom-right), pressed and toggled sunken, text fields white; nothing shifted or clipped in the bar
- [ ] The CPU box keeps one width while it ticks (try 100% load); the centre text gets the 27 px it saved; a temperature of 100 or more makes it one character wider
- [ ] `settings.ui.reduceMotion: true` (edit settings.json): menus open without fade / slide, hover is instant, a toast disappears at once, the idle dim appears at once
- [ ] Centred panels (launcher, games, wallpapers, services, screenshots, cheat sheet) still centred on both monitors; Spotify drawer and the notification history show no clipping after the padding change (page pad 3 -> 4, card inset 3 -> 4); menu content is 2 px wider
- [ ] Theme switch with a bright wallpaper (green / yellow / cyan "Set + colours"): applies, not refused; kitty and fastfetch now use the accent hue (dark background, light accent labels), `pkill -USR1 kitty` picks it up
- [ ] CJK text (Korean / Japanese lyrics, notification, song name): which fallback font fontconfig really picks (`noto-fonts-cjk` is in `packages/pacman.txt`; nothing in the repo controls it)

### Design pass, wave 2 (branch design-pass-w2, rendered / simulated offscreen only)
- [ ] Bar: the one sunken tray well at 1920 and 1280 (nothing clipped, the centre text gets its room, the GPU part still drops when the title is long), workspaces as plain raised buttons with the active one pushed in, one gripper, Start sunken while its menu is open, the clock as "3°C  Fri 6 Nov  05:34"
- [ ] Tray right-click menu with real tray items (shared `PopupMenu`): opens under the icon, Escape, a click outside, a pick, checked entries, an app with a submenu (falls back to the native menu); the first bar-opened menu with a focus grab, so also check it doesn't steal or lose keyboard focus in Hyprland
- [ ] Spotify drawer: the row menu with real keys (Up / Down wrap and skip, Enter, Escape returns the keys to the filter box, a click outside closes), hover highlight, the "..." menu, the quiet device banner with a real long device name, the scroll bar (wheel, drag, arrows), the seek bar keeping its fill
- [ ] Launcher: the banner, tabs by click, the Games tab inside the new `TabPage`, Shift+Enter and right-click options (`PopupMenu`; Escape and a click outside close it without closing the launcher; focus returns to the search box), Move up / down, Uninstall's confirm, the Start menu stripe
- [ ] File / View menu bars: Task Manager (a real window), Games and Wallpapers (overlay panels with exclusive keyboard): open, a second click closes, Escape, a click outside, the keys return to the search box
- [ ] Confirms (`ConfirmBar`): the side panel's power row, Phone Unpair, Bluetooth Forget, Task Manager End task / Kill / End anyway (Enter confirms, Esc backs out), History Move to Trash (Space / Del path), the Session panel (the question wraps at its 240 px)
- [ ] Side panel: tabs and Super+N, the group boxes, the microphone label with a real USB mic ("nickname · description" is a guess), the history's end line and empty state against real notifications, the scroll bars
- [ ] Status bars and empty states in Task Manager, Games, Wallpapers, Services and History; screenshot History at 1920 and 1280 wide (the large size clamped to the screen); Task Manager at its smallest size
- [ ] The urgent colour (darker, rust-coloured in cherry): the privacy icons, error text, a critical toast's title bar
- [ ] Window frames (`hypr/plugins.lua`, never run): install hyprbars and imgborders with `hyprpm`, `hyprctl reload`; do the option names, buttons and window-rule keys in `docs/theming.md` hold; do floating windows get the bar and tiled ones not; does the bevel draw around windows

### Work pass, wave 1 (branch work-pass-w1, offscreen only)
- [ ] History on the real panel and keyboard: type to filter, Space opens the viewer, Ctrl+C then paste elsewhere, Ctrl+O, the labelled buttons at real DPI (all tested on a scratch FloatingWindow copy only). Typing `[` goes into the glob and matches nothing (pre-existing)
- [ ] Shot names: a window-mode shot is named after the picked window, region / screen after the focused one (assumes Hyprland still reports it while the overlay is up), All and no window give `screenshot_`; two in one minute get `-2`; History Today / Week still find old and new names
- [ ] Shift+Print takes the instant full screenshot and F12 does nothing (the key form `SHIFT + Print` follows the other binds but is not confirmed by the Hyprland wiki); Zen gets F12 devtools back. Bind written, `luac -p` checked, never reloaded
- [ ] Services, System scope: Restart still opens the floating `qs-dialog` kitty and asks for doas (default command unchanged); optionally `terminal` foot with `terminalClassFlag` `--app-id`
- [ ] Spotify row menu in the real drawer: the song-name strip with real fonts, a click on it closes, keys still move, placement above and below the row
- [ ] Bluetooth battery: a real device shows its % (and the tooltip names it), disconnect goes back to ON, two devices show the lowest, one without a battery shows ON, the button keeps its width at 100%. If a device never reports one, BlueZ may need its experimental flag (from memory, unverified)
- [ ] Caffeine: on, then a Quickshell reload and a restart: the button stays on and the screen really doesn't dim or lock; log out and in: off (assumes the runtime dir is cleared at logout on Artix, untested)
- [ ] Empty states in the real hosts: Phone tab and Bluetooth menu height, launcher preview "Nothing selected" (now padded), Spotify lists and lyrics, notification history
- [ ] Low-memory toast: fill RAM above `ramPercent` (or put more than `tmpGb` in a tmpfs /tmp): one toast with the biggest program's name, no repeat while above, back only after the drop and the cooldown; `enabled: false` stays silent

### Bar, menus and desktop
- [ ] Menus over a fullscreen video (clicks stay in the menu); Super+Q / click-outside closes every menu
- [ ] Every search box (the shared SearchBox: arrows, Enter, Escape) in the launcher, games, cheat sheet, Services, screenshots, Spotify
- [ ] Bar now-playing click; OSD on the focused monitor; Workspaces click dispatch and centred numbers; tray tooltips; screen-share icon
- [ ] Power confirms in all four places (side panel, session panel, Start, launcher); launcher armed confirm; clipboard footer at 760 px
- [ ] Launcher Hide / Uninstall (Hidden chip); cheat sheet (Super+F1, scrolling)
- [ ] Services panel: does `dinitctl --user list` / `--system list` print the format the parser expects? Does System need doas to list? System actions open the doas terminal (`qs-dialog` rule: centre / size)
- [ ] Idle lock / DPMS timings; Calendar clicks
- [ ] hyprlock first at login (`autostart.lua`); `yay --sudo doas` on a reinstall
- [ ] Autoclicker (F8): run the setup script, log in again, F8 on a safe spot clicks about 20/s, F8 again stops, a toast says on / off

### Notifications
- [ ] One toast per app with a count, progress bars, Reply (inline reply from Vesktop / Discord, if they offer it), history kept after a Quickshell restart
- [ ] Toasts: title, hover pauses, none while the side panel's Home tab is open
- [ ] Spotify notification `appName` match (a guess)

### Audio
- [ ] First turn on "Use default output" in EasyEffects' PipeWire settings. Then click the DM15 and a Bluetooth sink and listen: does EasyEffects follow? Does `-b 1` / `-b 2` really switch the EQ, and what does it do to the mic chain?
- [ ] Connect / disconnect the Bluetooth speaker: sound and EQ return to the DAC by themselves. Restart EasyEffects: the EQ comes back on. If the hint line shows, EasyEffects is still pinned
- [ ] Per-app volume grouping
- [ ] Bluetooth pairing / trust / forget
- [ ] Bluetooth pairing agent (`scripts/bt-agent.py`): pair a PIN device (keyboard) and a passkey / number-compare device (phone, newer headset) from the Bluetooth menu. The helper is the default BlueZ agent while the menu is open, so it should win over blueman; check that blueman is default again after closing the menu, that typing in the PIN field works inside a bar popup (keyboard focus), that Pair / Allow / Cancel / Esc answer correctly, and that closing the menu mid-pair rejects cleanly

### Spotify
- [ ] Connection pool (`spotify.py serve`): play / pause, volume, seek and search feel the same or snappier; nothing errors after the PC sat idle a few minutes (a stale connection retries once)
- [ ] Setup: create the developer app, log in, then every control, Recent, the Library / Liked / Queue tabs, opening a playlist, the lyrics view (Ctrl+L); the animations (menus, hovers, Hyprland windows / workspaces)
- [ ] Consistency pass: five equal transport buttons; lyrics rows (volume, seek, transport) the same height; lyrics seek (drag, wheel, matches the main view, a line click still seeks); header buttons readable; volume % visible; Recent lined up with the grid on the same background; Recent / Pinned headings match; wrapped lyrics grouped; no cursor highlight until an arrow key; nothing cut at the right edge
- [ ] Search: type in the box, Enter (or the "Search Spotify for ..." row), Songs / Albums / Artists / Playlists chips, "More songs" rows (fixture-tested only)
- [ ] Play here from the phone; Play with nothing active carries on
- [x] spotifyd (works; needs an upgrade): the panel plays with the Spotify app closed; lyrics and the bar text follow spotifyd; the drawer closes when you click another program (same monitor and the other one)
- [ ] Folders: install the Spicetify extension, open the panel and the Spotify app; folders appear in Library > Playlists within a minute; the listener Origin (`FOLDERS_ORIGIN_HOSTS`) is accepted

### Screenshots, games, sharing
- [ ] Snipping overlay: region drag, Screen / All on DP-1, toast thumbnail and click; History multi-select, viewer, multi-copy paste, multi-delete
- [ ] Games menu and the launcher's Games / Clipboard tabs: shortcut launch, Add game, hide / remove, filter chips, Ctrl+Tab; games scan with the NAS off
- [ ] Screen-share picker: start a share from Discord, a browser or OBS (restart the portal first)

### Phone
- [ ] Phone tab: needs the KDE Connect app on the phone, the same Wi-Fi, firewall ports 1714-1764

### Theming and wallpapers
- [ ] Qt theme: install qt6ct, log out and in, pick Style "Fusion" and Color scheme "qsretro" in qt6ct; VLC (and another Qt app) takes the colours, a theme switch shows after restarting the app. Check that Quickshell itself looks unchanged with `QT_QPA_PLATFORMTHEME=qt6ct` set (text fields, scrollbars). The 21-entry palette order and the disabled / link colours are unverified
- [ ] GTK theme: restart Quickshell once (it writes QsRetro), then `gsettings set org.gnome.desktop.interface gtk-theme QsRetro`: Nemo, a GTK 4 app, a theme switch re-colouring open windows (the Adwaita flip), buttons / checkboxes / selections in every theme
- [ ] App themes: each app's one-time setup (`docs/theming.md`), then a theme switch. Does Zen's `@import` take effect? (VSCodium works; it needs Reload Window after a switch)
- [ ] Wallpaper colours: "Set + colours" on a real wallpaper, the Themes menu card "wallpaper", plain Set while that theme is active, the palette surviving a restart
- [ ] Wallpaper browser: Set on DP-1 / DP-2 / All, each fit mode, the choice coming back after a Quickshell restart and after a reboot
- [ ] Wallpaper at the first start after login: DP-2 gets its wallpaper (retried on its own). If the status says Invalid monitor: `hyprctl monitors | grep -E '^Monitor'` and `pgrep -a hyprpaper`
- [ ] Lock screen wallpaper: after Set, `hyprlock` (from a second TTY) shows the same picture per monitor; the `$var` in `path` and the `##` escape are unverified

## Done
- **Work pass, wave 1**: R4 removed the unused `MenuStyle.shotHistory*Fraction`; R7 found the broken icon links harmless (`docs/theming.md`); R1 `EmptyState` centres itself; R3 the clock text is built at the source; S3 caffeine survives a reload and restart; S5 Bluetooth battery in the bar; R6 disabled rows stop lighting on hover; R5 the Spotify row menu names its song; S4 Services takes its terminal from settings; P1 F12 became Shift+Print (gives Zen its devtools key back); R2 History action buttons carry labels; S2 shots are named by window; S1 History: type to filter, Ctrl+C / Ctrl+O; S6 low-memory and /tmp toast
- **Design pass, wave 2** (needs a live test, see above): shared `PopupWindowFrame` left titles, `RetroScrollBar`, `PopupMenu`, `ConfirmBar`, `GroupFrame`, `EmptyState`, `TabPage`, `StatusBar`, `MenuStrip`, `StartBanner`, `BarWell`, Win95 trackbars, window sizes, the Monaco centre title, a darker urgent colour; the bar, side panel, launcher, big windows and Spotify drawer moved onto them; `tests/interaction/` with real simulated input; the Win95 window frames as a written-not-run Hyprland config
- **Design pass, wave 1** (needs a live test, see above): component gallery (`quickshell/gallery.qml`, `scripts/render-gallery.sh`), palette rule in `apply.py` (bevel edge 1.35:1, text 4.5:1) with lighter highlights, two-ring Win95 buttons, spacing scale, two icon sizes, whole-pixel layout, fixed-width CPU label, two motion durations + Reduce motion, one embossed disabled look, generated `docs/DESIGN.md`, one-hue terminal and fastfetch, `noto-fonts-cjk` in the package list
- **Bar**: gripper, workspaces, Start / Themes, Wallpapers and Services buttons; Spotify lyric line; privacy icons, caffeine, CPU / GPU / RAM (click: Task Manager, right click: temperatures), ETH, Bluetooth, tray, bell + temperature + clock (right click: DND)
- **Side panel** (Super+N): power buttons with confirm, output / EQ presets / mic / per-app volume, full-height notification history (each entry a small raised window on a recessed well: title strip with app + time, 16 px title, 3-line body with a chevron), weather and calendar, DND button in the history header (also a right click on the clock); power row includes your custom session actions
- **Launcher** (Super+D): tabs Apps / Games / Clipboard (Ctrl+Tab), fuzzy apps with usage ranking and categories, calculator, session actions, "," window search (also Super+Tab), Super+V clipboard with delete and Clear all, options menu (pin, move, Hide / Unhide with a Hidden chip, Uninstall via pacman / flatpak)
- **Notifications**: toasts with actions, one per app; position / stack / monitor settings; history with one entry per notification that keeps the live notification, progress bars, inline reply, saved across restarts
- **Task Manager** (Ctrl+Shift+Esc or the CPU button): a real floating window, one for the desktop; Apps / Processes / Performance, Win95 style; replaces btm
- **Spotify panel** (Super+S): a drawer with now playing (cover, title, artist / album links, heart / add / lyrics, mute + volume), seek, a five-column transport, one search box (filter; Spotify search in place), Library | Liked | Queue tabs with flat chips, Recent, rows or cover tiles with Pinned / folder mosaics, list headers with Play / Shuffle, a row menu, a lyrics view, status-bar hints, a shared key map, remembers where you left it
- **Audio (Home tab)**: output list (click = default sink, EasyEffects follows; the EQ follows the real output, "EQ off" tag), EQ preset buttons, microphone mute + volume, scrollable per-app volumes
- **Bluetooth**: native BlueZ, connect / trust / forget / pair; PIN / passkey / compare prompts through a helper agent while the menu is open
- **Screenshots**: snipping overlay (Super+Shift+S / Print: Region, Window, Screen, All), toast with thumbnail, History viewer with multi-select (Super+Shift+H); no annotation by choice
- **Games**: cover grid with filter chips (All / Recent / Steam / Other / Hidden), as its own menu (Super+Shift+G) and as the launcher's Games tab; Steam, Steam shortcuts, own entries. Steam games open on workspace 2
- **Screen-share picker**: themed dialog (Screens / Windows tabs, thumbnails, Remember my choice) replacing the portal's default; no region sharing by choice
- **Cheat sheet** (Super+F1, read from the `-- help:` comments in `binds.lua`), **Services** panel (dinit; Start menu or the bar), **Phone** tab (KDE Connect)
- **Desktop**: idle dim / lock / screens off, OSDs, session panel, HyprEmoji, Super+Q closes an open menu before it closes a window, Win+C Vesktop scratchpad, autoclicker (F8, ydotool; one-time setup with `bash scripts/autoclick-setup.sh`), hyprlock at boot (greetd autologin + lock marker, asked by `install.sh`)
- **NFS drives at login**: user service `dinit.d/nfs-mounts` mounts `/mnt/disk1` and `/mnt/disk2` after `nm-online` (fstab lines need `noauto,user,exec`). Confirmed live
- **Theme manager**: `themes.json` + `apply.py` + templates drive kitty, Hyprland borders, hyprlock, fastfetch, btop, fish and the emoji picker; `cherry`, `dusty`, and a `wallpaper` palette made from a picture ("Set + colours")
- **GTK theme and icons**: ClassicPlatinumStreamlined recoloured into `QsRetro`, RetroismIcons hue-shifted into `QsRetroIcons` (icons confirmed live)
- **Qt theme**: `apply.py` writes the qt6ct colour scheme `qsretro` (only when `~/.config/qt6ct` exists); `QT_QPA_PLATFORMTHEME=qt6ct` in `hypr/env.lua`; setup in `docs/theming.md`
- **Spotify helper**: `serve` reuses HTTPS connections (pool of up to 4, one retry on a stale one)
- **App themes**: VSCodium and Zen from the active palette (CSS / colour files only). Neovim (not installed), Steam (needs Millennium), Spotify and Vesktop (tried, looked bad) skipped
- **Wallpaper browser**: Themes > Wallpapers... or the bar button; grid of `~/Pictures/wallpapers`, monitor + fit, set live through hyprpaper, restored at start, the lock screen follows
- **Look**: Win95 title bars, etched separators, grippers, dithered meters, dotted focus rect, sunken pressed states

## Removed (built, then taken out)
- Output switching by moving EasyEffects' streams: did nothing. Back as default-sink switching that EasyEffects follows (Done > Audio)
- Taskbar of open windows: buggy, not needed
- Caps-lock OSD, Alt+Tab switcher, satty / annotation, bar search button, speaker button, the icon-only Quick Launch strip (unlabelled squares read as noise), the clock's forecast tooltip
- Sunken wells around the bar groups, title-bar close boxes, per-app grouping in the notification history (it hid all but about two entries)

## Not wanted
Drag-to-reorder pinned apps (Move up / Move down is enough), region sharing in the screen-share picker, Heroic / Lutris / Bottles / Itch in the Games menu (Steam plus plain wine only), dock, desktop widgets, hot corners, screen-time tracker, dmenu mode / plugin providers, translator, video wallpaper, configurable bar, power profile, dark / light toggle, keyboard binds for moving / resizing windows (the mouse side buttons do that). Nightlight: not now.

Reference projects (read-only, for ideas): end-4/dots-hyprland, JaKooLit/Hyprland-Dots, HyDE-Project/HyDE, mylinuxforwork/dotfiles (ML4W), diinki/linux-retroism.

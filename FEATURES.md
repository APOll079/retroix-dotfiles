# Features

What exists, what's left and what still needs testing on the real desktop. One line per feature; how each part works is in `docs/` (`CLAUDE.md` has the table).

Style: cherry retro, bevels, no rounding / blur / shadows, `Config.colors` only. Desktop only (no battery, brightness or wifi).

**Contents:** [Planned](#planned) · [Needs a live test](#needs-a-live-test) · [Done](#done) · [Removed](#removed-built-then-taken-out) · [Not wanted](#not-wanted)

## Planned

### Next up
- From the old audit: F12 → Shift+Print (gives Zen its devtools key back), lazy-loaded popups (tried: no way to measure the gain headless; if wanted, start with Spotify, launcher, screenshots, wallpapers, games).
- spotifyd works but needs an upgrade.

### Backlog from the desktop-overhaul audit (Claude Code's suggestions, not picked yet)
| # | Fix | Size |
|---|---|---|
| 1 | Esc closes Start, Theme, Bluetooth, Session and the side panel (a Hyprland focus grab was tried: it broke clicks in the Themes menu, reverted) | S-M |
| 2 | Modal dialogs float and centre | S |
| 3 | Super+P pins a floating window (always on top) | S |
| 4 | Zen Picture-in-Picture: float, pin, a corner of DP-2 | S |
| 5 | Tooltips: ETH (IP, speed), privacy icons, cut-off lyric line | S |
| 6 | BevelButton tooltip + elide; one tooltip delay everywhere | M |
| 7 | Services: terminal from settings | S |
| 8 | Monaco 14 / 11 → 16 / 12 (launcher search, tucked labels): breaks the font rule | S |
| 9 | Screenshot History: type to filter, Ctrl+C / Ctrl+O | S |
| 10 | Loupe float rule on the class only | S |
| 11 | Super+right-drag resizes | S |
| 12 | Games chips clip "Hidden (nn)" | S |
| 13 | Caffeine survives a Quickshell reload | S |

Visual inconsistencies the audit found in code (check with a screenshot first): Theme menu cards and the screenshot toolbar are hand-rolled, raw TextFields in the Games form and the Phone tab, screenshot History sized by screen fraction, the bar's now-playing text has no hover.

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

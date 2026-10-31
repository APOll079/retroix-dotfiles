# Features

Style: cherry retro, bevels, no rounding/blur/shadows, Config.colors only. Desktop only (no battery, brightness or wifi).
Item numbers are the ids from the approval list. This file has two halves: **Planned** (what is left) and **Done** (what exists, one line each; details live in CLAUDE.md).

## Planned

### Next up
- Bluetooth PIN agent: only devices that ask for a PIN need it (blueman's agent works until then)
- Small ones left from the audit: F12 -> Shift+Print, lazy-loaded popups, reuse of the `serve` connection

### Needs a live test (built, not yet confirmed on the desktop)
- Desktop overhaul (branch `desktop-overhaul`): Task Manager window (opens floating + centred, resize sticks, Super+Q closes, title bar drags, Ctrl+Shift+Esc again focuses it, from a fullscreen game it leaves fullscreen first); CPU button (left = Task Manager on Performance, right = temperatures, GPU part hides only when the lyric line needs the room); side panel (Home full height, history scrolls, chevron unfolds, times line up); clock (temperature, right-click DND); Wallpapers / Services buttons (click opens, the same click closes, any bar click closes); EQ preset row (fill `audio.eqPresets`, click loads, sunken one survives a restart)
- Autoclicker (F8): run the setup script, log in again, F8 on a safe spot clicks about 20/s, F8 again stops, a toast says on / off
- Spotify folders: install the Spicetify extension, open the panel and the Spotify app; folders appear in Library > Playlists within a minute
- Menus over a fullscreen video (clicks stay in the menu); Spotify: Play here from the phone, Play with nothing active carries on; Task Manager (Ctrl+Shift+Esc): End task / Kill on your own apps, Performance graphs
- spotifyd: panel plays with the Spotify app closed; lyrics / bar text follow spotifyd. Spotify drawer closes when you click another program (same monitor and the other one)
- Notification upgrades: grouped toasts with a count, progress bars, Reply (inline reply from Vesktop/Discord, if they offer it), grouped history, history kept after a Quickshell restart
- Clean-up pass: every search box (now the shared SearchBox: arrows, Enter, Escape in the launcher, games, cheat sheet, services, screenshots, Spotify), Super+Q / click-outside closing on every menu, Services System actions
- Spotify panel (Super+S): create the developer app, log in, then every control, Recent, the Library / Liked / Queue tabs, opening a playlist, the lyrics view (Ctrl+L); the new animations (menus, hovers, Hyprland windows / workspaces)
- Launcher Hide / Uninstall (Hidden chip), keybind cheat sheet (Super+F1), Services panel (does `dinitctl --user list` / `--system list` print the format the parser expects? does System need doas to list?), Phone tab in the side panel (needs the KDE Connect app on the phone, same Wi-Fi, firewall ports 1714-1764)
- Bluetooth pairing / trust / forget
- Audio: turn on "Use default output" in EasyEffects' PipeWire settings first. Then: click the DM15 and a Bluetooth sink and listen (does EasyEffects follow? does `-b 1` / `-b 2` really switch the EQ, and what does it do to the mic chain?), connect / disconnect the Bluetooth speaker (sound and EQ should return to the DAC by themselves), restart EasyEffects (EQ back on). If the hint line shows, it is still pinned
- Wallpaper at the first start after login: DP-2 should now get its wallpaper (retried on its own); if the status still says Invalid monitor, run `hyprctl monitors | grep -E '^Monitor'` and `pgrep -a hyprpaper`
- GTK theme: restart Quickshell once (it writes QsRetro), then `gsettings set org.gnome.desktop.interface gtk-theme QsRetro`: Nemo, a GTK 4 app, a theme switch re-colouring open windows (the Adwaita flip), the buttons / checkboxes / selections in every theme
- App themes: each app's one-time setup (CLAUDE.md "App themes"), then a theme switch: does Zen's @import really take effect? (VSCodium works; it needs Reload Window after a theme switch)
- Wallpaper colours: "Set + colours" on a real wallpaper, the Themes menu card "wallpaper", plain Set while that theme is active, the palette surviving a restart
- Lock screen wallpaper: after Set, `hyprlock` (from a second TTY) shows the same picture per monitor; the `$var` in `path` and the `##` escape are unverified in hyprlock
- Wallpaper browser: Set on DP-1 / DP-2 / All, each fit mode, the choice coming back after a Quickshell restart and after a reboot (hyprpaper's error text and start-up timing are guesses)
- Snipping overlay: region drag, Screen / All on DP-1, toast thumbnail and click; History multi-select, viewer, multi-copy paste, multi-delete
- Games menu and the launcher's Games / Clipboard tabs: shortcut launch, Add game, hide / remove, filter chips, Ctrl+Tab; Super+Q closing menus
- Spotify search: type in the box, Enter (or the "Search Spotify for ..." row), Songs / Albums / Artists / Playlists chips, "More songs" rows (tested against a fixture only)
- Spotify consistency pass: five equal transport buttons; lyrics rows (volume, seek, transport) the same height; lyrics seek works (drag, wheel, matches the main view, a line click still seeks); header buttons readable; volume % visible; Recent lined up with the grid on the same background; Recent / Pinned headings match; wrapped lyrics grouped; no cursor highlight until an arrow key; nothing cut at the right edge
- This run's fixes: wallpaper restore on login (DP-2), qs-dialog rule (centre / size), Spotify listener Origin (`FOLDERS_ORIGIN_HOSTS`), bar now-playing click, OSD monitor, power confirms (side panel, session panel, Start, launcher), toasts (title, hover pause, Home suppression), launcher armed confirm, clipboard footer at 760 px, games scan with the NAS off, Task Manager core-process confirm, Services doas terminal, cheat sheet scroll, `yay --sudo doas` on a reinstall, hyprlock first at login
- Screen-share picker (start a share from Discord, a browser or OBS; restart the portal first), screen-share icon, idle lock / DPMS timings, per-app volume grouping, Calendar clicks, tray tooltips, Spotify notification `appName` match (a guess), Workspaces.qml click dispatch and centred numbers

### Theming run (LAST, as its own run, after you approve)
- 33b. Qt theme: no Qt config exists yet (qt6ct would be a new package; ask first)

Rules relaxed for the theming run only: CLAUDE.md says not to touch non-cherry themes in themes.json or kitty color0-15; the run may do both once you approve it.

### Theming run: what's left of the original design
- Built: palettes in `quickshell/theme/themes.json`, live reading in Config.qml, templates + `apply.py` for kitty, Hyprland, hyprlock, fastfetch, btop, fish, hypremoji, the app themes and the GTK theme; wallpaper browser and palettes from a wallpaper.
- Still to do: Qt only.
- Rule relaxed for this run only: the theme manager may touch the non-cherry palettes in themes.json and kitty color0-15, once approved.

### Small open items (from the old AUDIT.md)
- Spotify notification filter: `NotificationDaemon.qml` drops `appName` "spotify" (a guess). If Spotify track toasts still show, use the real app name.
- Portal float rule (`windowrules.lua`, `windowrule-4`) matches `^(xdg-desktop-portal.*)$`: check that a Zen file picker floats.
- Old files left in the live `~/.config/quickshell` (not in the repo, unused): `popups/MenuFrame.qml`, `popups/NetworkMenu.qml`, `taskbar/TaskbarButton.qml`, `preview.qml`, `fonts/MaterialSymbolsSharp_Filled_36pt-Regular.ttf`. Your sync doesn't delete, so remove them by hand if wanted.

## Done
- **Bar**: gripper, workspaces box, divider, Start / Theme, Wallpapers and Services buttons; Spotify lyric line (3); privacy icons (6), caffeine (5), sysmon with popup, ETH, Bluetooth, tray, bell + clock
- **Side panel** (Super+N): power buttons with confirm, output / EQ presets / mic / per-app volume, full-height notification history (each entry a small raised window on a recessed well: title strip with app + time, 16 px title, 3-line body with a chevron), calendar (7); weather (7) and DND (18) live on the bar clock (temperature in the label, right-click DND)
- **Launcher** (Super+D): tabs Apps / Games (cover grid) / Clipboard (Ctrl+Tab), fuzzy apps, calculator (10), session actions (11), "," window search, Super+V clipboard (4) with delete (Delete / Shift+Delete) and Clear all (confirm), usage ranking (13), categories, options menu with pin / move (15 partial). Super+Tab window switcher (the launcher's windows search)
- **Notifications**: toasts with actions (19), position / stack / monitor settings (20), history that keeps the live notification; one toast per app (history: one entry per notification), progress bars, inline reply, history saved across restarts
- **Bluetooth** (2): native BlueZ, connect / trust / forget / pair
- **Screenshots** (21): snipping overlay (Super+Shift+S / Print: Region, Window, Screen, All), toast with thumbnail, History viewer with multi-select; no annotation by choice
- **Games** (34): cover grid with filter chips (All / Recent / Steam / Other / Hidden), as the standalone menu (Super+Shift+G) and as the launcher's Games tab; Steam, Steam shortcuts, own entries; `scripts/games.py` + `GamesState.qml` + `GamesView.qml`
- **Screen share picker**: cherry dialog (Screens / Windows tabs, thumbnails, Remember my choice) replacing the portal's default picker; `sharepicker.qml` + `scripts/share-picker.sh` + `hypr/xdph.conf`. No Region sharing (by choice)
- **Desktop**: idle dim / lock / screens off (22), OSDs (23), session panel (24), HyprEmoji, Super+Q closes an open menu before it closes a window
- **Audio (Home tab)**: Output list (click = default sink, EasyEffects follows; the EQ follows the real output, "EQ off" tag), microphone mute + volume, scrollable per-app volumes; `AudioState.qml` + `AudioTab.qml`
- **Win+C**: Vesktop-only scratchpad (Spotify is the Quickshell panel)
- **Autoclicker** (F8): toggles a left-click loop, about 20 clicks/s (`hypr/scripts/autoclick`, ydotool); one-time root setup with `bash scripts/autoclick-setup.sh` (`--dry-run` first), then log in again for the input group
- **NFS drives at login**: user service `dinit.d/nfs-mounts` mounts `/mnt/disk1` and `/mnt/disk2` after `nm-online`; needs `noauto,user,exec` on the two fstab lines (outside the repo: the commands were given, not run). `nfs-utils` is in pacman.txt. Confirmed live
- **hyprlock at boot** (29): greetd autologin plus the lock marker (`~/.config/hypr/lock-at-login`, read in `autostart.lua`), both set up by `install.sh` (asks, default no). The lock screen works (confirmed); that it comes up at boot is assumed, not watched
- **Folder icons**: `theme/icongen.py` hue-shifts the blue of RetroismIcons to the accent into `~/.local/share/icons/QsRetroIcons` (Inherits the original; greys, reds, greens untouched); GTK settings, xsettingsd and `install.sh` use it. Confirmed live
- **GTK theme** (33): `theme/gtkgen.py` recolours the installed ClassicPlatinumStreamlined into `~/.local/share/themes/QsRetro` from the active palette (CSS + PNG assets), gtk settings files and `install.sh` (gsettings theme, icons, full font hinting) point at it
- **App themes** (32): VSCodium, Zen generated from the active palette (`apply.py` + templates; CSS / colour files only). Neovim (not installed), Steam (needs Millennium), Spotify and Vesktop (both tried, looked bad, dropped) skipped
- **Wallpaper colours** (31): `theme/wallcolors.py` (Pillow) makes a `wallpaper` palette from a picture (hue + colourfulness only, fixed lightness per role); browser button "Set + colours" / Shift+Enter; `apply.py wallpaper --palette FILE`
- **Wallpaper browser** (14): Themes > Wallpapers..., grid of `~/Pictures/wallpapers` (settings.json "wallpaper.folder"), monitor + fit, set live through hyprpaper IPC, re-set at start from the state dir; hyprpaper.conf untouched
- **Theme manager core** (30): `themes.json` + `apply.py` + templates drive kitty, Hyprland borders, hyprlock, fastfetch, btop, fish and the emoji picker; `dusty` alongside cherry
- Steam games open on workspace 2
- **Spotify panel** (Super+S): a drawer: now playing (cover, title, artist / album links, heart / add / lyrics, mute + volume), seek, a five-column transport, one search box (filter; Spotify search in place), Library | Liked | Queue tabs with flat chips, Recent (3 covers on top of the Library grid), rows or cover tiles with Pinned / folder mosaics, list headers with Play / Shuffle, a row menu, a lyrics view (volume, seek, transport under the lines), status bar hints, a shared key map, remembers where you left it; `scripts/spotify.py` + `SpotifyState.qml`
- **Task Manager** (Ctrl+Shift+Esc or the bar's CPU button): a real floating window (one for the desktop), Apps / Processes / Performance, Win95 style; replaces btm
- **Launcher cleanup**: Hide / Unhide + Hidden (n) chip, Uninstall via pacman / flatpak owner lookup
- **Cheat sheet** (Super+F1), **Services** panel (dinit), **Phone** tab in the side panel (KDE Connect); Services and Keys open from the Start menu
- **Look**: Win95 title bars, etched separators, grippers, dithered meters, dotted focus rect, sunken pressed states

## Removed (built, then taken out)
- Output device switching (1): first built by moving EasyEffects' streams, which did nothing. Superseded: it is back in the Home tab as default-sink switching that EasyEffects follows (see Done > Audio)
- Taskbar of open windows (8): buggy, not needed
- Caps-lock OSD, Alt+Tab switcher, satty / annotation, bar search button, speaker button
- Sunken wells around the bar groups, title-bar close boxes

## Not wanted
Drag-to-reorder pinned apps (Move up / Move down is enough), region sharing in the screen-share picker (monitor or program only), Heroic / Lutris / Bottles / Itch in the Games menu (Steam plus plain wine only), dock, desktop widgets, hot corners, screen-time tracker, dmenu mode / plugin providers, translator, video wallpaper, configurable bar, power profile, dark/light toggle. Nightlight: not now.

Reference projects (read-only, for ideas): end-4/dots-hyprland, JaKooLit/Hyprland-Dots, HyDE-Project/HyDE, mylinuxforwork/dotfiles (ML4W), diinki/linux-retroism.

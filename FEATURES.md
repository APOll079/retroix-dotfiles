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

### Capture bar, pause and preflight (branch record-controls, never looked at)
- [ ] Overlay (Super+Shift+S, then Record): the new bar `[Shot][Record] | targets | [Mic] | [History][X]` and the hint row look right at real DPI (it was never rendered), R switches, Screen / All wait for "Start recording" (Enter too), a plain shot still fires at once, Mic is dim in Shot mode and nothing jumps
- [ ] Preflight: Mic with no microphone shows the problem in red and blocks the start; a full disk or a read-only folder blocks; under 2 GB free only warns
- [ ] Pause: the bar's Pause / Resume and Super+Ctrl+P: does `SIGUSR2` really pause gpu-screen-recorder, does the clip skip the paused time, does `PAUSED 0:42` freeze and resume. If SIGUSR2 does nothing, the fix is the signal or the option in `record.sh pause`
- [ ] A recorder that fails at once (wrong portal, no permission) toasts its own last line instead of nothing

### History search and hourly forecast (never looked at)
- [ ] Notification history search: filters live while the panel keeps its keys (Super+N toggles), Escape twice (clear, then release the keyboard), right-click removes the right entry on a filtered list
- [ ] Hourly forecast in the Calendar tab: times match the place's local time (checked only against a fixture), four cells fit at 480 px (long values like "-12°C" may elide)

### Round 3, audio / capture / Spotify (never looked at, fakes only)
- [ ] Super+Ctrl+M with `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` and the OSD; the mic icon only shows while an app records
- [ ] Noise filter: does `easyeffects -l <audio.noisePreset>` switch input noise reduction on, and `noiseOffPreset` / the last EQ preset off, without disturbing the output preset? (set both in settings.json first)
- [ ] Output toast with a Bluetooth sink connecting / dropping; remembered volumes re-applied to a real stream (a browser with several streams); DND while sharing with a real portal stream
- [ ] Overlay Text mode: OCR on screen text (Swedish + English; install tesseract + data); "Save as GIF" on the recording toast (does your notification daemon show both actions?); `hyprpicker -a` prints #rrggbb so Super+Shift+C fills Start > Colours
- [ ] Spotify drawer in real focus: Escape / Enter on the "..." menu and both confirms
- [ ] Failed-disk / network toasts no longer replace each other (distinct app names)

### Round 3, launcher / Task Manager / NAS (never looked at, fakes only)
- [ ] Launcher: hover and the key cursor never light two rows (the pointer-gating with `HoverHandler` + `scenePosition` is untested live: if the cursor stops following the mouse, that is it); `kill zen` lists programs, Enter asks, End task closes with SIGTERM, a core program shows End anyway; `=` lists copied results, `:heart` shows emoji (do they render in the real font?); right-click a Clipboard row, Delete removes it
- [ ] Task Manager: the Ports tab shows real ports (`ss` output formats: unparsable lines are skipped), End task on your own listener asks first; the NET graph moves with a download
- [ ] NAS: stop the server: one toast and the bar button; the button remounts (needs the fstab `noauto,user` lines); the Downloads toast with Open / Show in folder
- [ ] Games: click a cover, the grid must not jump; Remove asks; Bluetooth and Updates panels don't resize while scanning or loading; History Escape clears the filter then closes; Prev / Next fit

### Round 4, themes and the optional cascade (never looked at)
- [ ] Themes menu: the Cursor and Icons dropdowns open inside it and a pick changes the GTK and Hyprland cursor (it persists across a Hyprland restart through `~/.local/state/qs-cursor`, read by `hypr/env.lua`; log out and in to confirm); Edit theme... opens the editor, Pick works with the real hyprpicker, Apply switches the live shell to the "custom" palette, Save with a failing contrast is allowed but Apply is off
- [ ] `settings.ui.cascadingStart: true` (Settings tab > Appearance): Programs appears first in Start, the cascade opens beside it and its keys work, the apps list flips left when there is no room; it uses a popup focus grab (the risky kind), so turn it off again if clicks misbehave

### Round 4, screensaver / mini player / overview (all visual: only seen live)
- [ ] Screensaver: look at starfield, pipes, mystify and random; every screen blanks; cursor jitter at the start doesn't close it, a key / click / mouse move after 0.5 s does; no start with caffeine or a fullscreen video; it fires before the dim (3 min); a static frame under reduce motion (`qs ipc call screensaver preview`, Super+Ctrl+K)
- [ ] Mini player (Super+Ctrl+O): the LCD and the 32 px digits, the marquee on a long title, play / prev / next / seek / volume with Spotify and with another player, "Nothing playing"; the window rule (size, pinned, bottom-left)
- [ ] Workspace overview (Super+Shift+O): cards with 1, 3, 6, 12 workspaces on both monitors; do the thumbnails capture (other workspaces too) or fall back to the label; clicks, arrows, Enter, Esc / click outside / second toggle; over a fullscreen window

### Round 4, launcher and network (never looked at, fakes only)
- [ ] `/ name` in the launcher on your real home (fd / plocate / find order, exclusions, real xdg-open); the Find window floats, centres and takes focus (`hyprctl reload` first; Super+Ctrl+F); the AppLauncher result area with the new rows next to the Settings tab (a merge point, never seen rendered)
- [ ] The ETH button opens the Network page (ip, ping and curl real; the speed test only on the button); `100 eur in sek` with a real frankfurter answer (does api.frankfurter.app still answer or redirect?)
- [ ] Restore workspaces (Super+Ctrl+W and 8 s after login): are Zen on 1 and VSCodium on 3 right (edit `hypr/restore.lua`), does `hl.exec_cmd(cmd, { workspace = "1 silent" })` work (the call shape is a guess; the fallback is one window rule per program)

### Round 4, tools (never looked at, fakes only)
- [ ] Solaar: `dinitctl --user enable solaar` (copy `dinit.d/solaar` first, your sync does it), it stays running and the mouse battery shows; if it can't open a display the user dinit lacks the Wayland environment; the mic, screen-share and REPLAY indicators are flat icons with no bevel; the mouse battery % shows beside Solaar's tray icon (no separate item) and a click on it opens Solaar, only clickable things look like buttons
- [ ] Task Manager GPU / VRAM / Read / Write numbers against radeontop / iotop on the AMD card, and the extra columns fit at 760 px; Default apps: Make default really changes `xdg-settings get default-web-browser` and `xdg-mime query default image/png`
- [ ] Troubleshoot: each of the four restarts with the real dinit services (and the relaunch fallback for hyprpaper / EasyEffects); Login report after a real login (needs the new `autostart.lua` marks: `hyprctl reload` does not re-run them, log in again)
- [ ] Solaar: `solaar show` on the real mouse parses and the bar button appears; Flatpak: Sober shows in Games and launches; MangoHud overlay for a Steam game (see the note in docs), a Flatpak game and an own entry; security audit: the first run is silent, a new CVE toasts

### Settings tab (never looked at)
- [ ] Start is clearly shorter (Files, Terminal, Settings, Power / Keys, Trash, Updates (N)); Settings > System tools opens each of the eight tools (Default apps, Network, Services, Troubleshoot, Login report, Clean up, Colours, Updates) and searching "network" in the Settings tab finds the row
- [ ] Super+D, Settings tab (or Start > Settings, Super+Shift+comma): change one setting of each type (On/Off, number, text, list, choice) and check the bar and other menus follow; the label column and hints fit at 760 px with the real Monaco font; the search box filters rows from all categories, Down moves into the first control, Escape in an empty field returns to the search box; tab order across rows; "Open settings.json" opens your editor; which settings really need a restart (none is flagged yet)

### Round 4, desktop / notifications / audio / phone (never looked at, fakes only)
- [ ] A fullscreen video past the dim time keeps the screen on; right-click a toast opens the menu (closes on Esc / click outside), mute and priority work, "Muted apps (n)" unmutes
- [ ] Phone battery on the bar with a real phone (are the KDE Connect D-Bus names right?), Send to phone with a file and a link
- [ ] Test mic with headphones (Stop and closing the tab end it, no `pw-loopback` left); "Play on" with a real stream (if nothing moves, the stream id mapping is the guess)
- [ ] Bar centre: a YouTube tab in Zen with Spotify closed shows on the bar; right-click the text: Like / Add to playlist; track toast on a real song change (`spotifyExtras.trackToast`)

### Round 4, my share (never looked at)
- [ ] Super+V opens the clipboard with no tabs; Super+D still has Apps / Games / Clipboard and the Clipboard tab works there
- [ ] Themes menu: "win95" and "platinum" appear; applying each re-colours the bar, kitty and GTK; do the borders and the select colour read well? (apply.py accepts both)
- [ ] Laptop profile: copy `hypr/monitors_local.lua.example` to `monitors_local.lua` on the laptop; its screen comes up without editing `monitors.lua`

### Round 3, my share (never looked at)
- [ ] After `hyprctl reload`: Loupe floats for any image; Zen Picture-in-Picture floats pinned bottom-right (is the title "Picture-in-Picture"?); file dialogs float and centre (does the title match list catch yours?); Super+Ctrl+T drops the terminal down and hides it again; Super+Ctrl+Z zooms (the `hl.config` call shape and `cursor.zoom_factor` are guesses)
- [ ] Clock width stays put when the weather arrives; the launcher search is Monaco 16 and nothing in it clips; selected text in a search box is readable; buttons shift their content by exactly 1 px when pressed
- [ ] `bash scripts/install-hooks.sh` once, then a commit runs `check.py`; `bash uninstall.sh` (dry run) lists the newest backup

### Bar, updates and trash changes (never looked at)
- [ ] CPU button: a left click shows the Task Manager (Performance tab), the next click hides it, and the button looks pushed in while the window is open; Ctrl+Shift+Esc still opens / focuses it
- [ ] Bar: Start and Themes are labelled and wider; no Wallpapers / Services buttons (Wallpapers is in the Themes menu, Services in the Start menu); the right side (caffeine, CPU, ETH, Bluetooth, bell + clock) is raised boxed buttons with gaps, no sunken frame: nothing clipped at 1920 and 1280, the centre text still gets its room (the width bookkeeping now counts the gaps); no stripe down the left of the Start menu and launcher, no dot on the Start button
- [ ] Updates: System / Flatpak / Update all each open the wider terminal (960x460, the rule isn't reloaded until `hyprctl reload`); after closing the terminal the count drops (and the Start dot goes) within a few seconds
- [ ] Start > Trash (size) opens the Trash folder in your file manager (`trash:///`); nothing in the shell empties it any more
- [ ] Launcher answers: "5 km in mi", "#c950bb", "time tokyo" in Super+D (text, glyph, Enter copies and closes), plus one the calculator also knows ("1 mib to kib") and a time in a zone that is in daylight saving now (glyph codepoints unchecked)

### Network and VPN watch (never looked at)
- [ ] Pull the cable and plug it back: "Network is down" then "Network is back" once each, about 20 s after the change (a shorter flap toasts nothing); a host added to `networkWatch.hosts` toasts "is down" / "is back" once. Set `hosts` in settings.json to try it (empty by default)
- [ ] Connect a NetworkManager VPN or WireGuard: the bar button appears within 15 s with its name (never looked at; glyph `\ue897` unchecked), a click drops it; a WireGuard interface NM doesn't manage should still show (fallback tested with fakes only)

### Clipboard layout (branch clipboard-layout, never looked at)
- [ ] Launcher Clipboard tab (Super+V): the same small tabs as Apps and Games, no inner padding, the preview and list fill the width; Ctrl+Tab and the tabs both switch, and the dead space is gone (the preview pane is still 45 % wide: `MenuStyle.clipPreviewFraction`)

### Work pass, wave 2 (branch work-pass-w2, offscreen only, never looked at)
- [ ] Updates (install pacman-contrib): the counts match `checkupdates` / `yay -Qua` / flatpak, the Arch news lines load, the dot on Start and the "Updates (N)" row appear, Update opens kitty on `yay -Syu`; neither panel nor the Start rows were ever looked at (glyph codepoints unchecked)
- [ ] Clean up: real sizes per row, Clean then the ConfirmBar then the doas terminal for pacman cache and orphans, Esc cancels a confirm first (the Trash is only a Start row that opens its folder)
- [ ] Lyrics window (never looked at): Super+Ctrl+L during a synced song: floats pinned bottom-right (the rule's `pin` / `move` / `min_size` names are unverified, rule never reloaded), the line follows the music and wraps at 420 px, a second toggle closes it, Super+Q and Esc close it; the Spotify drawer's lyrics view still ticks fast after the window closes
- [ ] USB drives (install udisks2): plug in a stick: toast with Open / Eject; Open mounts and opens the folder; the Start menu shows "Eject <name>" (never looked at); Eject with a file manager on it shows the busy error, then works after closing it; sticks plugged in before the shell starts don't toast; a stick with several partitions toasts once per partition
- [ ] Calendar to-do list (never looked at): add with and without a date, click a day to set the due date, toggle, right click Delete, edit `todo.txt` in an editor and see it update, the due-day bars on today and a picked day, the checkbox glyphs show (codepoints unchecked), Escape in the add field, the tab keeps its height
- [ ] Disk warnings: a mount above 90 % toasts once (fake one with a small tmpfs), the NAS mounts with the NAS off say "not responding" once and the bar never freezes; SMART on your disks: with and without the doas rule from `docs/desktop.md` (a failing disk toasts critical; one that passes stays silent)
- [ ] Failed service toast: stop a user service from a terminal (`dinitctl --user stop spotifyd`): one toast with Restart and Details, Details opens Services on its log (does `catlog` print anything without `log-type = buffer`?); a stop through the panel doesn't toast; the panel's Log / Back buttons and Escape look right (the log view never ran in a window)
- [ ] Screen recording: install `gpu-screen-recorder`; Super+Shift+R, Record (+ Mic) on region / window / screen on both monitors: the overlay isn't in the video, the bar shows REC m:ss and a click stops it, the "Recording saved" toast opens the file, the mic track is audible, a window clip has the right size (odd sizes may need even numbers), a Quickshell reload mid-recording keeps REC. Overlay and bar button have never been looked at
- [ ] Replay buffer: Super+Ctrl+R arms it (REPLAY in the bar), wait past `replaySeconds`, Super+Ctrl+S: a clip appears within about 2 s, about that long, the toast opens it; save with nothing armed says so; toggle off ends the process. The `SIGUSR1` save signal is unverified. Binds are written, `luac -p` checked, never reloaded
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
- **Work pass, wave 2** (needs live tests, see above): M1 screen recording and M2 replay buffer, M3 failed service toast, M4 disk warnings, M9 side panel audit (fixes: code only; the rest is a list in the wave 2 report), M10 to-do list, M7 USB drives, M8 lyrics window, M5 updates, M6 clean-up
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

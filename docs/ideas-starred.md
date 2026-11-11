# Ideas: top picks (★)

Claude's suggestions, **not picked yet** (except section 0, which is yours). Nothing here is a request until it moves to FEATURES.md "Planned".
The other ideas, the maybes and the rejected list are in `ideas-other.md`. Both files use the same sections. Design ideas are in `inspiration.md`.

Size: **S** an evening, **M** a session or two, **L** a project. "(seen in ...)" names a Noctalia / DankMaterialShell / Caelestia plugin that does something similar, so you can look at how they did it.

## 0. Fixes you asked for

These three are your requests, not my suggestions. Details are what I could guess from your words; Claude Code should check the real setup first.
| | Idea | Size |
|---|---|---|
| ★ | **Start Hyprland the right way, not in debug mode**: launch it with `start-hyprland` (the launcher script you called hyprland-start) instead of running `Hyprland` directly, and without the debug / verbose flags. First check how it starts today (Limine entry, a tty profile, greetd or a script) | S |
| ★ | **Limine: boot CachyOS without choosing**: Limine waits at its menu and you pick an entry by hand. Set the default entry and a short timeout in `limine.conf` (`default_entry`, `timeout`), so CachyOS boots by itself and the menu is only there if you press a key. Check what the entries are first (kernels, snapshots, fallback) and keep a way to reach them | S |
| ★ | **Lock screen at login**: `hyprlock` as soon as the session starts (autologin, then lock), or another customisable login screen instead. `install.sh` already offers greetd autologin with a lock; the "Login screen" and "Win95 lock screen" ideas are the styled versions | M |

## 1. Capture
| | Idea | Size |
|---|---|---|
| ★ | **Screenshot History: type to filter**, Ctrl+C copies / Ctrl+O opens the selected shot | S |
| ★ | **Text from a region (OCR)**: drag a box, the text lands on the clipboard (`tesseract`, Swedish + English) | S |
| ★ | **Colour picker in the shell**: the existing `hyprpicker` bind, plus a small history of picked colours (hex / rgb, click to copy) | S |
| ★ | **GIF from a recording**: "Save as GIF" on a short clip (ffmpeg), for Discord | S |
| ★ | **Name shots by window**: `zen_2026-11-03_14-05.png` instead of a plain timestamp | S |
| ★ | **OBS controls**: start / stop recording, save the replay buffer, from the bar (OBS is installed; an alternative to a separate recorder) (seen in obs-control) | S |
| ★ | **Screen recording**: a Record mode in the snipping overlay (region / window / screen, mic on/off), red "REC 0:42" in the bar, click to stop, toast with the file. `gpu-screen-recorder` (AMD-friendly) or `wf-recorder` | M |
| ★ | **Record the last 30 s (replay buffer)**: for games; one key saves the clip (`gpu-screen-recorder` replay mode) | M |

## 2. System health
| | Idea | Size |
|---|---|---|
| ★ | **Services: terminal from settings** | S |
| ★ | **Caffeine survives a Quickshell reload** | S |
| ★ | **Low-memory toast**: RAM above 90 % names the biggest program, and warns when `/tmp` (RAM-backed) is over a few GB, which is what ate 7 GB last time | S |
| ★ | **"Fix my desktop" action**: Start menu > Troubleshoot: restart Quickshell, the portals, PipeWire / WirePlumber, hyprpaper, EasyEffects, one click each | S |
| ★ | **NAS status**: an icon while `/mnt/disk1` / `disk2` are mounted, a warning when they're stale, Remount in one click | S |
| ★ | **Login time report**: what slowed the last login (from the autostart timestamps) | S |
| ★ | **Security audit**: installed packages checked against Arch security advisories, a toast on a new CVE that affects you (seen in arch-audit) | S |
| ★ | **Bluetooth device battery**: headphones / controller % in the bar while connected | S |
| ★ | **Default apps**: see and change the default browser, image viewer, video player (you have four image viewers) (seen in default-apps) | S |
| ★ | **USB drives**: toast on plug-in (Open / Eject), an Eject list in the Start menu or side panel (udisks2 is already there) | S-M |
| ★ | **Clean-up**: Start menu > Clean up: pacman cache (`paccache`), orphans, unused flatpak runtimes, old screenshots, the Trash; shows how much each frees first. Empty Trash also on its own in the Start menu, with the size | S-M |
| ★ | **Updates**: pending pacman / AUR / flatpak count in the Start menu (and a dot on Start when there are any), Update button opens kitty with `yay -Syu`, news check from archlinux.org / Artix first. Afterwards: list the `.pacnew` files with a diff, so package config changes don't go unnoticed (seen in arch-updater), and after a kernel / mesa / Hyprland update a "Restart to finish updating" marker on Start | M |
| ★ | **Backups**: a scheduled `restic` (or borg) backup of home to the NAS, last-backup time in the Start menu, a toast if it's older than a week | M |
| ★ | **Disk warnings**: toast when `/`, home or a NAS mount passes 90 %, and SMART warnings from `smartctl` | M |
| ★ | **Failed service toast**: a dinit service that stops or fails says so, with Restart and Details (its last errors, also reachable from the Services panel) | M |
| ★ | **Event hooks**: run your own scripts on events (monitor plugged in, Bluetooth device connected, a game started, theme changed) (seen in Dank Hooks (DMS)) | M |

## 3. Network
| | Idea | Size |
|---|---|---|
| ★ | **Network watch**: toast when ETH drops or comes back (nmcli monitor already runs), plus a ping list (NAS, router, Home Assistant, the printer) that toasts when one goes down or comes back (seen in link-ip-monitor) | S |
| ★ | **VPN status**: small icon in the bar while a WireGuard / NetworkManager VPN is up, click to disconnect; public IP and country in the ETH tooltip (seen in ip-monitor, geoip-monitor) | S |
| ★ | **Ports**: what's listening on which port, kill the process holding one (handy with Docker and dev servers) (seen in portctl, network-monitor) | S |
| ★ | **Network page**: your LAN devices / gateway ping / internet speed test in one small window | M |

## 4. Task Manager
| | Idea | Size |
|---|---|---|
| ★ | **Network speed**: up / down rate in the Task Manager's Performance tab (seen in network-monitor, system-monitor) | S |
| ★ | **GPU processes**: which programs use the GPU and VRAM, as a Task Manager column (seen in nvtop) | M |
| ★ | **Disk I/O per process** in the Task Manager (seen in processes) | M |

## 5. Launcher
| | Idea | Size |
|---|---|---|
| ★ | **Timers**: "timer 10m pizza" in the launcher, a toast + sound when done, the running timer in the bar | S |
| ★ | **Conversions in the calculator**: units offline ("5 km in mi", "180 cm in ft") and currency with today's rate ("/fx 100 eur" to SEK, seen in currency-exchange) | S |
| ★ | **Folder shortcuts**: the Nemo bookmarks as results (Pictures, NAS, repo) | S |
| ★ | **Colour preview**: typing `#c950bb` shows a swatch and copies rgb / hsl | S |
| ★ | **Time zones**: "time tokyo" answers | S |
| ★ | **Emoji in the launcher**: a ":" prefix searches emoji (alongside HyprEmoji) | S |
| ★ | **Kill from the launcher**: "kill zen" (with the Task Manager's safety rules) | S |
| ★ | **Spotify from the launcher**: "sp song name" plays the top result | S |
| ★ | **Calculator history**: the last results, click to copy | S |
| ★ | **Services by name**: "/svc spotifyd" to start / stop / restart a dinit service without opening the panel (seen in systemd) | S |
| ★ | **Ask Claude from the launcher**: "/ai question" runs the `claude` CLI on your subscription, shows the answer in place, "Continue in terminal" opens it in kitty (seen in ask-claude) | S |
| ★ | **File search**: a "/" prefix searches home (`fd` or `plocate`), Enter opens, Shift+Enter opens the folder | M |

## 6. Windows, workspaces and monitors
| | Idea | Size |
|---|---|---|
| ★ | **Esc closes every menu**: Start, Theme, Bluetooth, Session and the side panel (a Hyprland focus grab was tried and broke clicks in the Themes menu) | S |
| ★ | **Modal dialogs float and centre** (window rule) | S |
| ★ | **Zen Picture-in-Picture**: floats, pinned, in a corner of DP-2 | S |
| ★ | **Loupe float rule on the class only** | S |
| ★ | **Drop-down terminal**: a Quake-style kitty that slides from the top on one key and hides again (special workspace, like the Vesktop scratchpad) | S |
| ★ | **Zoom**: a key that magnifies around the cursor (Hyprland cursor zoom), for small text | S |
| ★ | **Stay awake while video plays**: idle doesn't dim during a fullscreen video, without turning caffeine on by hand (seen in inhibit-idle-while-watching) | S |
| ★ | **Restore workspaces at login**: each workspace gets its apps (Zen on 1, VSCodium on 3, ...), reopened and moved back at login or with one click (seen in workspace-restore) | S-M |

## 7. Audio
| | Idea | Size |
|---|---|---|
| ★ | **Noise suppression**: one toggle for the mic in the side panel (EasyEffects' RNNoise / deep-filter on the AT2020 chain) | S |
| ★ | **Mic mute key + OSD**: one key mutes the AT2020 everywhere, the OSD says MIC OFF, the privacy icon turns red | S |
| ★ | **Output switch toast**: when Bluetooth takes over or drops, a toast says where sound goes now | S |
| ★ | **Hear yourself**: a mic test button that plays the mic back for 5 s | S |
| ★ | **Remember app volumes**: Spotify always at 90 %, Discord at 70 % | S |
| ★ | **Move an app to another output**: right-click an app in the side panel > "Play on" (e.g. Discord on the headphones, Spotify on the speakers) | M |
| ★ | **Other players on the bar**: YouTube in Zen etc. as "Artist - Title" when Spotify is quiet | M |

## 8. Side panel, notifications, calendar and phone
| | Idea | Size |
|---|---|---|
| ★ | **Pomodoro / focus timer**: 25 / 5 cycles in the side panel, DND on during focus, a counter in the bar | S |
| ★ | **DND while screen sharing**: no toasts pop up on a shared screen (the privacy icon already knows) | S |
| ★ | **Mute an app**: right-click menu on a toast / entry > "Don't show toasts from vesktop" (still kept in the history) | S |
| ★ | **Search the history**: a filter box at the top of the history | S |
| ★ | **Notification sounds**: per-app on/off, one quiet sound (see "Sounds" for the asset rule), and optionally a different sound for messages from chosen people (seen in contact-sounds) | S |
| ★ | **Priority apps**: chosen apps get through DND (phone calls) | S |
| ★ | **Act on the latest toast by key**: Super+Shift+N opens / Super+Shift+X dismisses the newest | S |
| ★ | **Hourly forecast**: today by the hour in the Calendar tab | S |
| ★ | **Phone battery**: a small phone icon with % in the bar while it's connected (KDE Connect), click = Phone tab | S |
| ★ | **Send to and from phone**: "Send link / file to phone" from the launcher and the screenshot toast (KDE Connect or LocalSend), and a toast when a file arrives from a LocalSend device, with Open / Show in folder (seen in localsend) | S |
| ★ | **Improve the side panel (notifications / calendar / etc.)** (suggestion): a pass over Super+N instead of a separate dashboard. Look at what is cramped or missing in each tab (Home, Calendar, Phone, notification history) and fix the worst: readability, what is shown first, what could sit on the Home tab (now playing summary, CPU / RAM, next calendar item). Starts with a look at the current panel, then a short list for you to pick from (seen in Caelestia's dashboard) | M |
| ★ | **To-do list**: in the Calendar tab, with due dates shown on the calendar; a plain file so it syncs with your notes | M |

## 9. Games
| | Idea | Size |
|---|---|---|
| ★ | **Real game mode**: Super+G already frees the side buttons; also turn on caffeine, DND, turn off Hyprland animations, show "GAME" in the bar, and pause chosen programs (Ollama, Docker, sync) until it ends (seen in gamer-mode). Steam games switch it on by themselves (window class `steam_app_*`) | S |
| ★ | **Flatpak games in the grid**: Sober (Roblox) and other flatpak games as tiles next to Steam | S |
| ★ | **Performance overlay toggle**: MangoHud on / off from the Games menu | S |

## 10. Spotify
| | Idea | Size |
|---|---|---|
| ★ | **Track toast**: optional themed "now playing" toast on song change; the cover can slide out from the bar for a few seconds instead (seen in media-island) | S |
| ★ | **Like from the bar**: right-click the lyric line > Like / Add to playlist | S |
| ★ | **Lyrics window**: a small floating karaoke window (current and next line), always on top, for when the drawer is closed | M |

## 11. Files and downloads
| | Idea | Size |
|---|---|---|
| ★ | **Download toast**: a finished download in `~/Downloads` gets "Open / Show in folder" | S |

## 12. Your apps and hardware
| | Idea | Size |
|---|---|---|
| ★ | **Ollama manager**: your local models listed, start / stop, which one is loaded and how much RAM it holds (you run `ollama serve`) (seen in llamanager) | S |
| ★ | **Logitech mouse**: battery, DPI and button profile through Solaar (already installed) in the bar or side panel (seen in mx-control) | S |
| ★ | **Claude Code usage in the bar**: running sessions, which one is waiting for you, how much of your plan limit is left and when it resets; read from Claude Code's own local files (no API, no extra cost) (seen in bloom, claude-sessions, claudecode) | S-M |
| ★ | **Obsidian quick capture**: launcher "/note text" appends to today's daily note; vault git status and a Sync button (seen in obsidian) | S-M |
| ★ | **Home Assistant panel**: lights and scenes as buttons in the side panel through HA's REST API (a long-lived token in the state dir, never in the repo) | M |
| ★ | **3D printer**: progress and time left in the bar while the K2 prints (only if it exposes a Moonraker / HTTP API; check first) | M |
| ★ | **Discord voice**: who's in your voice channel, who's speaking, mute / deafen from the bar (check that Vesktop exposes it first) (seen in discord-voice) | M |

## 13. Theming and retro look
| | Idea | Size |
|---|---|---|
| ★ | **Monaco 14 / 11 → 16 / 12** in the launcher search and tucked labels (they break the font rule today) | S |
| ★ | **Classic theme presets**: "Windows 95" (teal desktop, grey chrome) and "Platinum" (Mac OS 8 grey) palettes in the Themes menu | S |
| ★ | **Character Map**: browse and copy the Material Symbols icons by name, shows the `\uXXXX` code (handy for building the shell itself) | S |
| ★ | **Theme editor**: build a new palette in the Themes menu by picking each role's colour (or picking it off the screen), with the contrast check (seen in palette-creator, palettes) | M |
| ★ | **Cursor and icon pickers**: choose cursor / icon themes in the Themes menu, applied everywhere at once (seen in cursor, icons) | M |
| ★ | **Cascading Start menu**: Programs > category > app submenus, like the real Start menu (the launcher stays for search) | M |
| ★ | **Find dialog**: a Win95 "Find: Files or Folders" window as the big version of launcher file search | M |
| ★ | **Win95 lock screen**: a Quickshell lock (WlSessionLock) that looks like the "Welcome to Windows" password box | L |
| ★ | **Login screen**: a Quickshell greeter for greetd in the same style, so the look starts before you log in | L |

## 14. The repo itself
| | Idea | Size |
|---|---|---|
| ★ | **Git pre-commit hook** that runs `scripts/check.py`, so nothing broken gets committed even without Claude | S |
| ★ | **Laptop profile**: `monitors.local.lua` (gitignored) so the ThinkPad uses its own screen without editing the repo | S |
| ★ | **CHANGELOG.md** written from the commit messages, and tags for versions | S |
| ★ | **Uninstall script**: puts the backups from `~/config-backup-*` back | S |
| ★ | **Test install in a container**: run `install.sh --dry-run` on a clean Artix image in Docker | M |

## 15. Gimmicks and fun features
Pure fun: nice to have, nothing depends on them.
| | Idea | Size |
|---|---|---|
| ★ | **"It's now safe to turn off your computer"**: the orange-on-black screen for a second at shutdown / reboot | S |
| ★ | **Defrag clean-up**: the Clean-up action shows a Win95 defrag-style block grid while it works | S-M |
| ★ | **Screensaver**: Win95-style 3D pipes, starfield, Mystify or a maze, drawn in QML, after idle and before dim / lock; any key returns | M |
| ★ | **Winamp-style mini player**: a small floating player (bevels, a green LCD time, a tiny visualizer), drawn in QML, no copied skin art | M |

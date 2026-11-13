# Ideas: top picks (★)

Claude's suggestions, **not picked yet** (except section 0, which is yours). Nothing here is a request until it moves to FEATURES.md "Planned".
The other ideas, the maybes and the rejected list are in `ideas-other.md`. Both files use the same sections.

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
| ★ | **Name shots by window**: `zen_2026-11-03_14-05.png` instead of a plain timestamp | S |
| ★ | **OBS controls**: start / stop recording, save the replay buffer, from the bar (OBS is installed; an alternative to a separate recorder) (seen in obs-control) | S |

## 2. System health
| | Idea | Size |
|---|---|---|
| ★ | **Backups**: a scheduled `restic` (or borg) backup of home to the NAS, last-backup time in the Start menu, a toast if it's older than a week | M |
| ★ | **Event hooks**: run your own scripts on events (monitor plugged in, Bluetooth device connected, a game started, theme changed) (seen in Dank Hooks (DMS)) | M |

## 5. Launcher
| | Idea | Size |
|---|---|---|
| ★ | **Folder shortcuts**: the Nemo bookmarks as results (Pictures, NAS, repo) | S |
| ★ | **Calculator history**: the last results, click to copy | S |
| ★ | **Services by name**: "/svc spotifyd" to start / stop / restart a dinit service without opening the panel (seen in systemd) | S |

## 8. Side panel, notifications, calendar and phone
| | Idea | Size |
|---|---|---|
| ★ | **Pomodoro / focus timer**: 25 / 5 cycles in the side panel, DND on during focus, a counter in the bar | S |
| ★ | **Notification sounds**: per-app on/off, one quiet sound (see "Sounds" for the asset rule), and optionally a different sound for messages from chosen people (seen in contact-sounds) | S |
| ★ | **Act on the latest toast by key**: Super+Shift+N opens / Super+Shift+X dismisses the newest | S |
| ★ | **Improve the side panel (notifications / calendar / etc.)** (suggestion): a pass over Super+N instead of a separate dashboard. Look at what is cramped or missing in each tab (Home, Calendar, Phone, notification history) and fix the worst: readability, what is shown first, what could sit on the Home tab (now playing summary, CPU / RAM, next calendar item). Starts with a look at the current panel, then a short list for you to pick from (seen in Caelestia's dashboard) | M |
| ★ | **To-do list**: in the Calendar tab, with due dates shown on the calendar; a plain file so it syncs with your notes | M |

## 9. Games
| | Idea | Size |
|---|---|---|
| ★ | **Real game mode**: Super+G already frees the side buttons; also turn on caffeine, DND, turn off Hyprland animations, show "GAME" in the bar, and pause chosen programs (Ollama, Docker, sync) until it ends (seen in gamer-mode). Steam games switch it on by themselves (window class `steam_app_*`) | S |

## 12. Your apps and hardware
| | Idea | Size |
|---|---|---|
| ★ | **Obsidian quick capture**: launcher "/note text" appends to today's daily note; vault git status and a Sync button (seen in obsidian) | S-M |
| ★ | **Home Assistant panel**: lights and scenes as buttons in the side panel through HA's REST API (a long-lived token in the state dir, never in the repo) | M |
| ★ | **3D printer**: progress and time left in the bar while the K2 prints (only if it exposes a Moonraker / HTTP API; check first) | M |
| ★ | **Discord voice**: who's in your voice channel, who's speaking, mute / deafen from the bar (check that Vesktop exposes it first) (seen in discord-voice) | M |

## 13. Theming and retro look
| | Idea | Size |
|---|---|---|
| ★ | **Monaco 14 / 11 → 16 / 12** in the launcher search and tucked labels (they break the font rule today) | S |
| ★ | **Character Map**: browse and copy the Material Symbols icons by name, shows the `\uXXXX` code (handy for building the shell itself) | S |
| ★ | **Win95 lock screen**: a Quickshell lock (WlSessionLock) that looks like the "Welcome to Windows" password box | L |
| ★ | **Login screen**: a Quickshell greeter for greetd in the same style, so the look starts before you log in | L |

## 14. The repo itself
| | Idea | Size |
|---|---|---|
| ★ | **Test install in a container**: run `install.sh --dry-run` on a clean Artix image in Docker | M |

## 15. Gimmicks and fun features
Pure fun: nice to have, nothing depends on them.
| | Idea | Size |
|---|---|---|
| ★ | **"It's now safe to turn off your computer"**: the orange-on-black screen for a second at shutdown / reboot | S |
| ★ | **Defrag clean-up**: the Clean-up action shows a Win95 defrag-style block grid while it works | S-M |

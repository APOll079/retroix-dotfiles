# Ideas: top picks (★)

Claude's suggestions, **not picked yet** (except section 0, which is yours). Nothing here is a request until it moves to FEATURES.md "Planned".
The other ideas, the maybes and the rejected list are in `ideas-other.md`. Both files use the same sections.

Size: **S** an evening, **M** a session or two, **L** a project. "(seen in ...)" names a Noctalia / DankMaterialShell / Caelestia plugin that does something similar, so you can look at how they did it.

## 0. Fixes you asked for

These three are your requests, not my suggestions. Details are what I could guess from your words; Claude Code should check the real setup first.
| | Idea | Size |
|---|---|---|

## 1. Capture
| | Idea | Size |
|---|---|---|
| ★ | **OBS controls**: start / stop recording, save the replay buffer, from the bar (OBS is installed; an alternative to a separate recorder) (seen in obs-control) | S |

## 2. System health
| | Idea | Size |
|---|---|---|
| ★ | **Backups**: a scheduled `restic` (or borg) backup of home to the NAS, last-backup time in the Start menu, a toast if it's older than a week | M |
| ★ | **Event hooks**: run your own scripts on events (monitor plugged in, Bluetooth device connected, a game started, theme changed) (seen in Dank Hooks (DMS)) | M |

## 5. Launcher
| | Idea | Size |
|---|---|---|

## 8. Side panel, notifications, calendar and phone
| | Idea | Size |
|---|---|---|
| ★ | **Notification sounds**: per-app on/off, one quiet sound (see "Sounds" for the asset rule), and optionally a different sound for messages from chosen people (seen in contact-sounds) | S |
| ★ | **Improve the side panel (notifications / calendar / etc.)** (suggestion): a pass over the side panel (bell + clock button) instead of a separate dashboard. Look at what is cramped or missing in each tab (Home, Calendar, Phone, notification history) and fix the worst: readability, what is shown first, what could sit on the Home tab (now playing summary, CPU / RAM, next calendar item). Starts with a look at the current panel, then a short list for you to pick from (seen in Caelestia's dashboard) | M |

## 9. Games
| | Idea | Size |
|---|---|---|

## 12. Your apps and hardware
| | Idea | Size |
|---|---|---|
| ★ | **Home Assistant panel**: lights and scenes as buttons in the side panel through HA's REST API (a long-lived token in the state dir, never in the repo) | M |
| ★ | **3D printer**: progress and time left in the bar while the K2 prints (only if it exposes a Moonraker / HTTP API; check first) | M |
| ★ | **Discord voice**: who's in your voice channel, who's speaking, mute / deafen from the bar (check that Vesktop exposes it first) (seen in discord-voice) | M |

## 13. Theming and retro look
| | Idea | Size |
|---|---|---|
| ★ | **Character Map**: browse and copy the Material Symbols icons by name, shows the `\uXXXX` code (handy for building the shell itself) | S |

## 14. The repo itself
| | Idea | Size |
|---|---|---|
| ★ | **Test install in a container**: run `install.sh --dry-run` on a clean Artix image in Docker | M |

## 15. Gimmicks and fun features
Pure fun: nice to have, nothing depends on them.
| | Idea | Size |
|---|---|---|

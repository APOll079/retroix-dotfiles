# Retroix

A retro Hyprland desktop: Win95 bevels and classic-Mac Platinum details on **Artix Linux (dinit)**. Everything you see besides app windows (bar, menus, launcher, notifications, Spotify player, Task Manager) is [Quickshell](https://quickshell.org) (QML), and one palette file recolours the whole system.

![Bar and side panel](screenshots/panel.png)

> This is my personal desktop, shared as-is. It works on my machine; read [Before you install](#before-you-install) for what it assumes.

## What's in it

**Bar**: workspaces, Start and Themes menus, Wallpapers / Services buttons, the current Spotify lyric line, CPU / GPU / RAM (click: Task Manager, right click: temperatures), caffeine, Bluetooth, tray, weather + clock (right click: Do Not Disturb).

| | |
|---|---|
| **Launcher** (Super+D) | Apps (fuzzy, usage-ranked, pins), calculator, session actions, window search, Games tab with cover art, clipboard history with previews |
| **Spotify panel** (Super+S) | Player, Recent, your whole library with folders and pins, search, queue, synced lyrics. Works with the Spotify app or headless through `spotifyd` |
| **Side panel** (Super+N) | Power buttons, audio output / EQ presets / mic / per-app volume, full-height notification history, calendar, phone (KDE Connect) |
| **Task Manager** (Ctrl+Shift+Esc) | A real window: Apps, Processes (grouped by program), Performance graphs |
| **Snipping tool** (Super+Shift+S, Print) | Region, window, screen, all monitors; a history viewer (Super+Shift+H) |
| **And** | Themed notifications with inline reply, screen-share picker, keybind cheat sheet (Super+F1), Bluetooth menu, dinit services panel, wallpaper browser |

**Theme manager**: one palette file (`quickshell/theme/themes.json`) recolours kitty, Hyprland, hyprlock, fish, btop, fastfetch, the emoji picker, GTK apps (theme and icons), Qt apps (through qt6ct), VSCodium and Zen in one go. It can also build a palette from your wallpaper.

## Before you install

It's built for one machine. Expect to edit:

- **Monitors**: `hypr/monitors.lua` and the workspace rules in `hypr/binds.lua` name two outputs (`DP-1` on top, `DP-2` main with workspaces 1-4). Change them to yours (`hyprctl monitors`).
- **Keyboard**: Swedish layout (`se`) in `hypr/inputs.lua`.
- **Sensors**: the CPU / GPU readout looks for an AMD CPU and GPU (hwmon names).
- **Hyprland 0.56+ with the Lua config**: the `hypr/*.lua` files don't work on the old config language.
- **Artix + dinit**: services are dinit units and the tools are `doas`, `yay` and fish. Other distros will need the package names and service setup adjusted.
- **Fonts**: Monaco and Charcoal are proprietary and not included (see [Fonts](#fonts)).

## Install

```sh
git clone https://github.com/APOll079/retroix-dotfiles.git
cd retroix-dotfiles
bash install.sh --dry-run   # read what it would do first
bash install.sh
```

`install.sh` is safe to re-run and never deletes anything. It:

1. installs the package lists in `packages/` (pacman, then the AUR with `yay`, then Flatpak). If `yay` is missing it builds `yay-bin` first; on a doas-only system it uses `PACMAN_AUTH=doas` and `yay --sudo doas --save` (not yet tried on a real reinstall);
2. copies the configs to `~/.config`, backing up what it overwrites to `~/config-backup-<date>/`;
3. enables the dinit services in `packages/services-dinit.txt`;
4. stops mako and dunst from taking notifications (Quickshell owns them);
5. checks that the locale is UTF-8;
6. copies the GTK and icon themes from `themes/` and `icons/` to `~/.local/share` (only folders that aren't there yet);
7. recolours the GTK theme into `QsRetro` / `QsRetroIcons` and writes the other colour files (`apply.py`);
8. reminds you to run `spotifyd authenticate` once.

It asks before installing Flatpak apps, pointing GTK at the theme, and setting up greetd autologin with a lock at login (default **no**; test `hyprlock` from a second TTY first).

The lists in `packages/` are plain text: comment a line out with `#` to skip it. Each has an "apps I use" section you can trim.

**Updating later**: edit the repo, run `bash install.sh` again (it only copies what changed), then `hyprctl reload` and restart Quickshell (`pkill quickshell; quickshell &`).

## Fonts

Not in this repo (proprietary):

- **Monaco**: put `Monaco.ttf` in `~/.config/quickshell/fonts/` *and* `~/.local/share/fonts/` (kitty and hyprlock use it too). `install.sh` doesn't check for it.
- **Charcoal**: put `Charcoal.ttf` in `~/.config/quickshell/fonts/` (menu titles).

Included: Liberation Sans (with its licence) and Material Symbols (the icons).

## Main keys

| Key | Does |
|---|---|
| Super+D | Launcher |
| Super+S | Spotify panel |
| Super+N | Side panel (notifications, audio, calendar, phone) |
| Super+V | Clipboard history |
| Super+Tab | Window switcher |
| Super+Shift+S, Print | Snipping tool (Shift+Print: instant full screenshot) |
| Super+Shift+R | Record the screen (the snipping overlay with Record on); again stops |
| Super+Alt+R, Super+Alt+S | Replay buffer on / off, save the last seconds as a clip |
| Super+Alt+L | Lyrics window (small, pinned, follows the song) |
| (History panel) type, Ctrl+C, Ctrl+O | Filter shots, copy, open the selected shot |
| Super+Shift+H | Screenshot history |
| Ctrl+Shift+Esc | Task Manager |
| Super+Shift+G | Games |
| Super+Q | Close the open menu, else the window |
| Super+F1 | Every key (read from `hypr/binds.lua`) |

Windows move with Super+drag or the mouse's side buttons; Super+G turns the side buttons off for games.

## Extras outside this repo

- **Spotify panel**: needs Spotify Premium and your own (free) Spotify developer app; Super+S walks you through it once. For folders and pins, enable the Spicetify extension: `spicetify config extensions qs-folders.js && spicetify apply`.
- **App themes**: VSCodium (restart, then Ctrl+K Ctrl+T > "Retro (quickshell)"; run "Developer: Reload Window" after a theme switch) and Zen (add `@import "/home/<you>/.config/zen-qs/theme.css";` to your profile's `chrome/userChrome.css` and set `toolkit.legacyUserProfileCustomizations.stylesheets` to true). Best guesses at what each app reads; expect to fix a variable or two.
- **Qt apps (VLC etc.)**: install `qt6ct`, log out and in once (`hypr/env.lua` sets `QT_QPA_PLATFORMTHEME=qt6ct`), then in qt6ct pick Style "Fusion" and Color scheme "qsretro".
- **Wallpapers**: the browser lists `~/Pictures/wallpapers`; `~/Pictures/wallpaper.png` is the lock screen's fallback. Profile picture: `~/Pictures/profile.PNG`.

## Docs

| File | For |
|---|---|
| [`MAINTENANCE.md`](MAINTENANCE.md) | Plain-English upkeep: updates, rollback, where to look when something breaks |
| [`FEATURES.md`](FEATURES.md) | What exists, what's planned, what still needs a live test |
| [`docs/`](docs) | How each part works: [`desktop.md`](docs/desktop.md), [`spotify.md`](docs/spotify.md), [`theming.md`](docs/theming.md) |
| [`CLAUDE.md`](CLAUDE.md) | Design and code rules for AI assistants working on this repo |

## Credits

- The Quickshell shell started from the Quickshell frontend of [linux-retroism](https://github.com/diinki/linux-retroism) by diinki and has since been rebuilt for this desktop.
- The GTK theme **ClassicPlatinumStreamlined** and the icon theme **RetroismIcons** are from linux-retroism (MIT licence, `themes/LICENSE-linux-retroism`), stored unmodified in `themes/` and `icons/` (upstream commit `255eb6a`). `install.sh` copies them to `~/.local/share`; the theme manager recolours a copy (`QsRetro`), never the original.
- Liberation Sans: SIL Open Font License (`quickshell/fonts/LiberationSans-LICENSE.txt`). Material Symbols: Google, Apache 2.0.

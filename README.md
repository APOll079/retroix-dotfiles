# pawtix dotfiles
![Side panel and bar](screenshots/panel.png)

A retro, Win95 / classic-Mac flavoured Hyprland desktop for **Artix Linux (dinit)**.
Bevels, solid title bars, dense rows, chunky icons: everything you see besides app windows is
[Quickshell](https://quickshell.org) (QML).

- **Bar**: workspaces, Start / Themes menus, Wallpapers / Services buttons, a Spotify lyric line, CPU / GPU / RAM monitor (click: Task Manager, right click:
  temperatures), Bluetooth, tray, weather + clock (right click: Do Not Disturb).
- **Launcher** (Super+D): apps, calculator, session actions, window search, Games tab, clipboard history.
- **Spotify panel** (Super+S): player, Recent, your whole library with folders and pins, lyrics.
  Works with the Spotify app or headless through `spotifyd`.
- **Task Manager** (Ctrl+Shift+Esc; a real window), snipping tool (Super+Shift+S), notifications with a full-height history,
  EasyEffects preset buttons (`audio.eqPresets` in settings.json), screen-share picker, cheat sheet (Super+F1), Bluetooth, KDE Connect, dinit services panel.
- **Theme manager**: one palette file (`quickshell/theme/themes.json`) recolours kitty, Hyprland,
  hyprlock, fish, btop, fastfetch, the emoji picker, GTK apps (theme and icons), VSCodium and Zen in one go
  (`quickshell/theme/apply.py`, run by Quickshell on a theme change; also `python3 ~/.config/quickshell/theme/apply.py dusty`).

## Install (fresh Artix + dinit)

```sh
git clone https://github.com/APOll079/pawtix-dotfiles.git
cd pawtix-dotfiles
bash install.sh --dry-run   # read what it would do first
bash install.sh
```

`install.sh` is safe to re-run and never deletes anything. It:

1. installs the package lists in `packages/` (pacman, then the AUR with `yay`, then Flatpak). If `yay` is missing it builds `yay-bin` first; on a doas-only system that uses `PACMAN_AUTH=doas` and `yay --sudo doas --save` (not yet tried on a real reinstall);
2. copies the configs to `~/.config` (files it overwrites are backed up to `~/config-backup-<date>/`);
3. enables the dinit services listed in `packages/services-dinit.txt`;
4. stops mako and dunst from grabbing notifications (Quickshell owns them);
5. checks the locale is UTF-8;
6. copies the GTK and icon themes from `themes/` and `icons/` to `~/.local/share` (only folders
   that aren't there yet);
7. recolours the GTK theme into `QsRetro` / `QsRetroIcons` from the active palette and writes the other colour files (`apply.py`), and asks before pointing GTK at them (gsettings);
8. prints `run 'spotifyd authenticate' once` after enabling spotifyd.

It asks first before installing Flatpak apps, linking the GTK theme, and setting up autologin with greetd plus locking at login (default **no**:
test `hyprlock` from a second TTY first).

The lists in `packages/` are plain text: comment a line out with `#` to skip it. Each file has a
separate "apps I use" section you can trim.

## Deploy changes

After editing this folder, copy it over again: `bash install.sh` (it only copies what changed),
then `hyprctl reload` and restart Quickshell (`pkill quickshell; quickshell &`).

## Fonts you have to get yourself

These are proprietary, so they are not in this repo:

- **Monaco**: put `Monaco.ttf` in `~/.config/quickshell/fonts/` *and* `~/.local/share/fonts/`
  (kitty and hyprlock use it too). `install.sh` does not check or copy it: do it by hand.
- **Charcoal**: put `Charcoal.ttf` in `~/.config/quickshell/fonts/` (menu titles).

Bundled here: Liberation Sans (with its licence) and Material Symbols (the icons).

## Themes and icons

The GTK theme **ClassicPlatinumStreamlined** and the icon theme **RetroismIcons** come from
[linux-retroism](https://github.com/diinki/linux-retroism) by diinki (MIT licence, see
`themes/LICENSE-linux-retroism`). They are stored unmodified in this repo (`themes/` and `icons/`,
copied from upstream commit `255eb6a`); `install.sh` copies them into `~/.local/share/themes/` and
`~/.local/share/icons/`, leaving a folder that is already there alone. The GTK theme is then recoloured with the active palette into a copy called
`QsRetro` (the original is never touched), so GTK apps follow the theme manager too.

## App themes

VSCodium and Zen follow the active theme too. The theme manager writes
a CSS / colour file for each app that is installed, and you switch each one on once:

- **VSCodium**: restart it, then Ctrl+K Ctrl+T > "Retro (quickshell)". After a theme switch run "Developer: Reload Window".
- **Zen**: add `@import "/home/<you>/.config/zen-qs/theme.css";` to your profile's
  `chrome/userChrome.css`, and set `toolkit.legacyUserProfileCustomizations.stylesheets` to true.

These are best guesses at what each app reads, so expect to fix a variable name or two.

## Also outside this repo

- **Spotify panel**: needs Spotify Premium and your own Spotify developer app (free). Super+S
  walks you through it once. For folders and pins, also enable the Spicetify extension:
  `spicetify config extensions qs-folders.js && spicetify apply`.
- Wallpapers: the browser (Themes > Wallpapers...) lists `~/Pictures/wallpapers`. `~/Pictures/wallpaper.png` is the lock screen's fallback background (`hypr/hyprlock.conf`). Profile picture: `~/Pictures/profile.PNG`.

## Docs

- `MAINTENANCE.md`: plain-English upkeep guide (updates, what to check when something breaks).
- `FEATURES.md`: what exists and what's planned.
- `CLAUDE.md`: the design rules and a detailed map of everything.
- `docs/`: how each part works (`desktop.md`, `spotify.md`, `theming.md`); `CLAUDE.md` says which file covers what.

The Quickshell shell started from the Quickshell frontend of [linux-retroism](https://github.com/diinki/linux-retroism) and has since been rebuilt for this desktop.

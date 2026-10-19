.pragma library

// Pure helpers for WallpaperState (kept here so they can be tested without a compositor).

// Jobs [[monitor, path, fit], ...] for the saved monitors that still need their wallpaper.
//   saved:        { "DP-2": { path, fit }, ... } (wallpaper.json)
//   applied:      { "DP-2": true } monitors hyprpaper already accepted this session
//   pendingNames: monitors a running send already covers
//   connected:    output names Quickshell lists right now
//   all:          true at start = every saved monitor, even if the screen list is still incomplete
//                 (it is not a reliable "is plugged in" test that early); false later = only plugged-in ones
function restoreJobs(saved, applied, pendingNames, connected, all) {
    return Object.keys(saved)
        .filter(m => m !== "" && saved[m] && saved[m].path && !applied[m] && pendingNames.indexOf(m) === -1
            && (all || connected.indexOf(m) !== -1))
        .map(m => [m, saved[m].path, saved[m].fit || "cover"]);
}

// Which failed monitors deserve a visible "gave up" message. A user's Set: all of them. The start-up
// restore: only monitors that are plugged in, so a saved but unplugged output stays quiet.
function reportable(failedNames, connected, restoring) {
    return restoring ? failedNames.filter(n => connected.indexOf(n) !== -1) : failedNames;
}

// "MON|message" lines from the setter shell loop -> { MON: message }
function parseFailures(text) {
    const failed = {};
    for (const line of text.split("\n")) {
        const i = line.indexOf("|");
        if (i > 0)
            failed[line.slice(0, i)] = line.slice(i + 1).trim();
    }
    return failed;
}

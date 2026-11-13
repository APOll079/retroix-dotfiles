.pragma library

// The Settings tab's data and pure helpers (no QML, no Config: every function takes the settings object as an
// argument, so tests run them on fixtures). One schema entry per setting in Config.settings:
//   { category, path: "idle.dimMinutes", type: "bool"|"int"|"string"|"list"|"choice"|"json-note",
//     label, hint, min, max, choices: [...] | choicesFrom: "themes", restart: bool }
//   type "action" = no setting: a row with an Open button that opens a tool (action: an id Bar.qml's toolActions knows); its path is "action:<id>"
// A new setting in Config.qml needs one line here (tests/interaction/settingsview.qml fails until it has one).
// json-note = no control suited (a list of objects): the row only says "Edit in settings.json".

var CATEGORIES = ["General", "Bar", "Appearance", "Notifications", "Audio", "Idle and power", "Recording", "Watchers", "Weather", "Games and extras", "System tools"];

function act(id, label, hint) {
    return e("System tools", "action:" + id, "action", label, hint, { action: id });
}

function e(category, path, type, label, hint, extra) {
    var o = { category: category, path: path, type: type, label: label, hint: hint, restart: false };
    if (extra)
        for (var k in extra)
            o[k] = extra[k];
    return o;
}

var SCHEMA = [
    e("General", "execCommands.terminal", "string", "Terminal", "Command that opens a terminal (kitty, foot, ...)"),
    e("General", "execCommands.files", "string", "File manager", "Command that opens the file manager"),
    e("General", "execCommands.terminalClassFlag", "string", "Terminal class flag", "How the terminal names its window: --class, --app-id, or empty"),
    e("General", "militaryTimeClockFormat", "bool", "24-hour clock", "Off shows 12-hour time"),
    e("General", "systemProfileImageSource", "string", "Profile picture", "Image path shown in the side panel (~ allowed)"),
    e("General", "systemDetails.osName", "string", "OS name", "Shown in the system info"),
    e("General", "systemDetails.osVersion", "string", "OS version", "Shown in the system info"),
    e("General", "systemDetails.cpu", "string", "CPU name", "Shown in the system info"),
    e("General", "systemDetails.gpu", "string", "GPU name", "Shown in the system info"),
    e("General", "systemDetails.ram", "string", "RAM", "Shown in the system info"),

    e("Bar", "bar.fontSize", "int", "Bar font size", "Pixels", { min: 8, max: 32 }),
    e("Bar", "bar.trayIconSize", "int", "Tray icon size", "Pixels", { min: 12, max: 48 }),
    e("Bar", "bar.monochromeTrayIcons", "bool", "Monochrome tray icons", "Tint tray icons with the theme text colour"),

    e("Appearance", "currentTheme", "choice", "Theme", "The colour palette", { choicesFrom: "themes" }),
    e("Appearance", "ui.cascadingStart", "bool", "Cascading Start menu", "Adds a Programs button to the Start menu that opens categories and apps as cascading menus"),
    e("Appearance", "ui.dither", "bool", "Dither on meters", "Off gives flat empty tracks"),
    e("Appearance", "ui.reduceMotion", "bool", "Reduce motion", "Turns every animation off"),

    e("Notifications", "notifications.position", "choice", "Toast position", "Where toasts appear", { choices: ["top-right", "top-left", "top", "bottom-right", "bottom-left", "bottom"] }),
    e("Notifications", "notifications.maxVisible", "int", "Toasts at once", "Stack limit", { min: 1, max: 20 }),
    e("Notifications", "notifications.monitor", "string", "Toast monitor", "Output name (DP-2), focused, or empty for the default"),
    e("Notifications", "notifications.dnd", "bool", "Do not disturb", "Hold toasts back; the history keeps them"),
    e("Notifications", "notifications.dndWhileSharing", "bool", "Hold toasts while sharing", "Critical ones still show"),
    e("Notifications", "notifications.mutedApps", "list", "Muted apps", "Comma-separated app names, never shown as toasts"),
    e("Notifications", "notifications.priorityApps", "list", "Priority apps", "Comma-separated app names that get through Do Not Disturb"),

    e("Audio", "audio.eqOutputMatch", "string", "EQ output match", "Output name part that turns the EQ on; empty = never"),
    e("Audio", "audio.eqPresets", "list", "EQ presets", "Comma-separated EasyEffects output presets"),
    e("Audio", "audio.rememberAppVolumes", "bool", "Remember app volumes", "Re-apply them when the app plays again"),
    e("Audio", "audio.noisePreset", "string", "Noise filter preset", "EasyEffects preset that switches noise reduction on"),
    e("Audio", "audio.noiseOffPreset", "string", "Noise filter off preset", "EasyEffects preset that switches it off"),
    e("Audio", "osd.volume", "bool", "Volume popup", "Show the volume OSD"),
    e("Audio", "osd.bluetooth", "bool", "Bluetooth popup", "Show the Bluetooth OSD"),

    e("Idle and power", "screensaver.enabled", "bool", "Screensaver", "Blank the screen with a Win95 screensaver when idle"),
    e("Idle and power", "screensaver.minutes", "int", "Screensaver after", "Minutes, 0 = off. Keep it below the dim and lock times", { min: 0, max: 600 }),
    e("Idle and power", "screensaver.style", "choice", "Screensaver style", "starfield, pipes, mystify or random; pipes3d is the real xscreensaver pipes (needs the xscreensaver package)", { choices: ["starfield", "pipes", "pipes3d", "mystify", "random"] }),
    e("Idle and power", "idle.enabled", "bool", "Idle handling", "Dim, lock and turn the screens off"),
    e("Idle and power", "idle.dimMinutes", "int", "Dim after", "Minutes, 0 = off", { min: 0, max: 600 }),
    e("Idle and power", "idle.lockMinutes", "int", "Lock after", "Minutes, 0 = off", { min: 0, max: 600 }),
    e("Idle and power", "idle.screenOffMinutes", "int", "Screens off after", "Minutes, 0 = off", { min: 0, max: 600 }),
    e("Idle and power", "idle.stayAwakeInFullscreen", "bool", "Stay awake in fullscreen", "No dim or lock while a fullscreen video or game is up"),
    e("Idle and power", "idle.stayAwakeApps", "list", "Fullscreen apps that keep awake", "Comma-separated app id patterns (regex): Steam games, .exe, gamescope, mpv, vlc, zen"),
    e("Idle and power", "session.countdownSeconds", "int", "Reboot countdown", "Seconds before reboot or shutdown, 0 = off", { min: 0, max: 60 }),
    e("Idle and power", "session.customActions", "json-note", "Custom session actions", "A list of name, icon and command"),

    e("Recording", "record.dir", "string", "Recording folder", "Where clips go (~ allowed)"),
    e("Recording", "record.replaySeconds", "int", "Replay buffer", "Seconds the replay buffer keeps", { min: 5, max: 600 }),

    e("Watchers", "memoryWatch.enabled", "bool", "Memory warning", "Toast when RAM or /tmp runs high"),
    e("Watchers", "memoryWatch.ramPercent", "int", "RAM limit", "Percent used", { min: 1, max: 100 }),
    e("Watchers", "memoryWatch.tmpGb", "int", "/tmp limit", "Gigabytes of RAM-backed /tmp", { min: 1, max: 256 }),
    e("Watchers", "memoryWatch.cooldownMinutes", "int", "Memory cooldown", "Minutes between two toasts", { min: 1, max: 1440 }),
    e("Watchers", "diskWatch.enabled", "bool", "Disk warning", "Toast when a mount fills up"),
    e("Watchers", "diskWatch.percent", "int", "Disk limit", "Percent used", { min: 1, max: 100 }),
    e("Watchers", "diskWatch.cooldownMinutes", "int", "Disk cooldown", "Minutes before it warns again", { min: 1, max: 1440 }),
    e("Watchers", "diskWatch.mounts", "list", "Disk mounts", "Comma-separated paths to watch (~ allowed)"),
    e("Watchers", "nas.enabled", "bool", "NAS watch", "Show NAS mount state in the bar"),
    e("Watchers", "nas.mounts", "list", "NAS mounts", "Comma-separated mount paths"),
    e("Watchers", "nas.intervalSeconds", "int", "NAS check every", "Seconds", { min: 5, max: 3600 }),
    e("Watchers", "downloads.enabled", "bool", "Download toast", "Toast when a download finishes"),
    e("Watchers", "downloads.intervalSeconds", "int", "Download check every", "Seconds", { min: 1, max: 300 }),
    e("Watchers", "networkWatch.enabled", "bool", "Network toasts", "Link up / down and ping results"),
    e("Watchers", "networkWatch.hosts", "list", "Ping hosts", "Comma-separated names or IPs; empty = link only"),
    e("Watchers", "networkWatch.cooldownSeconds", "int", "Network cooldown", "Seconds between toasts of one kind", { min: 0, max: 3600 }),
    e("Watchers", "networkWatch.vpn", "bool", "VPN status", "Poll the VPN for the bar button"),
    e("Watchers", "securityAudit.enabled", "bool", "Security audit", "Toast on a new vulnerability (arch-audit)"),
    e("Watchers", "securityAudit.intervalHours", "int", "Audit every", "Hours", { min: 1, max: 168 }),

    e("Watchers", "networkPage.speedTestUrl", "string", "Speed test file", "The file the Network page's Speed test downloads (only when you press the button)"),
    e("Weather", "weather.location", "string", "Location", "Empty = guessed from your IP"),
    e("Weather", "weather.metric", "bool", "Metric units", "Off shows Fahrenheit and mph"),

    e("Games and extras", "games.flatpakApps", "list", "Flatpak games", "Comma-separated Flatpak app ids"),
    e("Games and extras", "games.mangohud", "bool", "MangoHud", "Overlay for games launched from here"),
    e("Games and extras", "spotifyExtras.trackToast", "bool", "Track toast", "A toast on every song change"),
    e("Games and extras", "mouse.enabled", "bool", "Mouse battery", "Show the Logitech battery (Solaar) in the bar"),
    e("Games and extras", "wallpaper.folder", "string", "Wallpaper folder", "Folder the wallpaper browser lists (~ allowed)"),

    // Tools that used to be buttons in the Start menu (rarely used): each opens its panel, as the Start button did
    act("defaultApps", "Default apps", "Choose the default browser, image viewer, video player"),
    act("network", "Network", "Addresses, ping, LAN devices, speed test (the ETH button in the bar opens it too)"),
    act("services", "Services", "Start, stop and restart dinit services"),
    act("troubleshoot", "Troubleshoot", "Restart PipeWire, the portals, hyprpaper or EasyEffects"),
    act("loginReport", "Login report", "What slowed your last login"),
    act("cleanUp", "Clean up", "Free space: package cache, orphans, unused Flatpak runtimes"),
    act("colours", "Colours", "The colours you picked with the colour picker"),
    act("updates", "Updates", "Pending updates, news and the update buttons (Start shows it while updates wait)")
];

// Categories in schema order (CATEGORIES first, then any a later agent adds).
function categories(schema) {
    var out = [];
    for (var i = 0; i < CATEGORIES.length; i++)
        for (var j = 0; j < schema.length; j++)
            if (schema[j].category === CATEGORIES[i]) {
                out.push(CATEGORIES[i]);
                break;
            }
    for (var k = 0; k < schema.length; k++)
        if (out.indexOf(schema[k].category) < 0)
            out.push(schema[k].category);
    return out;
}

function entriesFor(schema, category) {
    return schema.filter(function (s) { return s.category === category; });
}

// Case-insensitive substring over label, hint and path; an empty query matches nothing.
function search(schema, query) {
    var q = String(query || "").trim().toLowerCase();
    if (q === "")
        return [];
    return schema.filter(function (s) {
        return (s.label + "\n" + s.hint + "\n" + s.path).toLowerCase().indexOf(q) >= 0;
    });
}

// "a, b" -> ["a","b"]: trimmed, empty items dropped, empty text -> []
function parseList(text) {
    return String(text || "").split(",").map(function (s) { return s.trim(); }).filter(function (s) { return s !== ""; });
}

function listText(array) {
    return (array || []).join(", ");
}

function rangeText(min, max) {
    if (min !== undefined && max !== undefined)
        return min + " to " + max;
    return min !== undefined ? min + " or more" : (max !== undefined ? max + " or less" : "a number");
}

// Digits only (a leading minus only when min < 0), then the range. -> { ok, value, message }
function parseIntRange(text, min, max) {
    var t = String(text).trim();
    var allowNeg = min !== undefined && min < 0;
    var re = allowNeg ? /^-?\d+$/ : /^\d+$/;
    if (!re.test(t))
        return { ok: false, value: 0, message: "Enter a whole number" + (allowNeg ? "" : " (0 or more)") };
    var v = Number(t);
    if ((min !== undefined && v < min) || (max !== undefined && v > max))
        return { ok: false, value: v, message: "Must be " + rangeText(min, max) };
    return { ok: true, value: v, message: "" };
}

// The text of a field -> the value to store, per the entry's type. -> { ok, value, message }
function fromText(entry, text) {
    if (entry.type === "int")
        return parseIntRange(text, entry.min, entry.max);
    if (entry.type === "list")
        return { ok: true, value: parseList(text), message: "" };
    return { ok: true, value: String(text), message: "" };
}

// A stored value -> the text shown in its field.
function toText(entry, value) {
    if (entry.type === "list")
        return listText(value);
    return value === undefined || value === null ? "" : String(value);
}

function sameValue(a, b) {
    if (Array.isArray(a) || Array.isArray(b))
        return JSON.stringify(a) === JSON.stringify(b);
    return a === b;
}

function valueOf(settings, path) {
    var parts = path.split(".");
    var o = settings;
    for (var i = 0; i < parts.length; i++) {
        if (o === undefined || o === null)
            return undefined;
        o = o[parts[i]];
    }
    return o;
}

// Assigns settings.<group>.<key> = value (a fresh array for lists, so the adapter sees a change). false if the group is missing.
function setValue(settings, path, value) {
    var parts = path.split(".");
    var o = settings;
    for (var i = 0; i < parts.length - 1; i++)
        o = o ? o[parts[i]] : undefined;
    if (o === undefined || o === null)
        return false;
    o[parts[parts.length - 1]] = Array.isArray(value) ? value.slice() : value;
    return true;
}

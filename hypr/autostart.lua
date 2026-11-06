---@module 'hl'
-- =========================
-- AUTOSTART
-- =========================
-- Login timestamps for Start > Login report: one line "<epoch-ms> <name>" per step in $XDG_RUNTIME_DIR/qs-login-times.
-- They mark when each step was LAUNCHED (the file is emptied at "session-start"), so a long gap means the launching
-- of the next step waited on something; scripts/loginreport.py turns the lines into the report.
local function mark(name)
    hl.exec_cmd("sh -c 'echo \"$(date +%s%3N) " .. name .. "\" >> \"$XDG_RUNTIME_DIR/qs-login-times\"'")
end

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c ': > \"$XDG_RUNTIME_DIR/qs-login-times\"'")
    mark("session-start")
    -- Lock first, before anything else starts (greetd autologin: nothing should be usable unlocked), only if ~/.config/hypr/lock-at-login exists (install.sh creates it
    -- when you answer yes; delete the file to turn it off)
    local marker = io.open((os.getenv("HOME") or "") .. "/.config/hypr/lock-at-login", "r")
    if marker then
        marker:close()
        hl.exec_cmd("hyprlock")
    end

    -- Use --all instead of --systemd for Artix/dinit
    hl.exec_cmd("dbus-update-activation-environment --all")

    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    mark("polkit")
    hl.exec_cmd("zen-browser")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("flatpak run com.github.wwmm.easyeffects --gapplication-service")
    hl.exec_cmd("hyprpaper")
    mark("hyprpaper")
    hl.exec_cmd("kdeconnectd")  -- phone link (side panel > Phone tab)
    hl.exec_cmd("xsettingsd")  -- GTK settings for XWayland apps (~/.config/xsettingsd/xsettingsd.conf)
    hl.exec_cmd("quickshell")
    mark("quickshell")
end)

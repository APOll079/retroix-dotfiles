---@module 'hl'

-- =========================
-- MONITORS
-- =========================
-- mainMonitor / topMonitor are the output names that binds.lua puts the workspaces on (and the main one is the monitor at
-- position 0x0, where the login screen puts its box). On a machine with other screens set them in monitors_local.lua.
mainMonitor = "DP-2"
topMonitor = "DP-1"

hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@60",
    position = "0x-1080",
    scale    = 1
})

hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080@165",
    position = "0x0",
    scale    = 1
})

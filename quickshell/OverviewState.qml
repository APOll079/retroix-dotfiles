pragma Singleton
import QtQuick
import Quickshell

// The pure part of the workspace overview (popups/Overview.qml): which cards there are, how they are laid out, how the
// keys move the selection, and the Hyprland commands a click sends. No state, no Hyprland calls: the panel passes plain
// objects in ({ id, name, monitor, active } workspaces, { address, cls, title, wsId, ... } windows), so tests use fixtures.
Singleton {
    id: root

    // A plain workspace from a HyprlandWorkspace (or a fixture, which is returned as it is)
    function wsOf(w) {
        return { id: w.id, name: w.name, monitor: w.monitor ? w.monitor.name : "", active: w.active === true };
    }

    // A plain window from a HyprlandToplevel; `wayland` is the Wayland toplevel the thumbnail captures (may be null).
    // Windows that are not mapped, or on a special workspace (id < 1), have no card and give null.
    function windowOf(t) {
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false)
            return null;
        const wsId = t.workspace ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : -1);
        if (!(wsId >= 1))
            return null;
        return { address: t.address, cls: String(ipc["class"] || ""), title: String(t.title || ""), wsId: wsId, wayland: t.wayland || null };
    }

    // The cards for one monitor: its workspaces (id >= 1) sorted by id, each with its windows (in the order given).
    // A window of a workspace that is not on this monitor appears nowhere. monitorName "*" = every monitor (the panel's
    // fallback when no workspace matches its own screen name, so the overview is never an empty dim).
    function cardsFor(monitorName, workspaces, windows) {
        const mine = (workspaces || []).filter(w => w.id >= 1 && (monitorName === "*" || w.monitor === monitorName)).sort((a, b) => a.id - b.id);
        return mine.map(w => ({
            id: w.id,
            name: String(w.name !== undefined && w.name !== "" ? w.name : w.id),
            active: w.active === true,
            windows: (windows || []).filter(x => x && x.wsId === w.id)
        }));
    }

    // "1 window", "3 windows", "empty"
    function countText(n) {
        return n === 0 ? "empty" : n === 1 ? "1 window" : n + " windows";
    }
    // The card title: "2 - 3 windows"
    function cardTitle(card) {
        return card.name + " - " + root.countText(card.windows.length);
    }

    // n equal cells of the given aspect (w / h) in W x H with `gap` between: the column count that makes the cells biggest.
    // Returns { cols, rows, cellW, cellH, x, y } (x, y: the offset that centres the whole grid in the area). The cell is
    // never bigger than maxW wide (0 = no limit), so one or two cards do not fill the screen.
    function gridFit(n, W, H, gap, aspect, maxW) {
        if (!(n > 0) || !(W > 0) || !(H > 0))
            return { cols: 1, rows: 1, cellW: 0, cellH: 0, x: 0, y: 0 };
        let best = null;
        for (let cols = 1; cols <= n; cols++) {
            const rows = Math.ceil(n / cols);
            const availW = (W - (cols - 1) * gap) / cols, availH = (H - (rows - 1) * gap) / rows;
            let cw = Math.min(availW, availH * aspect);
            if (maxW > 0)
                cw = Math.min(cw, maxW);
            cw = Math.max(0, Math.floor(cw));
            const ch = Math.floor(cw / aspect);
            // the biggest cell wins; on a tie the squarer grid (fewer empty slots)
            const empty = cols * rows - n;
            if (best === null || cw > best.cellW || (cw === best.cellW && empty < best.empty))
                best = { cols: cols, rows: rows, cellW: cw, cellH: ch, empty: empty };
        }
        const gw = best.cols * best.cellW + (best.cols - 1) * gap, gh = best.rows * best.cellH + (best.rows - 1) * gap;
        return { cols: best.cols, rows: best.rows, cellW: best.cellW, cellH: best.cellH, x: Math.floor((W - gw) / 2), y: Math.floor((H - gh) / 2) };
    }

    // The top-left of cell `i` of a grid from gridFit (the last row is centred when it is not full)
    function cellPos(i, n, fit, gap) {
        const row = Math.floor(i / fit.cols), col = i % fit.cols;
        const inRow = row === fit.rows - 1 ? n - row * fit.cols : fit.cols;
        const rowW = inRow * fit.cellW + (inRow - 1) * gap, fullW = fit.cols * fit.cellW + (fit.cols - 1) * gap;
        return { x: fit.x + Math.floor((fullW - rowW) / 2) + col * (fit.cellW + gap), y: fit.y + row * (fit.cellH + gap) };
    }

    // Arrow keys on a grid of `count` cards in `cols` columns: Left / Right stay inside the row, Up / Down inside the
    // grid; a move that has nowhere to go stays. "Home" / "End" jump to the first / last. Returns the new index.
    function moveSelection(index, key, cols, count) {
        if (count <= 0)
            return -1;
        const i = Math.max(0, Math.min(count - 1, index));
        const col = i % cols;
        switch (key) {
        case "left":
            return col > 0 ? i - 1 : i;
        case "right":
            return col < cols - 1 && i + 1 < count ? i + 1 : i;
        case "up":
            return i - cols >= 0 ? i - cols : i;
        case "down":
            return i + cols < count ? i + cols : i;
        case "home":
            return 0;
        case "end":
            return count - 1;
        }
        return i;
    }

    // The index of the card to start on: the active workspace, else the first
    function startIndex(cards) {
        const i = cards.findIndex(c => c.active);
        return i >= 0 ? i : 0;
    }

    // The Hyprland commands, in the same style as taskbar/Workspaces.qml and popups/FindWindow.qml. The address is checked
    // (hex digits only) so a hostile value can never end up inside the command text.
    function workspaceCommand(id) {
        return Number.isInteger(id) && id >= 1 ? "hl.dsp.focus({ workspace = " + id + " })" : "";
    }
    function windowCommand(address) {
        return /^[0-9a-fA-F]+$/.test(String(address)) ? "hl.dsp.focus({ window = \"address:0x" + address + "\" })" : "";
    }
}

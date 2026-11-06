// Tests for the workspace overview's logic (OverviewState.qml): grouping fixture workspaces and windows into cards, the
// card and thumbnail grid layout, the selection moves and the commands a click sends. popups/Overview.qml itself is a
// layer-shell PanelWindow and cannot be created offscreen, so only the pure part is run here (check.py lints the panel).
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: starter.start()
    Timer { id: starter; interval: 300; onTriggered: shell.run() }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }

    function run() {
        const O = OverviewState;
        const J = JSON.stringify;
        const ws = [
            { id: 3, name: "3", monitor: "DP-2", active: false },
            { id: 1, name: "1", monitor: "DP-2", active: true },
            { id: 5, name: "5", monitor: "DP-1", active: true },
            { id: -98, name: "special:spotifyspace", monitor: "DP-2", active: false },
            { id: 2, name: "2", monitor: "DP-2", active: false }
        ];
        const wins = [
            { address: "a1", cls: "kitty", title: "term", wsId: 1 },
            { address: "a2", cls: "zen", title: "web", wsId: 3 },
            { address: "a3", cls: "kitty", title: "second", wsId: 1 },
            { address: "a4", cls: "vlc", title: "on the other monitor", wsId: 5 },
            { address: "a5", cls: "spotify", title: "special", wsId: -98 }
        ];

        // grouping
        const cards = O.cardsFor("DP-2", ws, wins);
        check("cards: this monitor's workspaces only, sorted by id, special ones left out", J(cards.map(c => c.id)) === "[1,2,3]");
        check("cards: windows grouped by workspace, in the given order", J(cards[0].windows.map(w => w.address)) === "[\"a1\",\"a3\"]" && cards[1].windows.length === 0 && J(cards[2].windows.map(w => w.address)) === "[\"a2\"]");
        check("cards: a window of another monitor or a special workspace is on no card", cards.every(c => c.windows.every(w => w.address !== "a4" && w.address !== "a5")));
        check("cards: the active workspace is marked", cards[0].active === true && cards[1].active === false);
        check("cards: the other monitor has its own card", J(O.cardsFor("DP-1", ws, wins).map(c => c.id)) === "[5]" && O.cardsFor("DP-1", ws, wins)[0].windows[0].address === "a4");
        check("cards: an unknown monitor or null lists give no cards", O.cardsFor("HDMI-9", ws, wins).length === 0 && O.cardsFor("DP-2", null, null).length === 0);
        check("cards: the input is not changed", ws[0].id === 3 && ws.length === 5);

        // plain conversion
        const topl = { address: "ff10", title: "<b>t</b>", lastIpcObject: { "class": "kitty", mapped: true, workspace: { id: 2 } }, workspace: { id: 2 }, wayland: "W" };
        const w = O.windowOf(topl);
        check("windowOf: class, title, workspace and the capture handle", w.cls === "kitty" && w.title === "<b>t</b>" && w.wsId === 2 && w.wayland === "W" && w.address === "ff10");
        check("windowOf: falls back to the ipc workspace", O.windowOf({ address: "a", title: "x", lastIpcObject: { "class": "c", workspace: { id: 4 } } }).wsId === 4);
        check("windowOf: an unmapped window or a special workspace gives null", O.windowOf({ address: "a", title: "x", lastIpcObject: { mapped: false, workspace: { id: 1 } } }) === null
              && O.windowOf({ address: "a", title: "x", workspace: { id: -98 } }) === null && O.windowOf({ address: "a", title: "x" }) === null);
        check("wsOf: monitor name and active flag", J(O.wsOf({ id: 2, name: "2", monitor: { name: "DP-1" }, active: true })) === J({ id: 2, name: "2", monitor: "DP-1", active: true }));

        // titles
        check("title: counts", O.countText(0) === "empty" && O.countText(1) === "1 window" && O.countText(4) === "4 windows");
        check("title: card title", O.cardTitle(cards[0]) === "1 - 2 windows" && O.cardTitle(cards[1]) === "2 - empty");

        // grid layout
        const g1 = O.gridFit(1, 1000, 600, 12, 1.6, 0);
        check("grid: one cell takes the most it can in the area, centred", g1.cols === 1 && g1.cellW === 960 && g1.cellH === 600 && g1.x === 20 && g1.y === 0);
        const g1c = O.gridFit(1, 1000, 600, 12, 1.6, 400);
        check("grid: the width cap keeps one card small and centred", g1c.cellW === 400 && g1c.cellH === 250 && g1c.x === 300 && g1c.y === 175);
        const g4 = O.gridFit(4, 1000, 600, 12, 1.6, 0);
        check("grid: 4 cells in a wide area do not overflow it", g4.cols * g4.cellW + (g4.cols - 1) * 12 <= 1000 && g4.rows * g4.cellH + (g4.rows - 1) * 12 <= 600 && g4.cols * g4.rows >= 4);
        check("grid: every count fits in the area, cells keep the aspect", [1, 2, 3, 5, 7, 9, 12, 20].every(n => {
            const f = O.gridFit(n, 1800, 900, 12, 16 / 9, 0);
            return f.cols * f.rows >= n && f.cols * f.cellW + (f.cols - 1) * 12 <= 1800 && f.rows * f.cellH + (f.rows - 1) * 12 <= 900 && f.cellW > 0 && Math.abs(f.cellW / f.cellH - 16 / 9) < 0.05;
        }));
        check("grid: more cells never make the cells bigger", O.gridFit(9, 1800, 900, 12, 16 / 9, 0).cellW <= O.gridFit(4, 1800, 900, 12, 16 / 9, 0).cellW);
        check("grid: a narrow tall area stacks the cells in one column", O.gridFit(3, 300, 1500, 12, 16 / 9, 0).cols === 1);
        check("grid: nothing to lay out is harmless", O.gridFit(0, 100, 100, 12, 1.6, 0).cellW === 0 && O.gridFit(3, 0, 100, 12, 1.6, 0).cellW === 0);

        // cell positions
        const f5 = O.gridFit(5, 1800, 900, 12, 16 / 9, 0);
        const p0 = O.cellPos(0, 5, f5, 12), p1 = O.cellPos(1, 5, f5, 12), pl = O.cellPos(4, 5, f5, 12);
        check("cellPos: the first cell is at the grid origin, the next one a cell and a gap to the right", p0.x === f5.x && p0.y === f5.y && p1.x === p0.x + f5.cellW + 12 && p1.y === p0.y);
        check("cellPos: the last row is centred when it is not full", f5.cols * f5.rows === 5 || pl.x > f5.x);
        check("cellPos: a full last row starts at the origin", (() => {
            const f4 = O.gridFit(4, 1800, 900, 12, 16 / 9, 0);
            return O.cellPos(f4.cols * (f4.rows - 1), 4, f4, 12).x === f4.x;
        })());

        // selection moves (3 columns, 8 cards)
        const mv = (i, k) => O.moveSelection(i, k, 3, 8);
        check("keys: right and left move one, stop at the row ends", mv(0, "right") === 1 && mv(2, "right") === 2 && mv(1, "left") === 0 && mv(0, "left") === 0 && mv(3, "left") === 3);
        check("keys: right stops at the last card", mv(7, "right") === 7 && O.moveSelection(1, "right", 3, 2) === 1);
        check("keys: down and up move a row, stay at the edges", mv(0, "down") === 3 && mv(4, "down") === 7 && mv(6, "down") === 6 && mv(7, "up") === 4 && mv(1, "up") === 1);
        check("keys: down from the last full row into a short one stays when there is nothing under", mv(5, "down") === 5);
        check("keys: home and end", mv(5, "home") === 0 && mv(2, "end") === 7);
        check("keys: an unknown key or an out-of-range index is clamped", mv(1, "x") === 1 && mv(99, "left") === 6);
        check("keys: no cards gives -1", O.moveSelection(0, "right", 3, 0) === -1);
        check("start: the active workspace, else the first", O.startIndex(cards) === 0 && O.startIndex([{ active: false }, { active: true }]) === 1 && O.startIndex([{ active: false }]) === 0 && O.startIndex([]) === 0);

        // commands
        check("command: switch workspace is the Workspaces.qml call", O.workspaceCommand(3) === "hl.dsp.focus({ workspace = 3 })");
        check("command: a bad workspace id sends nothing", O.workspaceCommand(0) === "" && O.workspaceCommand(-98) === "" && O.workspaceCommand("2; x") === "" && O.workspaceCommand(1.5) === "");
        check("command: focus a window is the FindWindow.qml call", O.windowCommand("55d1a0c2") === "hl.dsp.focus({ window = \"address:0x55d1a0c2\" })");
        check("command: a hostile address sends nothing", O.windowCommand("1\" }) os.execute(\"x") === "" && O.windowCommand("") === "" && O.windowCommand(undefined) === "");

        console.log("TEST done failures=" + failures);
        quitTimer.start();
    }
}

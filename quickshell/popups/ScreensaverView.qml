import QtQuick
import ".."

// What a screensaver window shows and how it ends: the blank (outline colour) screen, one of the three styles drawn on a
// Canvas in the theme colours (accent, text, highlight), and the wake-up input. ScreensaverWindow.qml puts one on each
// screen; tests put one in a scratch window. The step functions are ScreensaverState's (pure). With reduce motion
// (`animate` false) the scene is stepped a few times once, painted once and never moves, but the screen still blanks.
// Keys, clicks and the wheel wake at once; a mouse move only after graceMs since startedAt (the cursor's own jitter).
// The wake input is eaten here, never forwarded.
Item {
    id: root

    property string style: "starfield"
    property real startedAt: 0
    property int graceMs: 500
    property bool animate: !MenuStyle.reduceMotion
    readonly property int frameMs: 33
    readonly property int cell: MenuStyle.rowHeight           // a pipe grid cell
    readonly property int pipeHeads: 3
    readonly property int pipeEvery: 3                        // frames per pipe step
    readonly property int polyCount: 2
    readonly property int polyCorners: 4
    readonly property int trailLen: 8
    readonly property int starCount: 160
    readonly property real starSpeed: 0.35                    // z per second
    readonly property int pipeWarm: 60                        // steps painted in the static frame
    // Drawn on Config.colors.outline (dark in every theme), so no entry may be the text colour (dark too: invisible stars,
    // pipes and pipe heads); base and highlight are light in every theme
    readonly property var palette: [MenuStyle.selectBar, Config.colors.base, Config.colors.highlight]

    property var rnd: Math.random
    property var scene: null
    property int frames: 0
    property real lastX: -1
    property real lastY: -1

    signal wake()

    readonly property var state_: ScreensaverState        // (through a var so the singleton's members are not lint errors)
    readonly property Item canvasItem: canvas

    // Does this input end the screensaver? Emits wake() when it does.
    function input(kind) {
        if (!root.state_.wakeDecision(kind, Date.now(), root.startedAt, root.graceMs))
            return false;
        root.wake();
        return true;
    }

    function build() {
        const S = root.state_, w = Math.max(1, root.width), h = Math.max(1, root.height);
        root.frames = 0;
        if (root.style === "pipes") {
            let st = S.initPipes(Math.max(2, Math.floor(w / root.cell)), Math.max(2, Math.floor(h / root.cell)), root.pipeHeads, root.rnd);
            if (!root.animate)
                for (let i = 0; i < root.pipeWarm; i++)
                    st = S.pipeStep(st, root.rnd);
            root.scene = st;
        } else if (root.style === "mystify") {
            let ps = S.initPolys(root.polyCount, root.polyCorners, w, h, root.rnd);
            if (!root.animate)
                ps = ps.map(p => {
                    let q = p;
                    for (let i = 0; i < root.trailLen; i++)
                        q = S.polyStep(q, w, h, 0.25, root.trailLen);
                    return q;
                });
            root.scene = ps;
        } else {
            root.scene = S.initStars(root.starCount, root.rnd);
        }
        canvas.requestPaint();
    }

    // One frame forward (the timer calls this; tests call it directly)
    function tick() {
        const S = root.state_, dt = root.frameMs / 1000;
        root.frames++;
        if (root.style === "pipes") {
            if (root.frames % root.pipeEvery === 0)
                root.scene = S.pipeStep(root.scene, root.rnd);
        } else if (root.style === "mystify") {
            root.scene = root.scene.map(p => S.polyStep(p, root.width, root.height, dt, root.trailLen));
        } else {
            root.scene = S.starStep(root.scene, dt, root.rnd, root.starSpeed);
        }
        canvas.requestPaint();
    }

    onWidthChanged: root.build()
    onHeightChanged: root.build()
    onStyleChanged: root.build()
    onAnimateChanged: root.build()
    Component.onCompleted: root.build()

    Timer {
        interval: root.frameMs
        repeat: true
        running: root.animate && root.visible && root.scene !== null
        onTriggered: root.tick()
    }

    Rectangle {
        anchors.fill: parent
        color: Config.colors.outline
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = String(Config.colors.outline);
            ctx.fillRect(0, 0, width, height);
            if (!root.scene)
                return;
            const pal = root.palette.map(c => String(c));
            if (root.style === "pipes")
                root.paintPipes(ctx, pal);
            else if (root.style === "mystify")
                root.paintPolys(ctx, pal);
            else
                root.paintStars(ctx, pal);
        }
    }

    function paintStars(ctx, pal) {
        const S = root.state_, dt = root.frameMs / 1000;
        for (const s of root.scene) {
            const p = S.starProject(s, root.width, root.height, dt, root.starSpeed);
            ctx.globalAlpha = Math.max(0.25, p.bright);
            ctx.strokeStyle = pal[1];
            ctx.lineWidth = Math.max(1, p.r - 1);
            ctx.beginPath();
            ctx.moveTo(p.px, p.py);
            ctx.lineTo(p.x, p.y);
            ctx.stroke();
            ctx.fillStyle = p.r > 2 ? pal[0] : pal[1];
            ctx.fillRect(Math.round(p.x - p.r / 2), Math.round(p.y - p.r / 2), p.r, p.r);
        }
        ctx.globalAlpha = 1;
    }

    // Flat shading: a wide pipe in the colour, a narrower lighter stripe along it, a square joint at each end
    function paintPipes(ctx, pal) {
        const c = root.cell, half = c / 2, w = c - 6;
        ctx.lineCap = "butt";
        for (const s of root.scene.segs) {
            const x1 = s.x1 * c + half, y1 = s.y1 * c + half, x2 = s.x2 * c + half, y2 = s.y2 * c + half;
            ctx.strokeStyle = pal[s.c];
            ctx.lineWidth = w;
            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            ctx.stroke();
            ctx.fillStyle = pal[s.c];
            ctx.fillRect(x1 - w / 2, y1 - w / 2, w, w);
            ctx.fillRect(x2 - w / 2, y2 - w / 2, w, w);
            ctx.strokeStyle = String(Config.colors.base);
            ctx.globalAlpha = 0.35;
            ctx.lineWidth = Math.max(1, Math.round(w / 4));
            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            ctx.stroke();
            ctx.globalAlpha = 1;
        }
        ctx.fillStyle = pal[1];
        for (const h of root.scene.heads)
            ctx.fillRect(h.x * c + half - w / 2, h.y * c + half - w / 2, w, w);
    }

    function paintPolys(ctx, pal) {
        ctx.lineWidth = 1;
        for (const p of root.scene) {
            const rings = [p.pts].concat(p.trail);
            for (let i = rings.length - 1; i >= 0; i--) {
                ctx.globalAlpha = 1 - i / (rings.length + 1);
                ctx.strokeStyle = pal[p.c];
                ctx.beginPath();
                rings[i].forEach((q, j) => j === 0 ? ctx.moveTo(q.x, q.y) : ctx.lineTo(q.x, q.y));
                ctx.closePath();
                ctx.stroke();
            }
        }
        ctx.globalAlpha = 1;
    }

    // Input: eaten here
    focus: true
    Keys.onPressed: event => {
        event.accepted = true;
        root.input("key");
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.AllButtons
        onPressed: root.input("press")
        onWheel: root.input("wheel")
        onPositionChanged: mouse => {
            // the same position again is not a move
            if (mouse.x === root.lastX && mouse.y === root.lastY)
                return;
            root.lastX = mouse.x;
            root.lastY = mouse.y;
            root.input("move");
        }
    }
}

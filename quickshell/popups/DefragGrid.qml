import QtQuick

import ".."

// Win95's Disk Defragmenter block grid: small squares filled left to right as `value` (0..1) grows, the one being worked on in
// the text colour. Used by the Clean up panel while a clean runs (no real progress is reported, so the value creeps up and
// jumps to 1 when the script ends). It steps, never animates, so reduce-motion needs no special case.
Canvas {
    id: root

    property real value: 0
    readonly property int cell: MenuStyle.defragCell
    readonly property int gap: 1
    readonly property int cols: Math.max(1, Math.floor((width + gap) / (cell + gap)))
    readonly property int rows: Math.max(1, Math.floor((height + gap) / (cell + gap)))

    antialiasing: false
    onValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const total = root.cols * root.rows;
        const filled = Math.floor(Math.max(0, Math.min(1, root.value)) * total);
        for (let i = 0; i < total; i++) {
            const x = (i % root.cols) * (root.cell + root.gap);
            const y = Math.floor(i / root.cols) * (root.cell + root.gap);
            ctx.fillStyle = i < filled ? MenuStyle.selectBar : (i === filled && root.value < 1 ? Config.colors.text : Config.colors.base);
            ctx.fillRect(x, y, root.cell, root.cell);
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    A big title as SSS by applibot sets one: thin, stroke-only capitals in
    the HUD face, every letter an outline over whatever is behind it. It
    can draw itself on (`drawOn()`): every letter's strokes trace in at
    once, line after line, then stay. Given a `room`, it breaks between words into at most
    `lines` lines, a size smaller each time it doesn't fit (down to
    `minSize`), the last line cut short only when even that is too long;
    without one it is one line, as wide as its words. It is as tall as its
    capitals: its top is their top and its foot their baseline.

    For display sizes only (about 30 px and up): smaller words stay solid.
    A flavour with `outline` sets its big English titles so
    (`Theme.outlined(text)`); Japanese stays in the title face.

        OutlineText { room: 720; text: "Quiet Static"; size: 104; lines: 2 }
        OutlineText { text: "02"; size: 88; color: Theme.hudAccent }   …   title.drawOn()
*/
Item {
    id: root

    /** The words, set in capitals. */
    property string text: ""
    /** The largest size, in pixels, and the smallest it may shrink to so the words fit. */
    property int size: 72
    property int minSize: 28
    /** The width it may take (0: one line, as wide as its words), and the most lines it may break into there. */
    property real room: 0
    property int lines: 1
    property color color: Theme.hudText
    /** The stroke's width: a hairline, a little heavier on larger words. */
    property real weight: Math.max(1, Math.min(2, used / 64))
    /** How much of it is drawn, 0 to 1: 1 at rest; `drawOn()` runs it up. */
    property real drawn: 1
    /** How long a draw takes (the size of the words decides nothing: a long title traces faster). */
    property int drawFor: Theme.settle

    /** The size it is set at, after fitting. */
    readonly property real used: layout.size
    /** Its lines as set: the words of each. */
    readonly property var shown: layout.lines

    implicitWidth: layout.wide
    implicitHeight: layout.lines.length ? cap * used + (layout.lines.length - 1) * step : 0

    /** Traces the strokes in from nothing over `drawFor`, after `wait` ms; at once with less motion. Without words yet, they are drawn on as they come. */
    function drawOn(wait) {
        drawing.stop()
        if (Theme.calm || drawFor <= 0) { drawn = 1; return }
        // Nothing runs while there is nothing to draw (a running animation keeps the window drawing).
        if (text === "") { onArrival = true; return }
        onArrival = false
        drawWait.duration = Math.max(0, wait || 0)
        drawn = 0
        drawing.start()
    }
    /** Asked to draw on before its words came: they are drawn on as they arrive. */
    property bool onArrival: false
    onTextChanged: if (onArrival && text !== "") drawOn(0)
    Settling { when: drawing.running }
    SequentialAnimation {
        id: drawing
        PauseAnimation { id: drawWait; duration: 0 }
        // Even, slow at both ends, so the strokes are seen running.
        NumberAnimation { target: root; property: "drawn"; from: 0; to: 1; duration: root.drawFor; easing: Theme.easeInOut }
    }

    // Measured once at 100 px; a face's outlines scale as their size does.
    FontMetrics { id: metrics; font.family: Theme.fontHud; font.pixelSize: 100 }
    /** The capitals' height and the step from line to line, as shares of the size. */
    readonly property real cap: Math.max(0.5, metrics.tightBoundingRect("H").height / 100)
    readonly property real step: used * (cap + 0.32)
    /** How far over the capitals' top a line's ink reaches (an accent, a slash), as a share of the size: a path's text stands with its ink's top where it is put. */
    function over(line) { return Math.max(0, -metrics.tightBoundingRect(line).y / 100 - cap) }
    function widthOf(s, size) { return metrics.advanceWidth(s) * size / 100 }

    // The words broken into lines at the largest size that fits them, else the smallest, cut short.
    readonly property var layout: {
        const words = text.toUpperCase().split(/\s+/).filter(Boolean)
        if (!words.length) return { size: size, lines: [], wide: 0 }
        const room = root.room > 0 ? root.room : Infinity
        const wrap = s => {
            const out = []
            for (const w of words) {
                const line = out.length ? out[out.length - 1] + " " + w : ""
                if (out.length && widthOf(line, s) <= room) out[out.length - 1] = line
                else out.push(w)
            }
            return out
        }
        const fits = (ls, s) => ls.length <= lines && ls.every(l => widthOf(l, s) <= room)
        let s = size, set = wrap(s)
        while (!fits(set, s) && s > minSize) { s = Math.max(minSize, s - 2); set = wrap(s) }
        if (!fits(set, s)) {
            set = set.slice(0, lines)
            let last = set[set.length - 1]
            while (last.length > 1 && widthOf(last + "…", s) > room) last = last.slice(0, -1).replace(/\s+$/, "")
            set[set.length - 1] = last + "…"
            set = set.map(l => { let t = l; while (t.length > 1 && widthOf(t, s) > room) t = t.slice(0, -1); return t })
        }
        return { size: s, lines: set, wide: Math.min(room, Math.max(...set.map(l => widthOf(l, s)))) }
    }
    /**
        The dash each outline traces with, in stroke widths: a dash starts again at every outline, so
        one about as long as a capital's outline (some three ems) draws every letter at once; at rest
        the whole stroke shows, the longest outlines too.
    */
    readonly property real dash: 3 * used / weight
    /** The lines draw one after another: each line's share of the whole, by its letters. */
    readonly property var lengths: layout.lines.map(l => Math.max(1, l.replace(/\s/g, "").length))
    readonly property real total: lengths.reduce((a, b) => a + b, 0)

    Repeater {
        model: root.layout.lines
        delegate: Shape {
            id: line
            required property string modelData
            required property int index
            readonly property real length: root.lengths[index] || 1
            readonly property real before: root.lengths.slice(0, index).reduce((a, b) => a + b, 0)
            /** How much of this line is drawn, 0 to 1. */
            readonly property real done: Math.max(0, Math.min(1, (root.drawn * root.total - before) / length))
            y: index * root.step
            width: root.layout.wide
            height: root.cap * root.used
            visible: done > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.weight
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                // While it draws, a dash as long as the line runs in; at rest, one dash longer than any
                // title, so the whole stroke shows (the renderer doesn't take a change of style while it runs).
                strokeStyle: ShapePath.DashLine
                dashPattern: line.done < 1 ? [root.dash, root.dash] : [1e6, 1]
                dashOffset: line.done < 1 ? root.dash * (1 - line.done) : 0
                PathText {
                    x: 0
                    y: -root.over(line.modelData) * root.used
                    text: line.modelData
                    font.family: Theme.fontHud
                    font.pixelSize: root.used
                }
            }
        }
    }
}

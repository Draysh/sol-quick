import QtQuick

/*
    An impact frame for a main act landing (play, on air, Watched, a seal,
    a stamp): over the hit thing's own region only, never the window,
    drawn on twos (the flavour's `beat.steps`, `Theme.step`; else one
    `Theme.frame` each): first a smear (its shape stretched the way it was
    struck, in the impact colour) with a burst of speed lines round it;
    then an inverted drawing (its region flat in the impact colour, its
    shape in ink) as the lines reach out; the lines alone, thinner; then
    the held pose, which is the thing itself. The page shakes 2 to 3 px for
    80 ms under the first two. Three at most a second (`Sounds.hitAllowed`),
    none with less motion. The Shell has one over its pane; a world asks
    for it through `Sol.impact(item)`.

        Sol.impact(playButton)
*/
Item {
    id: root

    /** How far the page is shaken across now: the Shell moves its pane by it. */
    property real shakeX: 0
    /** The thing hit, while the frames play. */
    property Item target: null
    /** Its place in this layer. */
    property rect area: Qt.rect(0, 0, 0, 0)
    /** Which drawing is up: 0 the smear, 1 the inverted shape, 2 the lines alone, -1 none. */
    property int drawing: -1
    /** The way it was struck: 1 left to right, -1 the other way. */
    property int way: 1
    /** A new burst of lines each time. */
    property int seed: 0
    /** How long a drawing stays up: on twos where the flavour's beat has `steps`. */
    readonly property int each: Theme.beat.steps ? Theme.step : Theme.frame

    enabled: false
    visible: drawing >= 0

    /** Plays the frames over `item`; `opts.way` -1 strikes it right to left. Nothing with less motion, or past three a second. */
    function hit(item, opts) {
        if (!item || !item.visible || Theme.calm || each === 0 || !Sounds.hitAllowed()) return
        const p = item.mapToItem(root, 0, 0)
        area = Qt.rect(p.x, p.y, item.width, item.height)
        way = opts && opts.way === -1 ? -1 : 1
        seed = (seed + 1) % 997
        target = item
        copy.scheduleUpdate()
        run.restart()
        shake.restart()
    }

    function noise(i) { const s = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }

    // What was hit, as it is now (its held pose): its shape for the two drawings.
    ShaderEffectSource { id: copy; sourceItem: root.target; live: false; hideSource: false; visible: false }

    Settling { when: run.running || shake.running }
    SequentialAnimation {
        id: run
        PropertyAction { target: root; property: "drawing"; value: 0 }
        PauseAnimation { duration: root.each }
        PropertyAction { target: root; property: "drawing"; value: 1 }
        PauseAnimation { duration: root.each }
        PropertyAction { target: root; property: "drawing"; value: 2 }
        PauseAnimation { duration: Theme.frame }
        PropertyAction { target: root; property: "drawing"; value: -1 }
        PropertyAction { target: root; property: "target"; value: null }
    }
    // The shake: a few pixels either way, a quarter of a hit each, then still.
    SequentialAnimation {
        id: shake
        PropertyAction { target: root; property: "shakeX"; value: 3 }
        PauseAnimation { duration: Theme.hit / 4 }
        PropertyAction { target: root; property: "shakeX"; value: -2 }
        PauseAnimation { duration: Theme.hit / 4 }
        PropertyAction { target: root; property: "shakeX"; value: 2 }
        PauseAnimation { duration: Theme.hit / 4 }
        PropertyAction { target: root; property: "shakeX"; value: -1 }
        PauseAnimation { duration: Theme.hit / 4 }
        PropertyAction { target: root; property: "shakeX"; value: 0 }
    }

    // The burst: speed lines from round the thing out, a new spray on each drawing.
    Canvas {
        id: burst
        readonly property real inner: Math.max(root.area.width, root.area.height) / 2 + Theme.s2
        readonly property real reach: Math.max(80, Math.min(240, Math.max(root.area.width, root.area.height) * 1.8))
        x: root.area.x + root.area.width / 2 - reach
        y: root.area.y + root.area.height / 2 - reach
        width: reach * 2
        height: reach * 2
        visible: root.drawing >= 0
        onPaint: {
            const g = getContext("2d")
            g.reset()
            if (root.drawing < 0) return
            const c = reach, lines = root.drawing === 2 ? 10 : 18
            g.fillStyle = root.drawing === 1 ? Theme.artBright : Theme.impact
            for (let i = 0; i < lines; i++) {
                const n = root.noise(root.seed * 31 + root.drawing * 7 + i)
                const a = (i + n * 0.8) / lines * Math.PI * 2
                const from = inner + (root.drawing === 2 ? reach * 0.3 : 0) * n
                const to = inner + (reach - inner) * (0.55 + 0.45 * root.noise(root.seed + i * 3 + root.drawing))
                const wide = (root.drawing === 2 ? 1.5 : 3.5) * (0.6 + n)
                const ca = Math.cos(a), sa = Math.sin(a)
                g.beginPath()
                g.moveTo(c + ca * from, c + sa * from)
                g.lineTo(c + ca * to - sa * wide, c + sa * to + ca * wide)
                g.lineTo(c + ca * to + sa * wide, c + sa * to - ca * wide)
                g.closePath()
                g.fill()
            }
        }
        Connections { target: root; function onDrawingChanged() { burst.requestPaint() } }
    }

    // The inverted drawing: the region flat in the impact colour, the shape on it in ink.
    Rectangle {
        visible: root.drawing === 1
        x: root.area.x - Theme.s2; y: root.area.y - Theme.s2
        width: root.area.width + Theme.s2 * 2; height: root.area.height + Theme.s2 * 2
        color: Theme.impact
    }
    ShaderEffect {
        visible: root.drawing === 1
        x: root.area.x; y: root.area.y
        width: root.area.width; height: root.area.height
        property variant source: copy
        property color color: Theme.cardInk
        property vector2d smear: Qt.vector2d(0, 0)
        fragmentShader: "../shaders/impact.frag.qsb"
    }
    // The smear: the shape stretched the way it was struck, in the impact colour.
    ShaderEffect {
        visible: root.drawing === 0
        x: root.area.x; y: root.area.y
        width: root.area.width; height: root.area.height
        property variant source: copy
        property color color: Theme.impact
        property vector2d smear: Qt.vector2d(0.3 * root.way, 0)
        transform: Scale { origin.x: root.way > 0 ? 0 : root.area.width; xScale: 1.35 }
        fragmentShader: "../shaders/impact.frag.qsb"
    }
}

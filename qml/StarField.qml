pragma ComponentBehavior: Bound
import QtQuick

/*
    A night to draw stars on, the part the Sky, Mercury's path and Titan's
    galaxy share: a dark panel in both lights with its far dust, the view
    (the point of the sky in the middle, `cx`, `cy`, and how close,
    `zoom`), and the pointer: drag to wander, scroll or pinch to come
    closer, double-click to come closer (or open a star, with `opens`),
    hover and click a star. `flyTo` glides to a view.

    A map is a StarField whose children are its own stars, lines and names
    (`StarLight`, `StarArc`, `StarLine`), placed with `sx(x)`, `sy(y)`: they
    sit on one plane that pans as a whole, so wandering moves nothing one
    by one. What stays put on the panel (a caption, an empty line) goes in
    `above`. Names are placed on `place()`, which comes at most every few
    frames while the view moves and once more when it settles. At rest
    nothing moves, so nothing is painted until it's touched.

        StarField {
            id: map
            stars: view.stars
            chosen: page.chosen
            onChoose: key => page.chosen = key
            Repeater { model: map.stars; delegate: StarLight { required property var modelData; x: map.sx(modelData.x); y: map.sy(modelData.y); r: 20 } }
        }
*/
Rectangle {
    id: field

    /** What can be picked: anything with `x`, `y` (the sky's own units, y down) and a key. */
    property var stars: []
    /** The name of a star's key in `stars` (`key`; Mercury's skills use `id`). */
    property string keyName: "key"
    /** How near the pointer must come to a star to take it, in pixels: a function of the star. */
    property var reach: s => 14
    /** The chosen star's key, or "". */
    property string chosen: ""
    /** The star under the pointer's key, or "". */
    property string hover: ""
    /** Whether a double-click on a star opens it (`open`) instead of coming closer. */
    property bool opens: false
    signal choose(string key)
    signal open(string key)
    /** Time to place the names again: the view moved, or came to rest. */
    signal place()

    /** Where the view starts and `home()` goes back to. */
    property point origin: Qt.point(0, 0)
    /** The point of the sky in the middle of the panel, and how close it is. */
    property real cx: origin.x
    property real cy: origin.y
    property real zoom: 1
    /** Pixels to one unit of the sky at zoom 1. */
    property real fit: Math.max(1, Math.min(width / 2.7, height / 1.9))
    /** Pixels to one unit of the sky now. */
    readonly property real k: fit * zoom
    /** How far the middle may wander, in the sky's units. */
    property rect room: Qt.rect(-1.4, -1, 2.8, 2)
    /** How close and how far the view may go. */
    property real nearest: 5
    property real farthest: 0.8
    /** How long a flight takes, in ms. */
    property int flightMs: Theme.calm ? 0 : Theme.rise

    /** How much of the ground lies over the still behind the night (top; the foot has a little more): little, so the film shows round the stars. */
    // Over a light flavour's bright noon still the night is laid deeper, so its names still read.
    property real dark: Theme.light ? 0.56 : 0.34
    /** The far dust: its own seed per map, how thinly it lies (square pixels to a grain), and how much of it is warm (warm dust is a little brighter). */
    property int dustSeed: 20261012
    property real dustSpread: 1500
    property real dustWarm: 0

    /** The map's stars, lines and names: the plane that pans as one. */
    default property alias content: plane.data
    /** What stays put on the panel, over the stars. */
    property alias above: front.data

    /** Where a point of the sky is on the panel. */
    function px(x) { return width / 2 + (x - cx) * k }
    function py(y) { return height / 2 + (y - cy) * k }
    /** Where a point of the sky is on the plane the map draws on. */
    function sx(x) { return x * k }
    function sy(y) { return y * k }

    /** Each star by its key, made again when the stars change. */
    readonly property var index: {
        const m = {}
        for (const s of stars) m[s[keyName]] = s
        return m
    }
    function find(key) { return key === "" ? null : index[key] || null }

    /** The star nearest to a point of the panel, if the point is on it. */
    function starAt(x, y) {
        let best = "", bestD = 1e9
        for (const s of stars) {
            const d = Math.hypot(px(s.x) - x, py(s.y) - y)
            if (d < reach(s) && d < bestD) { best = s[keyName]; bestD = d }
        }
        return best
    }
    function panBy(dx, dy) {
        cx = Math.max(room.x, Math.min(room.x + room.width, cx - dx / k))
        cy = Math.max(room.y, Math.min(room.y + room.height, cy - dy / k))
    }
    /** Closer (f > 1) or farther, keeping the point under (x, y) where it is. */
    function zoomAt(x, y, f) {
        flight.stop()
        const to = Math.max(farthest, Math.min(nearest, zoom * f))
        const ax = cx + (x - width / 2) / k, ay = cy + (y - height / 2) / k
        cx = ax - (x - width / 2) / (fit * to)
        cy = ay - (y - height / 2) / (fit * to)
        zoom = to
    }
    function flyTo(x, y, z) {
        flight.stop()
        toX.to = x; toY.to = y; toZoom.to = z
        flight.start()
    }
    /** The whole sky again. */
    function home() { flyTo(origin.x, origin.y, 1) }

    ParallelAnimation {
        id: flight
        NumberAnimation { id: toX; target: field; property: "cx"; duration: field.flightMs; easing: Theme.easeOut }
        NumberAnimation { id: toY; target: field; property: "cy"; duration: field.flightMs; easing: Theme.easeOut }
        NumberAnimation { id: toZoom; target: field; property: "zoom"; duration: field.flightMs; easing: Theme.easeOut }
    }

    // The names wait for the view: at most every few frames while it moves,
    // and once more when it settles.
    function placeSoon() { if (!placing.running) placing.start() }
    Timer { id: placing; interval: 100; onTriggered: field.place() }
    onCxChanged: placeSoon()
    onCyChanged: placeSoon()
    onZoomChanged: placeSoon()
    onWidthChanged: placeSoon()
    onHeightChanged: placeSoon()

    radius: Theme.radius
    clip: true
    border.width: 1
    border.color: Theme.line
    gradient: Gradient {
        GradientStop { position: 0; color: Theme.tint(Theme.hud.ground, field.dark) }
        GradientStop { position: 1; color: Theme.tint(Theme.hud.ground, Math.min(1, field.dark + 0.2)) }
    }
    // The night is the still itself, a little darkened, its corners bracketed: no glass, so the
    // constellations float on the film.
    HudBrackets { z: 5; anchors.fill: parent; color: Theme.tint(Theme.hudAccent, 0.8) }

    // Far dust, drawn once, drifting a little as the sky moves.
    Canvas {
        x: -40 + Math.max(-36, Math.min(36, -field.cx * field.k * 0.05))
        y: -40 + Math.max(-36, Math.min(36, -field.cy * field.k * 0.05))
        width: field.width + 80
        height: field.height + 80
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            let seed = field.dustSeed
            const next = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
            const count = Math.round(width * height / field.dustSpread)
            for (let i = 0; i < count; i++) {
                const big = next() > 0.95
                if (field.dustWarm > 0) {
                    const warm = next() > 1 - field.dustWarm
                    c.fillStyle = warm ? Qt.rgba(1, 0.9, 0.78, (big ? 0.2 : 0.07) + next() * 0.16) : Qt.rgba(0.82, 0.87, 1, (big ? 0.22 : 0.07) + next() * 0.18)
                } else {
                    c.fillStyle = Qt.rgba(0.85, 0.88, 1, (big ? 0.2 : 0.06) + next() * 0.14)
                }
                c.beginPath()
                c.arc(next() * width, next() * height, big ? 0.9 : 0.55, 0, Math.PI * 2)
                c.fill()
            }
        }
    }

    Item {
        id: plane
        x: field.width / 2 - field.cx * field.k
        y: field.height / 2 - field.cy * field.k
    }

    Item {
        id: front
        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property point last
        property bool dragged: false
        cursorShape: pressed && dragged ? Qt.ClosedHandCursor : field.hover !== "" ? Qt.PointingHandCursor : Qt.OpenHandCursor
        onPressed: m => { last = Qt.point(m.x, m.y); dragged = false; flight.stop() }
        onPositionChanged: m => {
            if (!pressed) { field.hover = field.starAt(m.x, m.y); return }
            if (!dragged && Math.hypot(m.x - last.x, m.y - last.y) < 4) return
            dragged = true
            field.panBy(m.x - last.x, m.y - last.y)
            last = Qt.point(m.x, m.y)
        }
        onExited: field.hover = ""
        onClicked: m => { if (!dragged) field.choose(field.starAt(m.x, m.y)) }
        onDoubleClicked: m => {
            const key = field.opens ? field.starAt(m.x, m.y) : ""
            if (key !== "") field.open(key)
            else field.zoomAt(m.x, m.y, 1.8)
        }
        // A wheel comes closer; a touchpad's two fingers wander (closer with Ctrl).
        onWheel: w => {
            // 120 a notch, so a wheel's `y` is its angleDelta.
            const d = Theme.wheel(w, 120)
            if (!d.notched && !(w.modifiers & Qt.ControlModifier)) field.panBy(d.x, d.y)
            else field.zoomAt(w.x, w.y, Math.pow(1.0018, d.notched ? d.y : d.y * 2))
        }
    }
    PinchHandler {
        target: null
        onScaleChanged: delta => field.zoomAt(centroid.position.x, centroid.position.y, delta)
    }
}

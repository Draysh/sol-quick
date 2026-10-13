pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    The window's ground: a still from the
    world's film (or a page's own key art, `Screen.ground`) full-bleed
    under the world's grade (`Theme.hud`: Saturn's dusk, Mercury's ink and
    vermilion, Neptune's neon night, Terra's noon sky lifted with a summer
    haze, Luna's indigo), a soft vignette, and a shade down the left where
    the page's title stands, so white words on it keep 4.5:1. A new still fades in
    over the one before. A `duotone` flavour (Neptune's) grades its stills in
    one colour, black into its light. Without one it is the world's drawn sky (stars, or
    Terra's summer sun). Neptune's has rain over it and a neon glow. The Shell draws it under the sidebar and the
    pages; HudGlass reads it, blurred once (`Shell.groundBlur`).

        DuskGround { anchors.fill: parent; source: shell.groundSource }
*/
Item {
    id: root

    /** The still: a file or web address, or "" for the drawn sky. */
    property string source: ""
    /** The picture on show (one of two, so the next fades in over it), or null for the sky. */
    property Image current: null
    readonly property bool lit: current !== null
    readonly property var look: Theme.hud
    /** What the shade, the pool and the vignette are laid in: the ground, or a day flavour's deep of the sky (`dim`). */
    readonly property color dim: look.dim || look.ground

    clip: true

    /** Shows `source` once it is ready: loaded into the picture not on show, then faded in. */
    function pick() {
        if (source === "") { current = null; return }
        for (const img of [one, two]) if (img.status === Image.Ready && String(img.source) === source) { current = img; return }
        const spare = current === one ? two : one
        if (String(spare.source) !== source) spare.source = source
    }
    onSourceChanged: pick()
    Component.onCompleted: pick()

    // The sky without a still: the world's own, top to bottom.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.look.sky[0] }
            GradientStop { position: 0.42; color: root.look.sky[1] }
            GradientStop { position: 0.7; color: root.look.sky[2] }
            GradientStop { position: 0.88; color: root.look.sky[3] }
            GradientStop { position: 1.0; color: root.look.sky[4] }
        }
    }
    // Its stars, in the darker part, the same every time (a night world's).
    Repeater {
        model: root.look.stars ? 90 : 0
        delegate: Rectangle {
            required property int index
            readonly property real r1: root.noise(index * 3 + 1)
            readonly property real r2: root.noise(index * 3 + 2)
            readonly property real r3: root.noise(index * 3 + 3)
            x: r1 * root.width
            y: Math.pow(r2, 1.6) * root.height * 0.62
            width: r3 > 0.92 ? 2.5 : r3 > 0.6 ? 1.5 : 1
            height: width
            radius: width / 2
            color: "#ffffff"
            opacity: (0.25 + r3 * 0.6) * (1 - y / (root.height * 0.7))
        }
    }
    /** A colour from `[r, g, b, a]`. */
    function rgba(c) { return Qt.rgba(c[0], c[1], c[2], c[3]) }
    /** A number from 0 to 1 for `i`, always the same one. */
    function noise(i) { const s = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }
    // A day world's sun, high on the right.
    Shape {
        visible: root.look.motif === "summer"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width * 0.78; centerY: root.height * 0.16
                centerRadius: Math.max(root.width, root.height) * 0.32
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 0.93, 0.95) }
                GradientStop { position: 0.08; color: Qt.rgba(1, 0.98, 0.8, 0.7) }
                GradientStop { position: 0.4; color: Qt.rgba(1, 0.95, 0.65, 0.16) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 0.95, 0.65, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // The stills, over the sky: the one on show on top, the one before fading out under it.
    // The flavour's framing (`frame`: a little closer, and how far across), so its stills' subject
    // stands clear of the title on the left; the whole picture, centred, without one.
    readonly property real zoom: root.look.frame ? root.look.frame[0] : 1
    readonly property real across: root.look.frame ? root.look.frame[1] : 0.5
    component Still: Image {
        id: still
        width: root.width * root.zoom
        height: root.height * root.zoom
        x: -(width - root.width) * root.across
        fillMode: Image.PreserveAspectCrop
        // Its upper middle: faces sit there more often than at the foot.
        verticalAlignment: Image.AlignTop
        horizontalAlignment: root.across < 0.5 ? Image.AlignLeft : root.across > 0.5 ? Image.AlignRight : Image.AlignHCenter
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: Math.min(2560, Math.max(1280, width))
        z: root.current === still ? 1 : 0
        opacity: root.current === still ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.rise; easing: Theme.easeOut } }
        onStatusChanged: if (status === Image.Ready) root.pick()
    }
    // A `duotone` flavour's stills are graded black into its light, as one colour (Neptune's red);
    // a light one's, its light into paper (Terra's blue).
    Item {
        id: stills
        anchors.fill: parent
        Still { id: one }
        Still { id: two }
        layer.enabled: !!root.look.duotone
        layer.effect: root.look.light ? paperTone : duotone
    }
    Component { id: duotone; Duotone { tone: root.look.accent } }
    Component { id: paperTone; PaperTone { shadow: root.look.accent; highlight: root.dim; contrast: 0.35; brightness: 0.02 } }
    Settling { when: one.status === Image.Loading || two.status === Image.Loading || (one.opacity > 0 && one.opacity < 1) || (two.opacity > 0 && two.opacity < 1) }

    // The grade: the whole picture held down a little, then the world's light from top to
    // bottom; over the drawn sky a little less, so words on it still read.
    Item {
        anchors.fill: parent
        opacity: Math.max(one.opacity, two.opacity, 0.8)
        Rectangle { anchors.fill: parent; color: root.look.ground; opacity: root.look.hold }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.rgba(root.look.grade[0]) }
                GradientStop { position: 0.3; color: root.rgba(root.look.grade[1]) }
                GradientStop { position: 0.6; color: root.rgba(root.look.grade[2]) }
                GradientStop { position: 0.85; color: root.rgba(root.look.grade[3]) }
                GradientStop { position: 1.0; color: root.rgba(root.look.grade[4]) }
            }
        }
        // Down the left, where the title stands.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.tint(root.dim, root.look.shade) }
                GradientStop { position: 0.4; color: Theme.tint(root.dim, root.look.shade * 0.64) }
                GradientStop { position: 0.6; color: Theme.tint(root.dim, root.look.shade * 0.2) }
                GradientStop { position: 0.8; color: Theme.tint(root.dim, 0) }
            }
        }
        // A bright still's shade deepens round the title itself, top left (Terra's noon clouds), so
        // the sky stays light everywhere else.
        Shape {
            visible: (root.look.pool || 0) > 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.width * 0.26; centerY: root.height * 0.17
                    centerRadius: Math.max(root.width * 0.34, root.height * 0.36)
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Theme.tint(root.dim, root.look.pool || 0) }
                    GradientStop { position: 0.55; color: Theme.tint(root.dim, (root.look.pool || 0) * 0.6) }
                    GradientStop { position: 1.0; color: Theme.tint(root.dim, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }
    // Neptune's rain, drawn once for the window's size (it never falls, so nothing moves while the
    // page rests), in three depths: a fine far mist of short faint strokes everywhere, fewer
    // longer ones nearer, and a few long soft streaks right in front at the window's edges. The
    // nearer ones keep clear of the title's corner, top left, where words stand on the still;
    // the panels blur what falls behind them. Low in the window, out-of-focus city lights in
    // the wet (the flavour's red, cyan and white) and their smears on the street.
    Canvas {
        id: rain
        anchors.fill: parent
        visible: (root.look.rain || 0) > 0
        opacity: root.look.rain || 0
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (!visible || width < 1 || height < 1) return
            const w = width, h = height, n = root.noise
            // How much of the nearer rain a place takes: little round the title, top left.
            const open = (x, y) => Math.min(1, Math.hypot((x / w - 0.3) / 0.36, (y / h - 0.14) / 0.24))
            // One streak, its head and tail fading so it reads as a drop moving, not a stroke.
            const streak = (x, y, l, slant, a, lw) => {
                const g = ctx.createLinearGradient(x, y, x - l * slant, y + l)
                g.addColorStop(0, Theme.tint(root.look.quiet, 0))
                g.addColorStop(0.55, Theme.tint(root.look.quiet, a))
                g.addColorStop(1, Theme.tint(root.look.quiet, a * 0.2))
                ctx.strokeStyle = g
                ctx.lineWidth = lw
                ctx.beginPath()
                ctx.moveTo(x, y)
                ctx.lineTo(x - l * slant, y + l)
                ctx.stroke()
            }
            // Far: a mist of short faint strokes.
            ctx.lineWidth = 0.8
            const far = Math.round(w * h / 3000)
            for (let i = 0; i < far; i++) {
                const x = n(i * 7 + 11) * (w + 40) - 20, y = n(i * 7 + 12) * h
                const l = 5 + n(i * 7 + 13) * 10
                ctx.strokeStyle = Theme.tint(root.look.quiet, 0.03 + n(i * 7 + 14) * 0.07)
                ctx.beginPath()
                ctx.moveTo(x, y)
                ctx.lineTo(x - l * 0.16, y + l)
                ctx.stroke()
            }
            // Nearer: fewer, longer, brighter.
            const mid = Math.round(w * h / 16000)
            for (let i = 0; i < mid; i++) {
                const x = n(i * 7 + 501) * (w + 60) - 30, y = n(i * 7 + 502) * h
                const keep = open(x, y)
                if (n(i * 7 + 505) > keep) continue
                streak(x, y, 18 + n(i * 7 + 503) * 30, 0.2, 0.08 + n(i * 7 + 504) * 0.14, 1)
            }
            // In front: a few long soft streaks, at the window's two edges.
            const near = Math.round(w * h / 110000)
            for (let i = 0; i < near; i++) {
                const side = n(i * 7 + 901) < 0.35 ? n(i * 7 + 902) * 0.1 : 0.72 + n(i * 7 + 902) * 0.3
                const x = side * w, y = n(i * 7 + 903) * h * 0.9
                streak(x, y, 80 + n(i * 7 + 904) * 90, 0.24, 0.1 + n(i * 7 + 905) * 0.1, 1.6 + n(i * 7 + 906))
            }
            // City lights out of focus, low in the window and mostly towards the neon on the right,
            // larger and fainter nearer the foot, in the flavour's two lights.
            const tones = [root.look.accent, root.look.second, root.look.accent, root.look.second]
            const lights = Math.round(w / 140)
            for (let i = 0; i < lights; i++) {
                const k = n(i * 7 + 1301)
                const x = w * (0.32 + 0.7 * Math.sqrt(n(i * 7 + 1302))), y = h * (0.74 + k * 0.24)
                const r = 5 + k * 12 + n(i * 7 + 1303) * 10
                const t = tones[Math.floor(n(i * 7 + 1304) * tones.length)]
                const a = (0.1 + n(i * 7 + 1305) * 0.14) * (1 - r / 45)
                const g = ctx.createRadialGradient(x, y, 0, x, y, r)
                g.addColorStop(0, Theme.tint(t, a))
                g.addColorStop(0.55, Theme.tint(t, a * 0.8))
                g.addColorStop(1, Theme.tint(t, 0))
                ctx.fillStyle = g
                ctx.beginPath()
                ctx.arc(x, y, r, 0, Math.PI * 2)
                ctx.fill()
            }
            // Their smears on the wet street: long and low, a little under each of a few.
            for (let i = 0; i < Math.round(lights / 3); i++) {
                const x = w * (0.3 + 0.7 * n(i * 7 + 1701)), y = h * (0.86 + n(i * 7 + 1702) * 0.1)
                const t = tones[i % 2]
                const rx = 30 + n(i * 7 + 1703) * 60
                ctx.save()
                ctx.translate(x, y)
                ctx.scale(1, 0.12)
                const g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx)
                g.addColorStop(0, Theme.tint(t, 0.12))
                g.addColorStop(1, Theme.tint(t, 0))
                ctx.fillStyle = g
                ctx.beginPath()
                ctx.arc(0, 0, rx, 0, Math.PI * 2)
                ctx.fill()
                ctx.restore()
            }
        }
    }
    // A neon glow low on the right, as a city's signs light the rain (Neptune's red).
    Shape {
        visible: !!root.look.haze
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width * 0.86; centerY: root.height * 0.92
                centerRadius: Math.max(root.width, root.height) * 0.42
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Theme.tint(root.look.haze || "#000000", 0.22) }
                GradientStop { position: 0.5; color: Theme.tint(root.look.haze || "#000000", 0.07) }
                GradientStop { position: 1.0; color: Theme.tint(root.look.haze || "#000000", 0) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // A soft vignette, a still or not.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height * 0.45
                centerRadius: Math.max(root.width, root.height) * 0.78
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.45; color: Theme.tint(root.dim, 0) }
                GradientStop { position: 1.0; color: Theme.tint(root.dim, root.look.light ? 0.2 : root.look.motif === "summer" ? 0.45 : 0.62) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}

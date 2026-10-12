pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    The window's ground in the Yozora look (`Theme.look`): a still from the
    world's film (or a page's own key art, `Screen.ground`) full-bleed
    under the world's grade (`Theme.hud`: Saturn's dusk, Mercury's ink and
    vermilion, Neptune's neon night, Terra's bright sky with a deep-blue
    foot), a soft vignette, and a shade down the left where the page's
    title stands, so white words on it keep 4.5:1. A new still fades in
    over the one before. Without one it is the world's drawn sky (stars at
    night, a sun by day). Neptune's has rain over it and a neon glow. The Shell draws it under the sidebar and the
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
    component Still: Image {
        id: still
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        // Its upper middle: faces sit there more often than at the foot.
        verticalAlignment: Image.AlignTop
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: Math.min(2560, Math.max(1280, root.width))
        z: root.current === still ? 1 : 0
        opacity: root.current === still ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        onStatusChanged: if (status === Image.Ready) root.pick()
    }
    Item {
        id: stills
        anchors.fill: parent
        Still { id: one }
        Still { id: two }
    }
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
                GradientStop { position: 0.0; color: Theme.tint(root.look.ground, root.look.shade) }
                GradientStop { position: 0.4; color: Theme.tint(root.look.ground, root.look.shade * 0.64) }
                GradientStop { position: 0.6; color: Theme.tint(root.look.ground, root.look.shade * 0.2) }
                GradientStop { position: 0.8; color: Theme.tint(root.look.ground, 0) }
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
                    GradientStop { position: 0.0; color: Theme.tint(root.look.ground, root.look.pool || 0) }
                    GradientStop { position: 0.55; color: Theme.tint(root.look.ground, (root.look.pool || 0) * 0.6) }
                    GradientStop { position: 1.0; color: Theme.tint(root.look.ground, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }
    // Neptune's rain: fine streaks slanting across the night, drawn once for the window's size
    // (it never falls, so nothing moves while the page rests).
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
            if (!visible) return
            ctx.lineWidth = 1.1
            const n = Math.round(width * height / 4200)
            for (let i = 0; i < n; i++) {
                const x = root.noise(i * 5 + 11) * (width + 60) - 30
                const y = root.noise(i * 5 + 12) * height
                const l = 14 + root.noise(i * 5 + 13) * 34
                const a = 0.08 + root.noise(i * 5 + 14) * 0.26
                ctx.strokeStyle = Qt.rgba(0.66, 0.78, 0.93, a)
                ctx.beginPath()
                ctx.moveTo(x, y)
                ctx.lineTo(x - l * 0.22, y + l)
                ctx.stroke()
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
                GradientStop { position: 0.45; color: Theme.tint(root.look.ground, 0) }
                GradientStop { position: 1.0; color: Theme.tint(root.look.ground, root.look.motif === "summer" ? 0.45 : 0.62) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}

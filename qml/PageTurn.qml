pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    How a page turns in the pane, in the world's own way, over the page as
    it arrives: a slanted wipe in the world's light runs across it
    (Saturn's with a film cut's black bars closing in and opening, Neptune's
    red with a cyan ghost behind it, beside the page's glitch), Terra's is a
    soft sweep of sunlight, and Mercury's an ink wash spreading out from
    the title until the page shows through. Going back runs the other way.
    It moves and fades only (no size changes), plays for a turn and then
    draws nothing; with less motion it doesn't play at all. The Shell plays
    it over its pane as it shows a page.

        PageTurn { anchors.fill: pages }   …   turn.play("in")   // "in", "up" (a section) or "back"
*/
Item {
    id: root

    /** The flavour's way: "dusk" (Saturn), "shrine" (Mercury), "neon" (Neptune) or "summer" (Terra). */
    readonly property string motif: Theme.hud.motif
    /** The way it runs: 1 left to right, -1 back. */
    property int way: 1
    /** Where Mercury's ink starts: the page's title, top left. */
    property point origin: Qt.point(Theme.margin(width) + 40, 30)

    enabled: false
    visible: run.running
    clip: true

    function play(dir) {
        run.stop()
        if (Theme.calm || Theme.turn === 0 || width <= 0 || height <= 0) return
        way = dir === "back" ? -1 : 1
        run.start()
    }

    // How far through the turn it is, 0 to 1.
    property real t: 0
    // The wipe's slant: its top leans this far ahead of its foot.
    readonly property real lean: height * 0.22
    // Where the wipe's leading edge is across the pane, from before the start to past the end.
    readonly property real edge: way > 0 ? -lean - 160 + (width + lean + 320) * t : width + 160 - (width + lean + 320) * t

    SequentialAnimation {
        id: run
        PropertyAction { target: root; property: "t"; value: 0 }
        NumberAnimation { target: root; property: "t"; from: 0; to: 1; duration: root.motif === "shrine" ? Theme.settle * 1.3 : Theme.turn; easing: root.motif === "shrine" ? Theme.easeOut : Theme.easeInOut }
    }
    Settling { when: run.running }

    // ---- The slanted wipe: a bright edge and a fading band of light behind it -----
    component Wipe: Item {
        id: wipe
        property color light: Theme.hudAccent
        /** Pixels behind the leading edge (a ghost runs a little after). */
        property real lag: 0
        property real strength: 1
        width: root.width; height: root.height
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // The band trails the edge, brightest at it.
            ShapePath {
                id: band
                strokeWidth: 0; strokeColor: "transparent"
                readonly property real at: root.edge - root.way * wipe.lag
                readonly property real tail: 110 * root.way
                fillGradient: LinearGradient {
                    x1: band.at - band.tail; y1: 0; x2: band.at; y2: 0
                    GradientStop { position: 0; color: Theme.tint(wipe.light, 0) }
                    GradientStop { position: 1; color: Theme.tint(wipe.light, 0.15 * wipe.strength) }
                }
                startX: band.at - band.tail + root.lean; startY: 0
                PathLine { x: band.at + root.lean; y: 0 }
                PathLine { x: band.at; y: root.height }
                PathLine { x: band.at - band.tail; y: root.height }
                PathLine { x: band.at - band.tail + root.lean; y: 0 }
            }
            // The edge itself: a hairline of the light, slanted.
            ShapePath {
                id: line
                strokeWidth: 2; strokeColor: Theme.tint(wipe.light, 0.9 * wipe.strength); fillColor: "transparent"
                readonly property real at: root.edge - root.way * wipe.lag
                startX: line.at + root.lean; startY: 0
                PathLine { x: line.at; y: root.height }
            }
        }
    }

    // Saturn and Neptune: the wipe in the world's light (Neptune's with a cyan ghost a step behind).
    Wipe { visible: root.motif === "dusk" || root.motif === "neon"; light: Theme.hudAccent }
    Wipe { visible: root.motif === "neon"; light: Theme.hudSecond; lag: 18; strength: 0.7 }

    // Saturn: a film's cut, black bars closing in at the top and the foot and opening again.
    Repeater {
        model: root.motif === "dusk" ? 2 : 0
        delegate: Rectangle {
            id: bar
            required property int index
            // In fast over the first fifth, out over the rest.
            readonly property real closed: root.t < 0.2 ? root.t / 0.2 : Math.max(0, 1 - (root.t - 0.2) / 0.8)
            width: root.width
            height: Math.round(root.height * 0.075)
            color: Theme.tint(Theme.hud.ground, 0.94)
            y: bar.index === 0 ? -height * (1 - closed) : root.height - height * closed
        }
    }

    // Terra: a broad soft sweep of sunlight, no edge.
    Shape {
        visible: root.motif === "summer"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: sun
            strokeWidth: 0; strokeColor: "transparent"
            readonly property real half: Math.max(220, root.width * 0.28)
            fillGradient: LinearGradient {
                x1: root.edge - sun.half; y1: 0; x2: root.edge + sun.half; y2: 0
                GradientStop { position: 0; color: Theme.tint(Theme.artSecond, 0) }
                GradientStop { position: 0.5; color: Theme.tint(Theme.artSecond, 0.2 * Math.sin(Math.PI * root.t)) }
                GradientStop { position: 1; color: Theme.tint(Theme.artSecond, 0) }
            }
            startX: root.edge - sun.half + root.lean; startY: 0
            PathLine { x: root.edge + sun.half + root.lean; y: 0 }
            PathLine { x: root.edge + sun.half; y: root.height }
            PathLine { x: root.edge - sun.half; y: root.height }
            PathLine { x: root.edge - sun.half + root.lean; y: 0 }
        }
    }

    // Mercury: ink over the pane, clearing from the title outwards with a soft, uneven edge.
    Repeater {
        model: root.motif === "shrine" ? 2 : 0
        delegate: Shape {
            id: ink
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // Two washes, one a little behind and off the other, so the edge isn't a perfect circle.
            readonly property real reach: Math.hypot(root.width, root.height) * 1.25
            readonly property real cx: root.way > 0 ? root.origin.x + ink.index * 70 : root.width - root.origin.x - ink.index * 70
            readonly property real cy: root.origin.y + ink.index * 50
            opacity: (ink.index === 0 ? 0.7 : 0.4) * Math.min(1, (1 - root.t) * 3)
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: ink.cx; centerY: ink.cy; focalX: ink.cx; focalY: ink.cy
                    centerRadius: Math.max(1, ink.reach * Math.max(0, root.t - ink.index * 0.08))
                    GradientStop { position: 0; color: Theme.tint(Theme.hud.ground, 0) }
                    GradientStop { position: 0.72; color: Theme.tint(Theme.hud.ground, 0) }
                    GradientStop { position: 0.9; color: Theme.tint(Theme.hud.ground, 0.55) }
                    GradientStop { position: 1; color: Theme.hud.ground }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}

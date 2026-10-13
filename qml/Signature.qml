import QtQuick
import QtQuick.Shapes

/*
    The navigator's name as a hand signs it (the flavour's `signature`, an
    SVG path drawn in a box 320 by 150), written in one stroke of the
    light, as SSS by applibot signs under each member (with the flavour's
    `signatureNib`, a broad nib held at an angle, as a brush writes: thin
    along it, broad across it). `write()` draws it
    on, the pen running along the stroke, once a launch (`Theme.signed`);
    after that, and with less motion, it is simply there. Nothing when the
    flavour has none.

        Signature { width: 220 }   …   signature.write(Theme.hold)
*/
Item {
    id: root

    /** The stroke, in its box of 320 by 150. */
    property string path: Theme.hud.signature || ""
    property color color: Theme.hudAccent
    /** How broad the nib is, in the box's units: 0 for a pen's even line. */
    property real nib: Theme.hud.signatureNib || 0
    /** How much of it is written, 0 to 1. */
    property real drawn: Theme.signed || Theme.calm ? 1 : 0
    /** How long the pen takes. */
    property int writeFor: Theme.rise

    readonly property real k: width / 320
    implicitWidth: 240
    implicitHeight: width * 150 / 320
    visible: path !== ""

    /** Writes it, after `wait` ms, if it hasn't been this launch; otherwise it stays as it is. */
    function write(wait) {
        if (Theme.signed || Theme.calm || writeFor <= 0) { drawn = 1; Theme.signed = true; return }
        Theme.signed = true
        pen.stop()
        penWait.duration = Math.max(0, wait || 0)
        drawn = 0
        pen.start()
    }
    Settling { when: pen.running }
    SequentialAnimation {
        id: pen
        PauseAnimation { id: penWait; duration: 0 }
        NumberAnimation { target: root; property: "drawn"; from: 0; to: 1; duration: root.writeFor; easing: Theme.easeInOut }
    }

    Shape {
        id: stroke
        width: 320; height: 150
        transform: Scale { xScale: root.k; yScale: root.k }
        visible: root.drawn > 0 && root.nib <= 0
        preferredRendererType: Shape.CurveRenderer
        // The stroke is about 760 units long (else the flavour's `signatureLength`): a dash as long, running in.
        readonly property real dash: (Theme.hud.signatureLength || 780) / 2.6
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // Always a dash, one longer than the stroke at rest (the renderer doesn't take a change of style while it runs).
            strokeStyle: ShapePath.DashLine
            dashPattern: root.drawn < 1 ? [stroke.dash, stroke.dash] : [1e6, 1]
            dashOffset: root.drawn < 1 ? stroke.dash * (1 - root.drawn) : 0
            PathSvg { path: root.path }
        }
    }

    // With a nib: the stroke drawn five times along the nib's edge, held at 40°, so it is thin where the
    // hand moves along the nib and broad where it moves across it, as a brush or a broad pen writes.
    Repeater {
        model: root.nib > 0 ? 5 : 0
        delegate: Shape {
            id: edge
            required property int index
            readonly property real at: (index / 4 - 0.5) * root.nib
            width: 320; height: 150
            transform: [Translate { x: edge.at * 0.77; y: -edge.at * 0.64 }, Scale { xScale: root.k; yScale: root.k }]
            visible: root.drawn > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                strokeStyle: ShapePath.DashLine
                dashPattern: root.drawn < 1 ? [stroke.dash / 1.4 * 2.6, stroke.dash / 1.4 * 2.6] : [1e6, 1]
                dashOffset: root.drawn < 1 ? stroke.dash / 1.4 * 2.6 * (1 - root.drawn) : 0
                PathSvg { path: root.path }
            }
        }
    }
}

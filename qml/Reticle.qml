import QtQuick
import QtQuick.Shapes

/*
    Two arcs and an axis at the world's real tilt, with whatever it frames
    in the middle (usually the world's name). It finds its target as it
    appears: the arcs draw themselves, the axis extends from the centre,
    then the poles.

        Reticle { tilt: 23.44; size: 200; Heading { level: 1; text: "Terra" } }
*/
Item {
    id: root

    /** Axial tilt in degrees; the axis leans right at the top. */
    property real tilt: 0
    property int size: 240
    default property alias content: inside.data
    property bool animated: true

    width: size
    height: size

    readonly property real r: size * 0.35
    readonly property real cx: size / 2
    readonly property real cy: size / 2
    readonly property real ax: r * 1.41 * Math.sin(tilt * Math.PI / 180)
    readonly property real ay: -r * 1.41 * Math.cos(tilt * Math.PI / 180)

    property real drawn: animated ? 0 : 1
    property real extended: animated ? 0 : 1
    property real poles: animated ? 0 : 1

    Component.onCompleted: if (animated) find.start()
    SequentialAnimation {
        id: find
        ParallelAnimation {
            NumberAnimation { target: root; property: "drawn"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            SequentialAnimation {
                PauseAnimation { duration: Theme.rise / 3 }
                NumberAnimation { target: root; property: "extended"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.rise * 0.8 }
                NumberAnimation { target: root; property: "poles"; to: 1; duration: Theme.fade }
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: Theme.tint(Theme.textBright, 0.6); strokeWidth: 1; fillColor: "transparent"
            trim.start: 0; trim.end: root.drawn
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.r; radiusY: root.r; startAngle: -70; sweepAngle: 110 }
        }
        ShapePath {
            strokeColor: Theme.tint(Theme.textBright, 0.6); strokeWidth: 1; fillColor: "transparent"
            trim.start: 0; trim.end: root.drawn
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.r; radiusY: root.r; startAngle: 110; sweepAngle: 110 }
        }
        // The axis grows from the centre, both ways.
        ShapePath {
            strokeColor: Theme.tint(Theme.textBright, 0.65); strokeWidth: 1; fillColor: "transparent"
            startX: root.cx - root.ax * root.extended; startY: root.cy - root.ay * root.extended
            PathLine { x: root.cx + root.ax * root.extended; y: root.cy + root.ay * root.extended }
        }
    }
    Rectangle { x: root.cx + root.ax - 2; y: root.cy + root.ay - 2; width: 4; height: 4; radius: 2; color: Theme.textBright; opacity: root.poles }
    Rectangle { x: root.cx - root.ax - 2; y: root.cy - root.ay - 2; width: 4; height: 4; radius: 2; color: Theme.textBright; opacity: root.poles }

    // Centred on the reticle even when it is wider, as a long name is.
    Item {
        id: inside
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}

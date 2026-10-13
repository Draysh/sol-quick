import QtQuick
import QtQuick.Shapes

/* An arc turning slowly, for the moments before a screen has data. */
Item {
    id: root
    property int size: 32
    width: size
    height: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            strokeColor: Theme.tint(Theme.ink, 0.14); strokeWidth: 1; fillColor: "transparent"
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size * 0.375; radiusY: root.size * 0.375; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Theme.text; strokeWidth: 1.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size * 0.375; radiusY: root.size * 0.375; startAngle: -90; sweepAngle: 90 }
        }
        RotationAnimation on rotation { from: 0; to: 360; duration: Theme.sweep; loops: Animation.Infinite; running: Theme.alive && root.visible }
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.09; height: width; radius: width / 2
        color: Theme.accent
    }
}

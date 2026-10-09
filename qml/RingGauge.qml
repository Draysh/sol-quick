import QtQuick
import QtQuick.Shapes

/*
    Two rings like Saturn's: the outer for the whole, the inner for the
    part. The arcs draw themselves in and follow their values after.

        RingGauge { outer: { value: 3, max: 5 }; inner: { value: 7, max: 12 }; center: "E07" }
*/
Item {
    id: root

    property var outer: ({ value: 0, max: 1 })
    property var inner: null
    property string center: ""
    property int size: 96

    width: size
    height: size

    function part(ring) { return ring && ring.max > 0 ? Math.min(0.9999, Math.max(0, ring.value / ring.max)) : 0 }
    property real outerShown: 0
    property real innerShown: 0
    Component.onCompleted: { outerShown = Qt.binding(() => part(outer)); innerShown = Qt.binding(() => part(inner)) }
    Behavior on outerShown { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    Behavior on innerShown { SequentialAnimation { PauseAnimation { duration: Theme.rise / 6 } NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        readonly property real s: root.size / 96

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.14); strokeWidth: 1; fillColor: "transparent"
            PathAngleArc { centerX: 48 * parent.s; centerY: 48 * parent.s; radiusX: 44 * parent.s; radiusY: 44 * parent.s; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Theme.text; strokeWidth: 1.5; fillColor: "transparent"; capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: 48 * parent.s; centerY: 48 * parent.s; radiusX: 44 * parent.s; radiusY: 44 * parent.s; startAngle: -90; sweepAngle: 360 * root.outerShown }
        }
        ShapePath {
            strokeColor: root.inner ? Qt.rgba(1, 1, 1, 0.14) : "transparent"; strokeWidth: 1; fillColor: "transparent"
            PathAngleArc { centerX: 48 * parent.s; centerY: 48 * parent.s; radiusX: 34 * parent.s; radiusY: 34 * parent.s; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.inner ? Theme.world : "transparent"; strokeWidth: 1.5; fillColor: "transparent"
            PathAngleArc { centerX: 48 * parent.s; centerY: 48 * parent.s; radiusX: 34 * parent.s; radiusY: 34 * parent.s; startAngle: -90; sweepAngle: 360 * root.innerShown }
        }
    }
    Text {
        anchors.centerIn: parent
        text: root.center
        font.family: Theme.font
        font.weight: Theme.weightDisplay
        font.pixelSize: 18 * root.size / 96
        color: Theme.text
        onTextChanged: fade.restart()
        NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
    }
}

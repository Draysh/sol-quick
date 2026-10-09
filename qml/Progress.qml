import QtQuick

/* A hairline with a playhead. It fills to its value as it appears, and follows the value after. */
Item {
    id: root

    property real value: 0
    property real max: 1
    property string start: ""
    property string end: ""

    readonly property real pct: max > 0 ? Math.min(1, Math.max(0, value / max)) : 0
    property real shown: 0

    implicitWidth: parent ? parent.width : 240
    implicitHeight: column.implicitHeight

    Component.onCompleted: shown = Qt.binding(() => pct)
    Behavior on shown { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Item {
            width: parent.width
            height: 13
            Rectangle { y: 6; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.2) }
            // The fill is scaled, never resized: the compositor's work.
            Rectangle { y: 6; width: parent.width; height: 1; color: Theme.text; transform: Scale { origin.x: 0; xScale: root.shown } }
            Rectangle { x: parent.width * root.shown; width: 1; height: 13; color: Theme.text }
        }
        Item {
            visible: root.start !== "" || root.end !== ""
            width: parent.width
            height: visible ? Theme.textXs * 1.6 : 0
            Quiet { text: root.start; anchors.left: parent.left }
            Quiet { text: root.end; anchors.right: parent.right }
        }
    }
}

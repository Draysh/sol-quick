import QtQuick

/* A row of slanted ticks (SlantTicks) lit to its value as it appears, following the value after. */
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
    Behavior on shown { NumberAnimation { duration: Theme.rise; easing: Theme.easeOut } }

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        SlantTicks {
            width: parent.width
            height: 7
            count: Math.max(6, Math.min(24, Math.round(width / 18)))
            value: root.shown
        }
        Item {
            visible: root.start !== "" || root.end !== ""
            width: parent.width
            height: visible ? Theme.textXs * 1.6 : 0
            // The end says the figures; the start gives way to it.
            Quiet { text: root.start; anchors.left: parent.left; width: Math.max(0, Math.min(implicitWidth, parent.width - (root.end !== "" ? endText.implicitWidth + Theme.s3 : 0))) }
            Quiet { id: endText; text: root.end; anchors.right: parent.right }
        }
    }
}

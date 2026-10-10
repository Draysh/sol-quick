import QtQuick

/*
    One row of the Shell's sidebar: a section (a mark, its name, a count)
    or, with `door`, a door to another app (its world's glyph, its name and
    under it what it is for). On the rail only the mark shows, and the hint
    names the row. The Sidebar lays them out.
*/
Settle {
    id: row

    property bool rail: false
    property string label: ""
    /** Under the name: what a door's app is for. */
    property string role: ""
    /** A world's glyph instead of the plain mark. */
    property string world: ""
    /** A count at the row's end (a section's), 0 for none. */
    property var badge: 0
    /** The whole hint, shown while the pointer is on the row. */
    property string hint: ""
    property bool current: false
    /** A door: its name rests brighter and stays put on hover. */
    property bool door: false
    signal clicked()

    height: Theme.control

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusM
        color: row.current ? Theme.surfaceHover : rowMouse.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        // One binding, not an anchor that comes and goes: a released anchor
        // leaves the row where it was put (off by a few pixels after the
        // sidebar starts as a rail for a moment).
        x: row.rail ? (row.width - width) / 2 : 12
        spacing: 12
        Item {
            width: 10; height: 10
            anchors.verticalCenter: parent.verticalCenter
            WorldGlyph { visible: row.world !== ""; world: row.world || "sol"; size: 10 }
            Rectangle {
                visible: row.world === ""
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: row.current ? Theme.textBright : "transparent"
                border.width: 1
                border.color: row.current || rowMouse.containsMouse ? Theme.textBright : Theme.lineStrong
                scale: rowMouse.containsMouse && !row.current ? 1.2 : 1
                Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                Behavior on color { ColorAnimation { duration: Theme.lock } }
                Behavior on border.color { ColorAnimation { duration: Theme.lock } }
            }
        }
        Column {
            visible: !row.rail
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: row.label
                width: Math.min(implicitWidth, row.width - (row.door ? 34 : 60 + (badge.visible ? 28 : 0)))
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                color: row.current || rowMouse.containsMouse ? Theme.textBright : row.door ? Theme.text : Theme.textQuiet
                transform: Translate { x: !row.door && rowMouse.containsMouse ? 2 : 0; Behavior on x { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Text {
                visible: row.role !== ""
                text: row.role
                width: Math.min(implicitWidth, row.width - 34)
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue
                color: Theme.textQuiet
            }
        }
    }
    Rectangle {
        id: badge
        visible: !!row.badge
        // At the row's end; on the rail, smaller, over the mark's shoulder.
        x: row.rail ? parent.width / 2 + 3 : parent.width - 12 - width
        y: row.rail ? 2 : (parent.height - height) / 2
        width: Math.max(height, badgeText.implicitWidth + (row.rail ? 6 : 10)); height: row.rail ? 14 : 18; radius: height / 2
        // The world's light, deepened by day, so the number reads on it in both.
        color: Theme.textWorld
        border.width: row.rail ? 2 : 0; border.color: row.current ? Theme.surfaceHover : Theme.deep
        Text { id: badgeText; anchors.centerIn: parent; text: row.badge || ""; font.family: Theme.font; font.pixelSize: row.rail ? 9 : 10; font.weight: Theme.weightLabel; color: Theme.space }
        onVisibleChanged: if (visible) pop.restart()
        SequentialAnimation { id: pop; NumberAnimation { target: badge; property: "scale"; from: 0.6; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }
    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
    Hint { text: row.hint; when: rowMouse.containsMouse }
}

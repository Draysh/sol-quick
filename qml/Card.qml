import QtQuick

/*
    A group: a panel raised off the night, its title in the world's light
    over a hairline, and two corner ticks that lock on to it under the
    pointer. Give it a width; it is as tall as what it holds.

        Card { title: "Log"; width: parent.width; Column { … } }
*/
Item {
    id: root

    property string title: ""
    /** Shows the world's glyph next to the title. */
    property string world: ""
    /** Shows an "Open" link in the header. */
    property bool openable: false
    signal opened()
    /** Its place in a grid, for the stagger. */
    property int index: 0
    property real gap: Theme.s3
    default property alias content: body.data
    /** Entries for a right-click (a list, or a function returning one): `{ label, run }`. */
    property var menu: null

    implicitHeight: body.y + body.implicitHeight + 20

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !!root.menu
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            const win = root.Window.window as AppWindow
            if (!win) return
            const p = root.mapToItem(null, mouse.x, mouse.y)
            win.menu.show(p.x, p.y, typeof root.menu === "function" ? root.menu() : root.menu)
        }
    }
    implicitWidth: 300

    // The card settles into place when it comes into view, then its ticks lock on.
    opacity: 0
    transform: Translate { id: shift; y: 6 }

    /** Arrived late (scrolled to): it comes at once, no stagger. */
    property bool late: false
    property var forget: null
    Component.onCompleted: forget = Theme.whenSeen(root, waited => { late = waited; arrive.start() })
    Component.onDestruction: if (forget) forget()
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.late ? 0 : Theme.delay(root.index) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            SequentialAnimation {
                PauseAnimation { duration: Theme.settle / 2 }
                ParallelAnimation {
                    NumberAnimation { target: ticks; property: "opacity"; from: 0; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                    NumberAnimation { target: ticks; property: "scale"; from: 0.3; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                }
            }
        }
    }

    // The panel: a step lighter than the pane, lit a little from above.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.raisedTop }
            GradientStop { position: 1; color: Theme.raised }
        }
        border.width: 1
        border.color: over.hovered ? Theme.lineMid : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }
    // Under the title, a hairline from edge to edge: the head, then the body.
    Rectangle { visible: head.visible; x: 1; y: head.y + head.height + 13; width: parent.width - 2; height: 1; color: Theme.line }
    HoverHandler { id: over }

    Item {
        id: ticks
        anchors.fill: parent
        opacity: 0
        scale: over.hovered ? 1.15 : 1
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        // Under the pointer only: the panel holds the group; the ticks lock on to it.
        Item {
            anchors.fill: parent
            opacity: over.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            Rectangle { x: -1; y: -1; width: 14; height: 1; color: Theme.textWorld }
            Rectangle { x: -1; y: -1; width: 1; height: 14; color: Theme.textWorld }
            Rectangle { x: parent.width - 13; y: parent.height; width: 14; height: 1; color: Theme.textWorld }
            Rectangle { x: parent.width; y: parent.height - 13; width: 1; height: 14; color: Theme.textWorld }
        }
    }

    Item {
        id: head
        x: 20; y: 16
        width: parent.width - 40
        height: visible ? 24 : 0
        visible: root.title !== "" || root.openable

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            WorldGlyph { visible: root.world !== ""; world: root.world; size: 10; anchors.verticalCenter: parent.verticalCenter }
            Label { text: root.title; color: Theme.textWorld; anchors.verticalCenter: parent.verticalCenter }
        }

        Item {
            visible: root.openable
            anchors.right: parent.right
            anchors.rightMargin: -8
            anchors.verticalCenter: parent.verticalCenter
            width: open.implicitWidth + 16
            height: Theme.target
            Row {
                id: open
                anchors.centerIn: parent
                spacing: 6
                Quiet { text: "Open"; color: openMouse.containsMouse ? Theme.textBright : Theme.textQuiet; Behavior on color { ColorAnimation { duration: Theme.fade } } }
                Icon {
                    name: "arrow-up-right"; size: 12
                    color: openMouse.containsMouse ? Theme.textBright : Theme.textQuiet
                    anchors.verticalCenter: parent.verticalCenter
                    transform: Translate { x: openMouse.containsMouse ? 1 : 0; y: openMouse.containsMouse ? -1 : 0; Behavior on x { NumberAnimation { duration: Theme.settle } } Behavior on y { NumberAnimation { duration: Theme.settle } } }
                }
            }
            MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened() }
        }
    }

    Column {
        id: body
        x: 20
        y: head.visible ? head.y + head.height + 14 + Math.max(root.gap, Theme.s3) : 20
        width: parent.width - 40
        spacing: root.gap
    }
}

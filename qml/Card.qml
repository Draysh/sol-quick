import QtQuick

/*
    A group, marked by two corner ticks instead of a box. The ticks lock on
    as the card appears. Give it a width; it is as tall as what it holds.

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

    implicitHeight: body.y + body.implicitHeight + 18

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !!root.menu
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            const win = root.Window.window
            if (!win || !win.hasOwnProperty("menu")) return
            const p = root.mapToItem(null, mouse.x, mouse.y)
            win.menu.show(p.x, p.y, typeof root.menu === "function" ? root.menu() : root.menu)
        }
    }
    implicitWidth: 300

    // The card settles into place when it comes into view, then its ticks lock on.
    opacity: 0
    transform: Translate { id: shift; y: 6 }

    /** The Flickable this scrolls in, if any. */
    function flickOf() { for (let it = parent; it; it = it.parent) if (it.hasOwnProperty("contentY") && it.hasOwnProperty("contentHeight") && it.hasOwnProperty("contentItem")) return it; return null }
    function inView(f) { if (f.height <= 0) return true; const y = mapToItem(f.contentItem, 0, 0).y; return y < f.contentY + f.height + 40 }
    /** Starts `arrival` now if on screen, else when scrolled to. */
    property var waitingOn: null
    property var waitingCheck: null
    function whenSeen(arrival) {
        const f = flickOf()
        if (!f || inView(f)) { arrival(); return }
        const check = () => { if (inView(f)) { unwait(); arrival() } }
        waitingOn = f; waitingCheck = check
        f.contentYChanged.connect(check)
    }
    function unwait() { if (waitingOn && waitingCheck) { waitingOn.contentYChanged.disconnect(waitingCheck) } waitingOn = null; waitingCheck = null }
    // Gone before it was seen: the Flickable must forget it.
    Component.onDestruction: unwait()
    Component.onCompleted: whenSeen(() => arrive.start())
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: Theme.delay(root.index) }
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

    Rectangle {
        anchors.fill: parent
        color: over.hovered ? Qt.rgba(1, 1, 1, 0.015) : "transparent"
        border.width: 1
        border.color: over.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }
    HoverHandler { id: over }

    Item {
        id: ticks
        anchors.fill: parent
        opacity: 0
        scale: over.hovered ? 1.15 : 1
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Rectangle { x: -1; y: -1; width: 14; height: 1; color: Theme.tick }
        Rectangle { x: -1; y: -1; width: 1; height: 14; color: Theme.tick }
        Rectangle { x: parent.width - 13; y: parent.height; width: 14; height: 1; color: Theme.tick }
        Rectangle { x: parent.width; y: parent.height - 13; width: 1; height: 14; color: Theme.tick }
    }

    Item {
        id: head
        x: 20; y: 18
        width: parent.width - 40
        height: visible ? 24 : 0
        visible: root.title !== "" || root.openable

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            WorldGlyph { visible: root.world !== ""; world: root.world; size: 10; anchors.verticalCenter: parent.verticalCenter }
            Label { text: root.title; anchors.verticalCenter: parent.verticalCenter }
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
        y: head.visible ? head.y + head.height + root.gap : 18
        width: parent.width - 40
        spacing: root.gap
    }
}

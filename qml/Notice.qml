import QtQuick

/*
    One notice: it drops in, a hairline along its bottom runs out as its
    time does, and it waits while the pointer is on it. The Shell makes
    these from `Notices.list`.
*/
Item {
    id: root

    /** The row of `Notices.list`: id, world, title, body, tone, cycle. */
    property var model
    readonly property bool error: !!model && model.tone === "error"

    implicitHeight: content.implicitHeight + 28

    opacity: 0
    transform: Translate { id: drop; y: -16 }
    Component.onCompleted: arrive.start()
    ParallelAnimation {
        id: arrive
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: drop; property: "y"; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: root.error ? Theme.danger : Theme.lineMid
        Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0.02, 0.02, 0.02, 0.84) }
    }

    Row {
        id: content
        x: 18; y: 14
        width: parent.width - 18 - Theme.target
        spacing: 14
        WorldGlyph { world: root.model ? root.model.world : "sol"; size: 14; y: 2 }
        Column {
            width: parent.width - 28
            spacing: 2
            Label { text: root.model ? root.model.title : ""; width: parent.width }
            Words { visible: !!root.model && root.model.body !== ""; text: root.model ? root.model.body : ""; width: parent.width; small: true }
        }
    }
    Button {
        variant: "round"
        icon: "close"
        anchors.right: parent.right; anchors.rightMargin: 4
        y: 2
        onClicked: Notices.dismiss(root.model.id)
    }

    // How long it stays: a line that runs out.
    Rectangle {
        id: time
        x: 1; y: parent.height - 2
        width: parent.width - 2; height: 1
        color: root.error ? Theme.danger : Theme.lineStrong
        transform: Scale { id: left; origin.x: 0; xScale: 1 }
        NumberAnimation {
            id: run
            target: left; property: "xScale"; from: 1; to: 0
            duration: Notices.linger
            running: true
            paused: hover.hovered
        }
        Connections {
            target: root
            function onModelChanged() { run.restart() }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? Notices.hold(root.model.id) : Notices.release(root.model.id)
    }
}

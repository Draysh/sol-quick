import QtQuick

/*
    One notice: it drops in, a hairline along its bottom runs out as its
    time does, and it waits while the pointer is on it. The window makes
    these from `Notices.list`.
*/
Item {
    id: root

    // The row of `Notices.list`.
    required property int key
    required property string world
    required property string title
    required property string body
    required property string tone
    readonly property bool error: tone === "error"

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
        Glass { anchors.fill: parent; anchors.margins: 1; tint: Theme.tint(Theme.veil, 0.84) }
    }

    Row {
        id: content
        x: 18; y: 14
        width: parent.width - 18 - Theme.target
        spacing: 14
        WorldGlyph { world: root.world; size: 14; y: 2 }
        Column {
            width: parent.width - 28
            spacing: 2
            Label { text: root.title; width: parent.width }
            Words { visible: root.body !== ""; text: root.body; width: parent.width; small: true }
        }
    }
    Button {
        variant: "round"
        icon: "close"
        anchors.right: parent.right; anchors.rightMargin: 4
        y: 2
        onClicked: Notices.dismiss(root.key)
    }

    // How long it stays: a line that runs out.
    Rectangle {
        id: time
        x: 1; y: parent.height - 2
        width: parent.width - 2; height: 1
        color: root.error ? Theme.danger : Theme.lineStrong
        transform: Scale { id: left; origin.x: 0; xScale: 1 }
        // The line is the time: when it has run out, the notice goes.
        NumberAnimation {
            target: left; property: "xScale"; from: 1; to: 0
            duration: Notices.linger
            running: true
            paused: hover.hovered
            onFinished: Notices.dismiss(root.key)
        }
    }

    HoverHandler { id: hover }
}

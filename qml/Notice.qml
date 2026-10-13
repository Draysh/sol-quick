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
    /** A button's label (it runs what the notice was posted with), or "". */
    required property string action
    readonly property bool error: tone === "error"

    implicitHeight: content.implicitHeight + 28

    opacity: 0
    transform: Translate { id: drop; y: -16 }
    Component.onCompleted: arrive.start()
    ParallelAnimation {
        id: arrive
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.settle; easing: Theme.easeOut }
        NumberAnimation { target: drop; property: "y"; to: 0; duration: Theme.settle; easing: Theme.easeOut }
    }

    GlassPanel { id: panel; anchors.fill: parent; edge: root.error ? Theme.danger : Theme.lineMid; shade: 0.84 }

    Row {
        id: content
        x: 18; y: 14
        width: parent.width - 18 - Theme.s3
        spacing: 14
        WorldGlyph { world: root.world; size: 14; y: 2 }
        Column {
            width: parent.width - 28
            spacing: 2
            // The title, and the way to put it away at the end of its line.
            Item {
                width: parent.width
                height: Math.max(titleLabel.implicitHeight, close.height)
                Label { id: titleLabel; text: root.title; width: parent.width - close.width - Theme.s2; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    id: close
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    text: "×"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Theme.textL
                    color: closeMouse.containsMouse ? Theme.textBright : Theme.textQuiet
                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Dismiss"
                    MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notices.dismiss(root.key) }
                }
            }
            Words { visible: root.body !== ""; text: root.body; width: parent.width; small: true }
            Item { visible: root.action !== ""; width: 1; height: Theme.s2 }
            Button { visible: root.action !== ""; variant: "quiet"; text: root.action; onClicked: Notices.act(root.key) }
        }
    }

    // How long it stays: a line that runs out, between the corners.
    Rectangle {
        id: time
        x: panel.radius; y: parent.height - 2
        width: parent.width - panel.radius * 2; height: 1
        color: root.error ? Theme.danger : Theme.hudAccent
        transform: Scale { id: left; origin.x: 0; xScale: 1 }
        // The line is the time: when it has run out, the notice goes.
        NumberAnimation {
            target: left; property: "xScale"; from: 1; to: 0
            running: true
            // One with a button stays twice as long, and waits under the pointer.
            duration: root.action !== "" ? Notices.linger * 2 : Notices.linger
            paused: hover.hovered
            onFinished: Notices.dismiss(root.key)
        }
    }

    HoverHandler { id: hover }
}

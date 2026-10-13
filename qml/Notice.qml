import QtQuick

/*
    One notice: it drops in, a hairline along its bottom runs out as its
    time does, and it waits while the pointer is on it. A failure says its
    `jp` line first, in the world's voice, then its English, with its raw
    words folded under "Details" (open, they can be selected and copied,
    and the notice waits). The window makes these from `Notices.list`.
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
    /** Said before the body, in the world's voice, or "". */
    required property string jp
    /** The raw words behind "Details", or "". */
    required property string detail
    readonly property bool error: tone === "error"
    property bool detailsOpen: false

    implicitHeight: content.implicitHeight + 28

    opacity: 0
    transform: Translate { id: drop; y: -16 }
    Component.onCompleted: { arrive.start(); if (error) Sounds.error() }
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
            Text {
                visible: root.jp !== ""
                width: parent.width
                text: root.jp
                wrapMode: Text.Wrap
                // In the world's own face where it reads a little over a line's size (Lucy's Makinas at 18), as the navigator says it.
                readonly property int size: Theme.titleFloor > 0 && Theme.titleFloor <= Theme.textL - 1 ? Theme.titleFloor : Theme.textM
                font.family: Theme.titleFace(size); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(size); font.pixelSize: size
                color: Theme.textBright
            }
            Words { visible: root.body !== ""; text: root.body; width: parent.width; small: true }
            // The raw words, folded away.
            Item { visible: root.detail !== ""; width: 1; height: Theme.s1 }
            Text {
                id: disclose
                visible: root.detail !== ""
                text: (root.detailsOpen ? "▾ " : "▸ ") + "Details"
                font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold
                font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
                color: discloseMouse.containsMouse || disclose.activeFocus ? Theme.textBright : Theme.textQuiet
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: root.detailsOpen ? "Hide the details" : "Show the details"
                Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { event.accepted = true; root.detailsOpen = !root.detailsOpen } }
                MouseArea { id: discloseMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.detailsOpen = !root.detailsOpen }
                Item { anchors.fill: parent; anchors.margins: -3; Ticks { on: disclose.activeFocus; out: 2; radius: Theme.radiusS } }
            }
            TextEdit {
                visible: root.detailsOpen && root.detail !== ""
                width: parent.width
                text: root.detail
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                font.family: Theme.fontMono; font.pixelSize: Theme.textXs
                color: Theme.textQuiet
                selectionColor: Theme.tint(Theme.hudAccent, 0.4)
                selectedTextColor: Theme.textBright
            }
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
            paused: hover.hovered || root.detailsOpen
            onFinished: Notices.dismiss(root.key)
        }
    }

    HoverHandler { id: hover }
}

import QtQuick

/*
    A hairline with a playhead, dragged: a position in a track, a volume.
    `value` follows the pointer while it drags and `moved(value)` says
    where it let go (or, with `live`, every move).

        Slider { from: 0; to: duration; value: position; onMoved: v => seek(v) }
*/
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property bool live: false
    property bool dragging: false
    signal moved(real value)

    implicitHeight: 16
    implicitWidth: 120
    // Left and right step a twentieth; the change is a move like any other.
    activeFocusOnTab: true
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    function step(by) { moved(Math.max(from, Math.min(to, value + by * span / 20))) }
    Accessible.role: Accessible.Slider

    readonly property real span: Math.max(1e-6, to - from)
    readonly property real shown: dragging ? dragValue : value
    property real dragValue: 0
    readonly property real fill: Math.max(0, Math.min(1, (shown - from) / span))

    function at(x) { return from + Math.max(0, Math.min(1, x / width)) * span }

    Rectangle { x: 0; y: parent.height / 2; width: parent.width; height: 1; color: Theme.lineStrong }
    Rectangle { x: 0; y: parent.height / 2; width: parent.width * root.fill; height: 1; color: Theme.textBright }
    Rectangle {
        x: parent.width * root.fill - 4.5
        y: parent.height / 2 - 4.5
        width: 9; height: 9; radius: 4.5
        color: Theme.textBright
        scale: mouse.containsMouse || root.dragging || root.activeFocus ? 1.4 : 1
        Behavior on scale { NumberAnimation { duration: Theme.lock } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -6; anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // A Flickable around it doesn't take the drag away.
        preventStealing: true
        onPressed: m => { root.dragging = true; root.dragValue = root.at(m.x); if (root.live) root.moved(root.dragValue) }
        onPositionChanged: m => { if (root.dragging) { root.dragValue = root.at(m.x); if (root.live) root.moved(root.dragValue) } }
        onReleased: { root.dragging = false; root.moved(root.dragValue) }
        onCanceled: root.dragging = false
    }
}

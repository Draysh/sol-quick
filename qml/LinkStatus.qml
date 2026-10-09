pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

/*
    Where an app stands with Sol, in one line at the bottom of the sidebar:
    in sync, sending, or offline with what waits. A dot lights when the
    connection is up. `busy` names other work going on ("Syncing library").
*/
Column {
    id: root

    property bool online: false
    property int unsent: 0
    property string busy: ""
    property string warn: ""

    readonly property string line: online
        ? (busy !== "" ? busy : unsent ? "Sending " + unsent : "In sync")
        : (unsent ? "Offline · " + unsent + " to send" : "Offline")
    readonly property string title: online
        ? (unsent ? unsent + " change" + (unsent === 1 ? "" : "s") + " on the way to Sol" : "Connected to Sol; every change reaches it at once")
        : "Sol can't be reached; " + (unsent ? unsent + " change" + (unsent === 1 ? " waits" : "s wait") + " here until it can" : "changes made now wait here until it can")

    spacing: Theme.s2

    component Line: Row {
        id: line
        property string text: ""
        property color dot: Theme.textFaint
        property bool glow: false
        property string hint: ""
        spacing: 6
        Item {
            width: 5; height: 5
            anchors.verticalCenter: parent.verticalCenter
            RectangularShadow { anchors.fill: dotRect; radius: 2.5; blur: 8; color: Theme.tint(line.dot, line.glow ? 1 : 0); Behavior on color { ColorAnimation { duration: Theme.fade } } }
            Rectangle { id: dotRect; anchors.fill: parent; radius: 2.5; color: line.dot; Behavior on color { ColorAnimation { duration: Theme.fade } } }
        }
        Quiet { text: line.text; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, root.width - 12) }
        HoverHandler { id: hover }
        Hint { text: line.hint; when: hover.hovered; above: true }
    }

    Line { visible: root.warn !== ""; text: root.warn; dot: Theme.danger; hint: root.warn }
    Line { text: root.line; dot: root.online ? Theme.ok : Theme.textFaint; glow: root.online; hint: root.title }
}

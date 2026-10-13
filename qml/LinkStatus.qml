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
    /** Just the dots, centred (the Shell's rail): the words are in their hints. */
    property bool compact: false
    /** How wide its words may run (the sidebar keeps the navigator's head chip clear); its width unless set. */
    property real room: width

    readonly property string line: online
        ? (busy !== "" ? busy : unsent ? "Sending " + unsent : "In sync")
        : (unsent ? "Offline · " + unsent + " to send" : "Offline")
    /** What waits, on a line of its own when the whole line doesn't fit its room: "313 to send". */
    readonly property string waiting: !online && unsent ? unsent + " to send" : ""
    readonly property bool split: waiting !== "" && !compact && whole.implicitWidth + 11 > room
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
        x: root.compact ? (root.width - width) / 2 : 0
        // A dot alone is a small thing to point at: room around it.
        padding: root.compact ? 8 : 0
        Item {
            width: 5; height: 5
            anchors.verticalCenter: parent.verticalCenter
            RectangularShadow { anchors.fill: dotRect; radius: 2.5; blur: 8; color: Theme.tint(line.dot, line.glow ? 1 : 0); Behavior on color { ColorAnimation { duration: Theme.fade } } }
            Rectangle { id: dotRect; anchors.fill: parent; radius: 2.5; color: line.dot; Behavior on color { ColorAnimation { duration: Theme.fade } } }
        }
        Quiet { visible: !root.compact; text: line.text; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, root.room - 12) }
        HoverHandler { id: hover }
        Hint { text: root.compact ? line.text + " · " + line.hint : line.hint; when: hover.hovered; above: true }
    }

    Line { visible: root.warn !== ""; text: root.warn; dot: Theme.danger; hint: root.warn }
    Line { text: root.split ? "Offline" : root.line; dot: root.online ? Theme.ok : Theme.textFaint; glow: root.online; hint: root.title }
    // What waits, under "Offline", lined up with its words.
    Quiet { visible: root.split; x: 11; text: root.waiting }
    // The whole line, measured.
    Quiet { id: whole; visible: false; text: root.line }
}

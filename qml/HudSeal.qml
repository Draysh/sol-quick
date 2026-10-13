import QtQuick

/*
    A hanko: a small vermilion seal with one kanji pressed into it, set a
    little askew, as a stamp lands. Mercury's mark beside a heading
    (HudLabel draws one there); anything else may use it for a
    day stamped done. `round` makes it a summer stamp card's round stamp
    (Terra's habits, Luna's nights).

        HudSeal { text: "学"; size: 22 }
        HudSeal { text: "済"; round: true; color: Theme.hudAccent; paper: Theme.hud.ink }
*/
Item {
    id: root

    /** The kanji pressed in it: one character. */
    property string text: ""
    property real size: 20
    property color color: Theme.hud.seal || "#e2412e"
    /** The paper showing through: the words' colour. */
    property color paper: Theme.hud.washi || "#fff4da"
    /** Round, as the stamps on a summer stamp card are, rather than square. */
    property bool round: false
    /** How askew it landed, in degrees. */
    property real tilt: -4

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        rotation: root.tilt
        antialiasing: true
        radius: root.round ? width / 2 : 0
        color: root.color
        // The ink thins at the edge, as a real stamp does.
        border.width: 1
        border.color: Qt.lighter(root.color, 1.25)
        Rectangle { anchors.fill: parent; anchors.margins: 2; radius: root.round ? width / 2 : 0; color: "transparent"; border.width: 1; border.color: Theme.tint(root.paper, 0.55) }
        Text {
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Font.Black; font.pixelSize: Math.round(root.size * 0.6)
            color: root.paper
        }
    }
}

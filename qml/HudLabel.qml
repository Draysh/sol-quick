import QtQuick

/*
    A HUD label in the Yozora look: the world's mark, words in the mono
    face (capitals, tracked wide) and a Japanese tag after them in the
    world's light: "◆ CONTINUE WATCHING · 続きから". The mark is the
    flavour's (`Theme.flavour`): Saturn's diamond, Mercury's vermilion
    seal, Neptune's neon slashes, Terra's sun. Neptune's Japanese comes
    first instead, as a lit sign, the way a street's signs read:
    "[再生中] NOW PLAYING" (the slashes only when there is none). Card and
    HudPanel head with one; a page may use it for any heading of its own.

        HudLabel { text: "On air tonight"; jp: "今夜" }
*/
Row {
    id: root

    property string text: ""
    /** Japanese after the words, in the light: "今夜". */
    property string jp: ""
    /** The words' colour. */
    property color color: Theme.hudText
    /** The mark's and the tag's light. */
    property color light: Theme.hudAccent
    property int size: Theme.textXs
    /** The world's mark before the words. */
    property bool mark: true
    /** The words' room: a long label elides within it. */
    property real room: 10000

    spacing: 10

    /** Neptune's sign: the Japanese lit before the words. */
    readonly property bool sign: Theme.hud.motif === "neon" && jp !== ""

    // Neptune's sign: the Japanese, dark on the light, before the words.
    Rectangle {
        id: signBox
        visible: root.sign
        anchors.verticalCenter: parent.verticalCenter
        width: signText.implicitWidth + 10
        height: signText.implicitHeight + 2
        color: root.light
        Text {
            id: signText
            anchors.centerIn: parent
            text: root.jp
            font.family: Theme.fontTitle; font.pixelSize: root.size + 1; font.weight: Font.Black
            color: Theme.hud.ground
        }
    }
    // The mark, the flavour's own.
    Item {
        visible: root.mark && !root.sign
        width: Theme.hud.motif === "shrine" ? 16 : Theme.hud.motif === "neon" ? 14 : 8
        height: Math.max(16, words.implicitHeight)
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            visible: Theme.hud.motif === "dusk"
            anchors.centerIn: parent
            width: 6; height: 6; rotation: 45; antialiasing: true
            color: root.light
        }
        HudSeal {
            visible: Theme.hud.motif === "shrine"
            anchors.centerIn: parent
            size: 15
            text: root.jp !== "" ? root.jp.charAt(0) : Theme.hud.glyph
        }
        Text {
            visible: Theme.hud.motif === "neon"
            anchors.centerIn: parent
            text: "//"
            font.family: Theme.fontMono; font.pixelSize: root.size; font.weight: Font.Bold
            color: root.light
        }
        Rectangle {
            visible: Theme.hud.motif === "summer"
            anchors.centerIn: parent
            width: 7; height: 7; radius: 3.5
            color: Theme.hudSecond
            Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 6.5; color: "transparent"; border.width: 1; border.color: Theme.tint(Theme.hudSecond, 0.5) }
        }
    }
    Text {
        id: words
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        width: Math.min(implicitWidth, root.room - (root.sign ? signBox.width + root.spacing : root.mark ? 18 : 0) - (tag.visible ? tag.implicitWidth + root.spacing : 0))
        elide: Text.ElideRight
        font.family: Theme.fontMono; font.pixelSize: root.size; font.weight: Font.DemiBold
        font.letterSpacing: Theme.track(Theme.trackHud, root.size); font.capitalization: Font.AllUppercase
        color: root.color
    }
    Text {
        id: tag
        visible: root.jp !== "" && !root.sign
        anchors.verticalCenter: parent.verticalCenter
        text: "· " + root.jp
        font.family: Theme.fontTitle; font.pixelSize: root.size + 2; font.weight: Font.Bold
        color: root.light
    }
}

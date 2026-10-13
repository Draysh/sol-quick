import QtQuick
import QtQuick.Shapes

/*
    A HUD label: the world's mark, words in the HUD face (capitals,
    tracked wide) and a Japanese tag after them in the world's light, two
    pixels larger, in the title serif: "◆ CONTINUE WATCHING · 続きから". The mark is the
    flavour's (`Theme.flavour`): Saturn's diamond, Mercury's vermilion
    seal, Neptune's neon slashes, Terra's furin (a wind chime). Neptune's Japanese comes
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
            font.family: Theme.titleFace(root.size + 1); font.features: Theme.titleFeatures; font.pixelSize: root.size + 1; font.weight: Theme.titleWeight(root.size + 1)
            color: Theme.hud.ground
        }
    }
    // The mark, the flavour's own.
    Item {
        visible: root.mark && !root.sign
        width: Theme.hud.motif === "shrine" ? 16 : Theme.hud.motif === "neon" ? 14 : Theme.hud.motif === "summer" ? 10 : 8
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
            font.family: Theme.fontHud; font.pixelSize: root.size; font.weight: Font.Bold
            color: root.light
        }
        // A furin, the summer's wind chime: a round glass bell, its clapper's string and the paper strip the wind catches.
        Shape {
            visible: Theme.hud.motif === "summer"
            anchors.centerIn: parent
            width: 10; height: 17
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1.2; strokeColor: root.light; fillColor: Theme.tint(root.light, 0.3)
                startX: 1.6; startY: 8.4
                PathArc { x: 8.4; y: 8.4; radiusX: 4.2; radiusY: 4.2; useLargeArc: true }
                PathLine { x: 1.6; y: 8.4 }
            }
            Rectangle { x: 4.4; y: 0; width: 1.2; height: 2; color: root.light }
            Rectangle { x: 4.5; y: 8.4; width: 1; height: 2.6; color: Theme.tint(root.color, 0.6) }
            Rectangle { x: 3.3; y: 10.8; width: 3.4; height: 6; color: Theme.hudPrimary; rotation: 8; antialiasing: true }
        }
    }
    Text {
        id: words
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        width: Math.min(implicitWidth, root.room - (root.sign ? signBox.width + root.spacing : root.mark ? 18 : 0) - (tag.visible ? tag.implicitWidth + root.spacing : 0))
        elide: Text.ElideRight
        // A label of a few words is capitals, tracked; a longer one, or one with Japanese, as written.
        readonly property bool caps: Theme.capsFor(root.text)
        font.family: caps ? Theme.fontCaps : Theme.font; font.pixelSize: caps ? root.size : root.size + 1; font.weight: Font.DemiBold
        font.letterSpacing: caps ? Theme.track(Theme.trackHud, root.size) : 0; font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
        color: root.color
    }
    Text {
        id: tag
        visible: root.jp !== "" && !root.sign
        anchors.verticalCenter: parent.verticalCenter
        text: "· " + root.jp
        font.family: Theme.titleFace(root.size + 2); font.features: Theme.titleFeatures; font.pixelSize: root.size + 2; font.weight: Theme.titleWeight(root.size + 2)
        color: root.light
    }
}

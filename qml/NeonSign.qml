pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

/*
    A vertical neon sign, as a shop's hangs over a street in the rain: a
    word in katakana written down in a lit tube of the flavour's second
    light, in a thin frame of it, glowing on a dark board. It is drawn once
    and never moves. The neon flavour's (`Theme.hud.signs`): the first
    page's line down the right, and one beside a page's lead (Neptune's
    Album and Queue, Triton's On air); a few, never on every card.
    `catchLight()` switches it on as a tube catches: dark, two stutters
    of light, then on and held, with the flavour's sting (the opening's
    last beat, on the first page).

        NeonSign { text: "レコード"; height: 220 }
        NeonSign { id: sign; text: "ミュージック" }   …   sign.catchLight()
*/
Item {
    id: root

    /** The word, written down: katakana reads best (a long vowel stands upright). */
    property string text: ""
    /** The tube's light. */
    property color light: Theme.hudSecond
    /** The largest a character is drawn; a long word in a short sign is drawn smaller. */
    property int size: 24
    /** The tallest it may be, 0 for as tall as its word wants. */
    property real room: 0

    readonly property var glyphs: Array.from(text)
    readonly property real pad: Math.round(cell * 0.45)
    /** Each character's square, smaller when the word wouldn't fit the room. */
    readonly property real cell: {
        const want = Math.round(size * 1.08)
        if (room <= 0 || glyphs.length === 0) return want
        return Math.max(12, Math.min(want, Math.floor((room - size * 0.9) / glyphs.length)))
    }
    implicitWidth: Math.round(cell + pad * 2)
    implicitHeight: glyphs.length * cell + pad * 2
    width: implicitWidth
    height: implicitHeight

    // The board behind the tube: dark, so the light reads over a bright still, and lit a little by it.
    Rectangle { anchors.fill: parent; color: Theme.tint(Theme.hud.ground, 0.7) }
    Rectangle { anchors.fill: parent; anchors.margins: 3; color: Theme.tint(root.light, 0.07) }

    /** How lit the tube is, 0 to 1: lit, unless it is catching. */
    property real power: 1
    /** Switches it on as a neon tube catches (a stutter, then held), with its sting, after `wait` ms in the dark; at once with less motion. */
    function catchLight(wait) {
        if (Theme.calm || Theme.flicker === 0) { power = 1; return }
        catching.stop()
        dark.duration = wait || 0
        power = 0
        catching.start()
    }
    Settling { when: catching.running }
    SequentialAnimation {
        id: catching
        PauseAnimation { id: dark; duration: 0 }
        ScriptAction { script: Sounds.lit() }
        PropertyAction { target: root; property: "power"; value: 0.75 }
        PauseAnimation { duration: Theme.flicker }
        PropertyAction { target: root; property: "power"; value: 0.08 }
        PauseAnimation { duration: Theme.flicker * 2 }
        PropertyAction { target: root; property: "power"; value: 1 }
        PauseAnimation { duration: Theme.flicker }
        PropertyAction { target: root; property: "power"; value: 0.3 }
        PauseAnimation { duration: Theme.flicker }
        NumberAnimation { target: root; property: "power"; to: 1; duration: Theme.hit; easing: Theme.easeOut }
    }

    // The tube: its frame and the word, glowing in its own light.
    Item {
        anchors.fill: parent
        opacity: root.power
        layer.enabled: root.visible && root.text !== ""
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.light; shadowBlur: 1; shadowOpacity: 1; shadowScale: 1.04; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 24; autoPaddingEnabled: true }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: "transparent"
            border.width: 2
            border.color: root.light
        }
        Column {
            x: root.pad
            y: root.pad
            Repeater {
                model: root.glyphs
                delegate: Item {
                    id: glyph
                    required property string modelData
                    width: root.cell
                    height: root.cell
                    // A long vowel, a dash or a wave stands upright, as it is written down.
                    readonly property bool turns: "ーー—～〜-".indexOf(modelData) >= 0
                    Text {
                        anchors.centerIn: parent
                        rotation: glyph.turns ? 90 : 0
                        text: glyph.modelData
                        font.family: Theme.fontJpSans; font.weight: Font.Bold; font.pixelSize: Math.round(root.cell / 1.08)
                        // The tube's hot core is nearly white; the glow round it is the light.
                        color: Qt.tint(root.light, Qt.rgba(1, 1, 1, 0.5)) // not a token: the tube's white-hot core, from its own light
                    }
                }
            }
        }
    }
}

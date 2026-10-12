pragma ComponentBehavior: Bound
import QtQuick

/*
    A page (or a card) with nothing in it yet, said with a little charm: a
    small still scene (the world, faint, on a thin orbit, with the page's
    own glyph as its moon), a line in the world's own voice, a quiet line
    on what fills it, and at most one way to start. Nothing moves: it is a
    picture, not an animation. In the Yozora look the scene is the glyph
    in a diamond, and the world's navigator says the line too (its page's
    `emptySay`).

        Empty { width: parent.width; icon: "bed"; line: "A quiet sky so far."; hint: "Nights appear here as you log them on Tonight." }
        Empty { compact: true; icon: "star"; line: "No stars yet."; action: "Rate something"; onActed: … }
*/
Item {
    id: root

    /** The page's glyph (an `Icon` name), riding the orbit; none leaves the orbit bare. */
    property string icon: ""
    /** The world drawn at the centre (the window's own unless given). */
    property string world: Sol.world
    /** The line in the world's voice: short, a sentence. */
    property string line: ""
    /** What fills the page, quietly: where things come from, what to do first. */
    property string hint: ""
    /** A way to start, as a button's words; empty for none. `acted` when pressed. */
    property string action: ""
    signal acted()
    /** Smaller, for inside a card: the scene beside the words instead of above them. */
    property bool compact: false

    implicitHeight: compact ? Math.max(scene.height, words.implicitHeight) : scene.height + Theme.s3 + words.implicitHeight
    height: implicitHeight

    // The navigator says the line while it shows (the Yozora look).
    readonly property var page: Theme.yozora ? Theme.screenOf(root) : null
    readonly property string says: line !== "" ? line + (hint !== "" ? " " + hint : "") : hint
    function tell() {
        const s = root.page
        if (!s || !s.hasOwnProperty("emptySay")) return
        if (root.visible && root.says !== "") s.emptySay = root.says
        else if (s.emptySay === root.says) s.emptySay = ""
    }
    onVisibleChanged: tell()
    onSaysChanged: tell()
    Component.onCompleted: tell()
    Component.onDestruction: { const s = root.page; if (s && s.hasOwnProperty("emptySay") && s.emptySay === root.says) s.emptySay = "" }

    // The scene: a faint orbit, the world at its middle, the glyph as a moon on it.
    Item {
        id: scene
        width: root.compact ? 72 : 132
        height: root.compact ? 52 : 92
        x: root.compact ? 0 : (root.width - width) / 2

        readonly property real rx: width / 2 - 6
        readonly property real ry: height / 2 - 10
        // The Yozora look's scene: the glyph in a diamond, in the world's light.
        Rectangle {
            visible: Theme.yozora
            anchors.centerIn: parent
            width: root.compact ? 30 : 46; height: width; rotation: 45; antialiasing: true
            color: Theme.tint(Theme.hudAccent, 0.1)
            border.width: 1.5; border.color: Theme.tint(Theme.hudAccent, 0.8)
        }
        Icon { visible: Theme.yozora; anchors.centerIn: parent; name: root.icon || "sparkles"; size: root.compact ? 14 : 20; stroke: 1.4; color: Theme.hudAccent }
        Canvas {
            id: orbit
            visible: !Theme.yozora
            anchors.fill: parent
            opacity: 0.55
            onPaint: {
                const g = getContext("2d")
                g.reset()
                g.strokeStyle = Theme.textFaint
                g.lineWidth = 1
                g.setLineDash([2, 4])
                g.beginPath()
                g.ellipse(6, 10, width - 12, height - 20)
                g.stroke()
            }
            Connections { target: Theme; function onDayChanged() { orbit.requestPaint() } }
        }
        Body {
            visible: !Theme.yozora
            world: root.world
            disc: root.compact ? 22 : 38
            animated: false
            anchors.centerIn: parent
            opacity: 0.5
        }
        // The moon: the page's glyph, up on the right of the orbit, on a disc of the pane's sky.
        Rectangle {
            visible: root.icon !== "" && !Theme.yozora
            readonly property real a: -0.85
            width: root.compact ? 22 : 30; height: width; radius: width / 2
            x: scene.width / 2 + scene.rx * Math.cos(a) - width / 2
            y: scene.height / 2 + scene.ry * Math.sin(a) - height / 2
            color: Theme.space
            Icon { anchors.centerIn: parent; name: root.icon; size: root.compact ? 14 : 18; stroke: 1.2; color: Theme.textQuiet }
        }
        // A star or two, still.
        Rectangle { visible: !Theme.yozora; x: 4; y: scene.height - 12; width: 2; height: 2; radius: 1; color: Theme.textFaint }
        Rectangle { visible: !Theme.yozora; x: scene.width - 10; y: scene.height - 6; width: 1.5; height: 1.5; radius: 1; color: Theme.textFaint }
    }

    Column {
        id: words
        x: root.compact ? scene.width + Theme.s3 : 0
        y: root.compact ? Math.max(0, (scene.height - implicitHeight) / 2) : scene.height + Theme.s3
        width: root.width - x
        spacing: Theme.s1
        Text {
            width: parent.width
            visible: text !== ""
            text: root.line
            horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Theme.font; font.pixelSize: root.compact ? Theme.textM : Theme.textL; font.weight: Theme.weightValue
            color: Theme.textBright
        }
        Words {
            width: parent.width
            visible: text !== ""
            text: root.hint
            small: true; quiet: true
            horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
        }
        Item { width: 1; height: Theme.s1; visible: root.action !== "" }
        Item {
            visible: root.action !== ""
            width: parent.width; height: start.height
            Button { id: start; text: root.action; x: root.compact ? 0 : (parent.width - width) / 2; onClicked: root.acted() }
        }
    }
}

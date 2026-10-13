pragma ComponentBehavior: Bound
import QtQuick

/*
    A page (or a card) with nothing in it yet, said with a little charm:
    the world's navigator, large, saying the line in its bubble (`jp`,
    then `line`, in the world's own voice), a quiet line on what fills it
    under them, and at most one way to start. Meanwhile the sidebar's
    navigator keeps quiet (its page's `emptySay`): one bubble at a time.
    Without the portrait, and always inside a card (`compact`), it is the
    page's glyph in a diamond in the world's light beside or over the
    words. Nothing moves but the line typing in as it shows.

        Empty { width: parent.width; icon: "bed"; jp: "まだ、静かな空。"; line: "A quiet sky so far."; hint: "Nights appear here as you log them on Tonight." }
        Empty { compact: true; icon: "star"; line: "No stars yet."; action: "Rate something"; onActed: … }
*/
Item {
    id: root

    /** The page's glyph (an `Icon` name), in the diamond; sparkles when none. */
    property string icon: ""
    /** The world it is about (the window's own unless given). */
    property string world: Sol.world
    /** The line in the world's voice: short, a sentence. */
    property string line: ""
    /** The line in Japanese, said first in the navigator's bubble. */
    property string jp: ""
    /** What fills the page, quietly: where things come from, what to do first. */
    property string hint: ""
    /** A way to start, as a button's words; empty for none. `acted` when pressed. */
    property string action: ""
    signal acted()
    /** Smaller, for inside a card: the scene beside the words instead of above them. */
    property bool compact: false

    /** The navigator stands beside the words: a page's empty state, with the portrait here. */
    readonly property bool navigated: !compact && navFace.here
    implicitHeight: navigated ? talk.height + Theme.s3 + after.implicitHeight
        : compact ? Math.max(scene.height, words.implicitHeight) : scene.height + Theme.s3 + words.implicitHeight
    height: implicitHeight

    // The sidebar's navigator keeps quiet while this one speaks.
    readonly property var page: Theme.screenOf(root)
    readonly property string says: navigated ? jp + line : ""
    function tell() {
        const s = root.page
        if (!s || !s.hasOwnProperty("emptySay")) return
        if (root.visible && root.says !== "") s.emptySay = root.says
        else if (s.emptySay === root.says) s.emptySay = ""
    }
    onVisibleChanged: { tell(); if (visible && navigated) { bubble.say(); navFace.bob() } }
    onSaysChanged: tell()
    Component.onCompleted: tell()
    Component.onDestruction: { const s = root.page; if (s && s.hasOwnProperty("emptySay") && s.emptySay === root.says) s.emptySay = "" }

    // The navigator, large, and its bubble beside it; what fills the page and the way to start under them.
    Item {
        id: talk
        visible: root.navigated
        readonly property real faceWidth: Math.min(128, Math.max(88, root.width * 0.2))
        readonly property real bubbleWidth: Math.min(380, bubble.naturalWidth, root.width - faceWidth - Theme.s4)
        width: faceWidth + Theme.s4 + bubbleWidth
        height: Math.max(navFace.height, bubble.implicitHeight)
        x: (root.width - width) / 2
        NavigatorFace { id: navFace; world: root.world; width: talk.faceWidth; height: Math.round(talk.faceWidth * 1.3); y: talk.height - height }
        Speech {
            id: bubble
            x: talk.faceWidth + Theme.s4
            y: Math.max(0, (navFace.height - implicitHeight) / 2 - Theme.s3)
            width: talk.bubbleWidth
            large: true
            jp: root.jp
            line: root.line
            tail: "left"
            tailAt: Math.min(bodyHeight - tailWidth - Theme.radiusSpeech, Math.max(Theme.radiusSpeech, bodyHeight * 0.55))
        }
    }
    Column {
        id: after
        visible: root.navigated
        y: talk.height + Theme.s3
        x: (root.width - width) / 2
        width: Math.min(root.width, Math.max(talk.width, 420))
        spacing: Theme.s2
        Words {
            width: parent.width
            visible: text !== ""
            text: root.hint
            small: true; quiet: true
            horizontalAlignment: Text.AlignHCenter
        }
        Item {
            visible: root.action !== ""
            width: parent.width; height: startNav.height
            Button { id: startNav; text: root.action; x: (parent.width - width) / 2; onClicked: root.acted() }
        }
    }

    // The scene: the glyph in a diamond, in the world's light.
    Item {
        id: scene
        visible: !root.navigated
        width: root.compact ? 72 : 132
        height: root.compact ? 52 : 92
        x: root.compact ? 0 : (root.width - width) / 2

        Rectangle {
            anchors.centerIn: parent
            width: root.compact ? 30 : 46; height: width; rotation: 45; antialiasing: true
            color: Theme.tint(Theme.hudAccent, 0.1)
            border.width: 1.5; border.color: Theme.tint(Theme.hudAccent, 0.8)
        }
        Icon { anchors.centerIn: parent; name: root.icon || "sparkles"; size: root.compact ? 14 : 20; stroke: 1.4; color: Theme.hudAccent }
    }

    Column {
        id: words
        visible: !root.navigated
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

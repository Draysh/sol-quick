pragma ComponentBehavior: Bound
import QtQuick

/*
    The world's navigator in the sidebar's foot: a character's portrait
    (`NavigatorFace`) in a cut frame that breaks the rail's edge a little,
    its name beside it (案内役, the name, NAVIGATOR), and over it what it
    says about the page in a speech bubble (`Speech`): the Japanese line,
    then the English. A moon's pages have their planet's. Without a line
    it keeps quiet: the portrait alone, no bubble.

    Where the rows leave no room for it (a short window, the narrow rail)
    it is a head chip instead, the face in a small diamond on the rail's
    edge, whose bubble opens beside it over the page on hover or a click.
    It hops when a line arrives, leans towards a page as it opens, and
    cheers on `Sol.cheer()`. Without the portrait it isn't there at all.

        Navigator { width: parent.width; jp: shell.navigatorJp; line: shell.navigatorLine; looking: shell.path; space: room }
*/
Item {
    id: root

    /** What it says in English: a sentence, about 60 characters at most. */
    property string line: ""
    /** What it says in Japanese, over the English. */
    property string jp: ""
    /** Whose navigator: the window's world (a moon's is its planet's). */
    property string world: Sol.world
    /** What it is looking at (the page's path): when it changes, it leans towards it. */
    property var looking: null
    /** The height the sidebar can give it. */
    property real space: 0
    /** On the narrow rail: always the chip. */
    property bool narrow: false
    /** How far its right edge is from the rail's edge, which the frame breaks. */
    property real edge: 0
    /** Away: it has stepped into the page (an empty state's own navigator speaks there). */
    property bool away: false

    /** Whether there is one to show: the portrait is here. */
    readonly property bool here: face.here && !away
    readonly property bool says: line !== "" || jp !== ""
    /** The bubble's height over the portrait, with its gap. */
    readonly property real speechHeight: says ? speech.implicitHeight + Theme.s2 : 0
    /** The line is said in the world's own face when the bubble that takes still leaves the portrait its room; else in the display face, smaller. */
    readonly property bool voiced: narrow || space >= (says ? voicedProbe.implicitHeight + Theme.s2 : 0) + smallestFrame
    // The bubble as it would be in the world's face, measured unseen.
    Speech { id: voicedProbe; visible: false; still: true; width: Math.min(root.bubbleRoom, naturalWidth); jp: root.jp; line: root.line; tail: "down"; voiced: true }
    /** How wide the bubble may be: from the rail's inner edge to the frame's outer one. */
    readonly property real bubbleRoom: width + edge + Theme.s2 + 4
    /** How tall it is with its bubble over the portrait, at the smallest the portrait goes. */
    readonly property real fullHeight: speechHeight + smallestFrame
    /** The chip, when the bubble and the portrait don't fit. */
    readonly property bool chip: narrow || space < fullHeight
    /** How far it reaches past the rail's edge into the page. */
    readonly property real reach: !here ? 0 : chip ? (narrow ? 0 : chipBox.x + chipBox.width - width - edge) : frame.x + frame.width - width - edge

    // The portrait grows into the room the rows leave, between these: at most as wide as leaves
    // its name (案内役, the name, NAVIGATOR) a column beside it.
    readonly property real smallestFrame: 88
    readonly property real largestFrame: Math.round(Math.min(176, (width + edge + Theme.s2 + 4 - 84) / 0.76))
    readonly property real frameHeight: Math.round(Math.max(smallestFrame, Math.min(largestFrame, space - speechHeight)))
    readonly property real frameWidth: Math.round(frameHeight * 0.76)
    readonly property real chipSize: 50
    /** Where the head chip starts across it (the diamond's left point), so the status beside it ends short of it. */
    readonly property real chipLeft: chipBox.x
    /** Where the diamond's edge is across it at `h` above or below its middle: words beside its point may run that far. */
    function chipEdge(h) { return chipBox.x + Math.min(chipSize / 2, Math.abs(h)) }

    implicitHeight: !here ? 0 : chip ? chipSize : speechHeight + frameHeight
    visible: here

    /** Says its line again: the chip opens its bubble (until the next page or a click), the portrait's bubble types it in anew. */
    function tell() {
        if (!says) return
        if (chip) pop.pinned = true
        else speech.say()
        face.bob(); chipFace.bob()
    }

    // A line arriving makes it hop and its bubble slide in from the portrait's side (not the
    // first, as the window opens); a new page, lean.
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => root.ready = true)
    readonly property string said: jp + "\n" + line
    onSaidChanged: if (ready && says) { face.bob(); chipFace.bob(); if (!Theme.calm && !chip) slideIn.restart() }
    SequentialAnimation {
        id: slideIn
        PropertyAction { target: speechShift; property: "x"; value: Theme.s3 }
        PropertyAction { target: speech; property: "opacity"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: speech; property: "opacity"; to: 1; duration: Theme.hit; easing: Theme.easeOut }
            NumberAnimation { target: speechShift; property: "x"; to: 0; duration: Theme.land; easing: Theme.easeOut }
        }
    }
    onLookingChanged: if (ready) face.lean()

    // ---- With room: the bubble over the portrait, its name beside it --------------
    Speech {
        id: speech
        visible: !root.chip && root.says
        // Its right edge on the frame's, which breaks the rail's edge: as wide as the two reach.
        x: frame.x + frame.width - width
        width: Math.min(root.bubbleRoom, naturalWidth)
        jp: root.jp
        line: root.line
        voiced: root.voiced
        transform: Translate { id: speechShift }
        tail: "down"
        tailAt: Math.max(Theme.radiusSpeech + 2, Math.min(width - tailWidth - Theme.radiusSpeech, frame.x + frame.width * 0.42 - tailWidth / 2 - x))
    }
    Item {
        id: frame
        visible: !root.chip
        x: root.width + root.edge + Theme.s2 + 4 - width
        y: root.speechHeight
        width: root.frameWidth; height: root.frameHeight
        NavigatorFace { id: face; anchors.fill: parent; world: root.world; lit: frameMouse.containsMouse }
        // A click says it again.
        MouseArea { id: frameMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.tell() }
    }
    Column {
        visible: !root.chip
        x: 0
        anchors.bottom: frame.bottom
        width: frame.x - Theme.s2
        spacing: 2
        Text {
            text: "案内役"
            font.family: Theme.titleFace(Theme.textXs + 1); font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 1; font.weight: Theme.titleWeight(Theme.textXs + 1)
            color: Theme.hudAccent
        }
        Text {
            width: parent.width
            text: Theme.yozoraOf(root.world).navigator || ""
            elide: Text.ElideRight
            font.family: Theme.fontCaps; font.pixelSize: Theme.textS; font.weight: Font.Bold
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textS); font.capitalization: Font.AllUppercase
            color: Theme.hudText
        }
        Text {
            text: "Navigator"
            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs - 1
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.hudFaint
        }
    }

    // ---- Without: the head chip on the rail's edge, its bubble beside it ------------
    Item {
        id: chipBox
        visible: root.chip
        // Inside the rail's edge: beside the status the page's footer (Neptune's player) may sit just past it.
        x: root.narrow ? (root.width - width) / 2 : root.width + root.edge - width - Theme.s2
        width: root.chipSize; height: root.chipSize
        NavigatorFace { id: chipFace; anchors.fill: parent; world: root.world; diamond: true; lit: chipHover.hovered || pop.pinned }
        HoverHandler { id: chipHover; cursorShape: root.says ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: pop.pinned = !pop.pinned && root.says }
    }
    // Over the page, beside the chip, while the pointer is on it or after a click.
    Item {
        id: pop
        property bool pinned: false
        readonly property bool open: root.chip && root.says && (pinned || chipHover.hovered || popHover.hovered)
        x: chipBox.x + chipBox.width + Theme.s2
        width: Math.min(260, popSpeech.naturalWidth)
        height: popSpeech.implicitHeight
        // The tail's tip at the chip's middle.
        y: chipBox.y + chipBox.height / 2 - popSpeech.tailAt - popSpeech.tailWidth * 0.9
        visible: opacity > 0
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing: Theme.easeOut } }
        transform: Translate { x: pop.open ? 0 : -Theme.s2; Behavior on x { NumberAnimation { duration: Theme.fade; easing: Theme.easeOut } } }
        onOpenChanged: if (open) popSpeech.say()
        HoverHandler { id: popHover; enabled: pop.open }
        // A click on it puts it away.
        TapHandler { enabled: pop.open; onTapped: pop.pinned = false }
        Speech {
            id: popSpeech
            width: parent.width
            jp: root.jp
            line: root.line
            tail: "left"
            tailAt: Math.max(Theme.radiusSpeech, bodyHeight - tailWidth - Theme.radiusSpeech)
        }
    }
    // A new page closes a bubble left open.
    Connections { target: root; function onLookingChanged() { pop.pinned = false } }
}

pragma ComponentBehavior: Bound
import QtQuick

/*
    A world's first-run tour: three cards over the window (what this world
    does, its best key, where to start), shown once on a device the first
    time the window is in front, skippable at any card, and open again
    from the `?` sheet or the palette ("Take the tour"). The window has one
    (`win.tour`) and fills it from its `tour` list:

        AppWindow { tour: [
            { icon: "cards", title: "Japanese, a little every day", body: "…" },
            { icon: "languages", title: "Its best key", body: "…", keys: "R" },
            { icon: "book-open", title: "Where to start", body: "…", go: "/kana", start: "Open Kana" } ] }

    → or Enter goes on, ← back, Escape skips. On the last card the main
    button goes to `go` (when given) and closes.
*/
FocusScope {
    id: root

    /** The cards: `{ title, body, keys?, icon?, go?, start? }`. */
    property var cards: []
    /** The card showing, while open. */
    property int at: 0
    readonly property bool shown: opacity > 0
    property bool open: false
    readonly property var card: cards[at] || ({})
    readonly property bool last: at >= cards.length - 1
    property Item before: null
    /** The world whose body heads a card without an icon. */
    property string world: Sol.world
    /** Where a last card's `go` leads: the window's Shell. */
    property var go: null
    signal closed()

    anchors.fill: parent
    z: 190
    visible: opacity > 0
    opacity: open ? 1 : 0
    enabled: open
    Settling { when: tourFade.running }
    Behavior on opacity { NumberAnimation { id: tourFade; duration: Theme.calm ? Theme.fade : Theme.rise; easing: Theme.easeOut } }

    /** Opens the tour at its first card. */
    function show() {
        if (!cards.length || open) return
        at = 0
        before = root.Window.activeFocusItem
        open = true
        root.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        if (before) before.forceActiveFocus()
        before = null
        closed()
    }
    function next() {
        if (!last) { at++; return }
        const to = card.go
        close()
        if (to && go) go(to)
    }
    function previous() { if (at > 0) at-- }

    Keys.onPressed: event => {
        event.accepted = true
        if (event.key === Qt.Key_Escape) close()
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) next()
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) previous()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.tint(Theme.veil, 0.72)
        MouseArea { anchors.fill: parent; onClicked: { } }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(420, parent.width - Theme.s4 * 2)
        height: body.implicitHeight + Theme.s4 * 2
        radius: Theme.radiusL
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.raisedTop }
            GradientStop { position: 1; color: Theme.raised }
        }
        border.width: 1; border.color: Theme.lineMid
        // Each card arrives a little from the right.
        property int shownAt: root.at
        onShownAtChanged: { slide.restart() }
        transform: Translate { id: shift }
        SequentialAnimation {
            id: slide
            PropertyAction { target: body; property: "opacity"; value: 0 }
            PropertyAction { target: shift; property: "x"; value: Theme.calm ? 0 : 14 }
            ParallelAnimation {
                NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.settle; easing: Theme.easeOut }
                NumberAnimation { target: shift; property: "x"; to: 0; duration: Theme.settle; easing: Theme.easeOut }
            }
        }

        Column {
            id: body
            x: Theme.s4; y: Theme.s4
            width: panel.width - Theme.s4 * 2
            spacing: Theme.s3

            Item {
                width: parent.width; height: 56
                Body { world: root.world; disc: 44; animated: false; anchors.verticalCenter: parent.verticalCenter; visible: !root.card.icon }
                Rectangle {
                    visible: !!root.card.icon
                    width: 44; height: 44; radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.tint(Theme.world, 0.12)
                    border.width: 1; border.color: Theme.tint(Theme.world, 0.35)
                    Icon { anchors.centerIn: parent; name: root.card.icon || "info"; size: 20; color: Theme.world }
                }
                Quiet {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: (root.at + 1) + " of " + root.cards.length
                }
            }
            Text {
                width: parent.width
                text: root.card.title || ""
                wrapMode: Text.Wrap
                font.family: Theme.font; font.pixelSize: Theme.textL; font.weight: Theme.weightValue
                color: Theme.textBright
            }
            Words { width: parent.width; text: root.card.body || "" }
            // The key, as a keycap.
            Row {
                visible: !!root.card.keys
                spacing: Theme.s2
                Repeater {
                    model: root.card.keys ? String(root.card.keys).split(" ") : []
                    delegate: Rectangle {
                        id: cap
                        required property string modelData
                        width: Math.max(34, capText.implicitWidth + 20); height: 34
                        radius: Theme.radiusM
                        color: Theme.tint(Theme.ink, 0.05)
                        border.width: 1; border.color: Theme.lineStrong
                        Text {
                            id: capText
                            anchors.centerIn: parent
                            text: cap.modelData
                            font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: Theme.weightLabel
                            color: Theme.textBright
                        }
                    }
                }
            }
            Item { width: 1; height: Theme.s1 }
            Item {
                width: parent.width; height: Theme.control
                // Where the tour stands: a dot a card.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: root.cards.length
                        delegate: Rectangle {
                            required property int index
                            width: index === root.at ? 16 : 6; height: 6; radius: 3
                            color: index === root.at ? Theme.world : Theme.lineStrong
                            Behavior on width { NumberAnimation { duration: Theme.fade } }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: Theme.s2
                    Button { variant: "quiet"; text: root.last ? "Close" : "Skip"; hint: "Esc"; onClicked: root.close() }
                    Button { variant: "primary"; text: root.last ? (root.card.start || "Start") : "Next"; hint: root.last ? "" : "→ or Enter"; onClicked: root.next() }
                }
            }
        }
    }
}

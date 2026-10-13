import QtQuick

/*
    A group: a panel of glass over the still with its top-right corner
    cut, its title a HUD label (with its `jp`) over a hairline, and
    brackets in the world's light under the pointer. Give it a width; it
    is as tall as what it holds. A card that
    is a thing (a title, a deck, a station) has a `menu`: right-click it,
    or the ⋯ in its head.

        Card { title: "Log"; width: parent.width; Column { … } }
        Card { title: "Spirited Away"; menu: () => Saturn.titleMenu(title); … }
*/
Item {
    id: root

    property string title: ""
    /** Its title in Japanese, after the English: "続きから". */
    property string jp: ""
    /** The world it is about (a moon's card in its planet's settings). */
    property string world: ""
    /** Shows an "Open" link in the header. */
    property bool openable: false
    signal opened()
    /** Its place in a grid, for the stagger. */
    property int index: 0
    /** How many of a Grid's columns it takes: 1, 2, or "row" for the whole row. */
    property var span: 1
    property real gap: Theme.s3
    default property alias content: body.data
    /** Its menu, on a right-click and under the ⋯ in its head: ContextMenu's entries (a list, or a function returning one). */
    property var menu: null
    /** Its ⋯ (there while it has a `menu`), for opening the menu from elsewhere. */
    readonly property alias moreButton: more
    /** Its corners: `Theme.radius`, or `Theme.radiusL` for the dialog. */
    property real radius: Theme.radius

    implicitHeight: body.y + body.implicitHeight + 20
    /** The room its Grid gives it past its own height, to end level with the card beside it (set by the Grid). */
    property real spare: 0

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !!root.menu
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            const win = root.Window.window as AppWindow
            if (win) win.menu.openAt(root, mouse, root.menu)
        }
    }
    implicitWidth: 300

    /** It does something when clicked (an Open link makes it so too): it gives under a press. */
    property bool pressable: false

    // The card comes into place when it comes into view, in the world's beat (`Theme.beat`):
    // Neptune's slides in and flickers once, Saturn's cuts in, Mercury's shows through like ink,
    // Terra's comes up with a light bounce; and it leans towards the pointer.
    opacity: 0
    property Translate shift: Translate { y: Theme.calm ? 0 : Theme.beat.rise; x: Theme.calm ? 0 : Theme.beat.slide }
    // Grows from its top a little as it settles; a tall one hardly at all, so its top stays where it is.
    property Scale pop: Scale { origin.x: root.width / 2; origin.y: 0; xScale: Theme.calm ? 1 : Theme.beat.grow; yScale: 1 - (1 - xScale) * Math.min(1, 400 / Math.max(1, root.height)) }
    property Translate moved: Translate { }
    transform: [shift, pop, moved, lean.shift, lean.push]

    /** Placed somewhere else by its Grid: it glides there from `dx`, `dy` away (not with less motion, nor before it has arrived). */
    function glide(dx, dy) {
        if (Theme.calm || Theme.settle === 0 || (opacity === 0 && !arrive.running)) return
        gliding.stop()
        root.moved.x += dx
        root.moved.y += dy
        gliding.start()
    }
    Settling { when: gliding.running }
    ParallelAnimation {
        id: gliding
        NumberAnimation { target: root.moved; property: "x"; to: 0; duration: Theme.settle; easing: Theme.easeOut }
        NumberAnimation { target: root.moved; property: "y"; to: 0; duration: Theme.settle; easing: Theme.easeOut }
    }

    /** Arrived late (scrolled to): it comes at once, no stagger. */
    property bool late: false
    property var forget: null
    /** It has come into view: its glass is made then, not before (a card far down a page costs nothing until it is scrolled to). */
    property bool seen: false
    // Started once the page has had its say, so a page turning has told when it lands.
    Component.onCompleted: forget = Theme.whenSeen(root, waited => { late = waited; seen = true; Qt.callLater(() => { if (root) root.start() }) })
    Component.onDestruction: if (forget) forget()
    /** The first card of a page (its Grid's first): its brackets light in the world's light as it lands, then go. */
    property bool lead: false
    /** How long until it arrives: its stagger, and while its page turns, until the page lands. */
    property real pause: 0
    function start() {
        const page = Theme.screenOf(root)
        const lands = page && page.landsAt ? Math.max(0, page.landsAt - Date.now()) : 0
        pause = root.late ? 0 : Theme.delay(root.index) + lands
        arrive.restart()
    }
    Settling { when: arrive.running }
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.pause }
        // A flicker first (Neptune's beat): a glimpse, gone, then it comes.
        PropertyAction { target: root; property: "opacity"; value: Theme.beat.flick && !Theme.calm && !root.late ? 0.5 : 0 }
        PauseAnimation { duration: Theme.beat.flick && !Theme.calm && !root.late ? Theme.flicker : 0 }
        PropertyAction { target: root; property: "opacity"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.beat.arrive; easing: Theme.easeOut }
            NumberAnimation { target: root.shift; property: "y"; to: 0; duration: Theme.beat.arrive; easing: Theme.beat.curve }
            NumberAnimation { target: root.shift; property: "x"; to: 0; duration: Theme.beat.arrive; easing: Theme.easeOut }
            NumberAnimation { target: root.pop; property: "xScale"; to: 1; duration: Theme.beat.arrive; easing: Theme.spring }
        }
        ScriptAction { script: if (root.lead && !root.late && !Theme.calm) leading.restart() }
    }
    // The lead's accent: its brackets lit at once as it lands, held a beat, then gone.
    property real leadGlow: 0
    SequentialAnimation {
        id: leading
        PropertyAction { target: root; property: "leadGlow"; value: 1 }
        PauseAnimation { duration: Theme.hold }
        NumberAnimation { target: root; property: "leadGlow"; to: 0; duration: Theme.fade; easing: Theme.easeIn }
    }

    // The panel: glass over the still with its top-right corner cut, and brackets in the light under the pointer.
    Loader {
        anchors.fill: parent
        active: root.seen
        sourceComponent: HudGlass { cuts: [0, Theme.hudCut, 0, 0] }
        onLoaded: { const g = item as HudGlass; if (g) g.glow = Qt.binding(() => root.pointed ? 1 : 0) }
    }
    HudBrackets {
        anchors.fill: parent
        cuts: [0, Theme.hudCut, 0, 0]
        color: Theme.tint(Theme.hudAccent, lean.hovered ? 0.9 : root.leadGlow)
        Behavior on color { enabled: !leading.running; ColorAnimation { duration: Theme.fade } }
    }
    // Under the title, a hairline from edge to edge: the head, then the body.
    Rectangle { visible: head.visible; x: 20; y: head.y + head.height + 13; width: parent.width - 40; height: 1; color: Theme.line }
    /** The pointer is on it: its glass's edge and brackets light. */
    readonly property bool pointed: lean.hovered

    Item {
        id: head
        x: 20; y: 16
        width: parent.width - 40
        height: visible ? 24 : 0
        visible: root.title !== "" || root.openable

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            // A long title elides before the Open link.
            readonly property real room: head.width - (openLink.visible ? openLink.width - 8 + Theme.s3 : 0) - (more.visible ? more.width - 8 + Theme.s3 : 0)
            HudLabel { visible: root.title !== ""; anchors.verticalCenter: parent.verticalCenter; text: root.title; jp: root.jp; room: parent.room }
        }

        Item {
            id: openLink
            visible: root.openable
            activeFocusOnTab: visible
            Accessible.role: Accessible.Link
            Accessible.name: "Open " + root.title
            Accessible.onPressAction: root.opened()
            Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { event.accepted = true; if (!event.isAutoRepeat) root.opened() } }
            Item { anchors.centerIn: parent; width: open.width + 8; height: open.height + 8; Ticks { on: openLink.activeFocus; out: 2; radius: Theme.radiusS } }
            anchors.right: more.visible ? more.left : parent.right
            anchors.rightMargin: more.visible ? 0 : -8
            anchors.verticalCenter: parent.verticalCenter
            width: open.implicitWidth + 16
            height: Theme.target
            Row {
                id: open
                anchors.centerIn: parent
                spacing: 6
                Quiet { text: "Open"; color: openMouse.containsMouse || openLink.activeFocus ? Theme.textBright : Theme.textQuiet; Behavior on color { ColorAnimation { duration: Theme.fade } } }
                Icon {
                    name: "arrow-up-right"; size: 12
                    color: openMouse.containsMouse || openLink.activeFocus ? Theme.textBright : Theme.textQuiet
                    anchors.verticalCenter: parent.verticalCenter
                    transform: Translate { x: openMouse.containsMouse ? 1 : 0; y: openMouse.containsMouse ? -1 : 0; Behavior on x { NumberAnimation { duration: Theme.settle } } Behavior on y { NumberAnimation { duration: Theme.settle } } }
                }
            }
            MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened() }
        }
        // The card's menu, for a pointer that doesn't right-click and for the keys.
        MoreButton {
            id: more
            visible: !!root.menu
            menu: root.menu
            hint: root.title !== "" ? "More for " + root.title : "More"
            anchors.right: parent.right
            anchors.rightMargin: -8
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: body
        // Drawn taller to end level with its pair (Grid), what it holds sits in the middle.
        transform: Translate { y: root.spare / 2 }
        x: 20
        y: head.visible ? head.y + head.height + 14 + Math.max(root.gap, Theme.s3) : 20
        width: parent.width - 40
        spacing: root.gap
    }

    Lean { id: lean; anchors.fill: parent; presses: root.pressable || root.openable }

    /** Its brackets lock onto it from a little way out, as a reticle finding its target, and a few
        sparks fly: for a thing that has just gone live (a station on air). Nothing with less motion. */
    function lockOn() {
        if (Theme.calm || Theme.settle === 0) return
        lock.active = true
        if (lock.item) (lock.item as CardLock).play()
        if (lockSpark.item) (lockSpark.item as Spark).burst(); else lockSpark.active = true
        sparked.restart()
    }
    // Made the first time it locks on, so a card that never does costs nothing for it.
    component CardLock: HudBrackets {
        id: marks
        property real glow: 0
        function play() { locking.restart() }
        visible: glow > 0
        cuts: [0, Theme.hudCut, 0, 0]
        weight: 2
        color: Theme.tint(Theme.hudAccent, glow)
        transform: Scale { id: lockScale; origin.x: marks.width / 2; origin.y: marks.height / 2 }
        Settling { when: locking.running }
        SequentialAnimation {
            id: locking
            PropertyAction { target: marks; property: "glow"; value: 1 }
            PropertyAction { target: lockScale; properties: "xScale,yScale"; value: 1.08 }
            NumberAnimation { target: lockScale; properties: "xScale,yScale"; to: 1; duration: Theme.lock * 2; easing: Theme.spring }
            PauseAnimation { duration: Theme.settle }
            NumberAnimation { target: marks; property: "glow"; to: 0; duration: Theme.rise; easing: Theme.easeOut }
        }
    }
    Loader {
        id: lock
        anchors.fill: parent
        active: false
        sourceComponent: CardLock { }
        onLoaded: (item as CardLock).play()
    }
    Loader {
        id: lockSpark
        active: false
        x: Theme.hudBracket; y: Theme.hudBracket
        sourceComponent: Spark { count: 28 }
        onLoaded: (item as Spark).burst()
    }
    Timer { id: sparked; interval: Theme.rise * 2; onTriggered: lockSpark.active = false }
}

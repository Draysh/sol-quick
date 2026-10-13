import QtQuick

/*
    Something taking its place: rises a few pixels and fades in as it
    appears, in the world's beat (`Theme.beat`: its length and curve).
    `place` is its place in a list, so each comes a stagger after the one
    before (never more than 400 ms late). On a page that is turning it
    starts as the page lands, not under the turn. Give it a size; what is
    inside fills it. `again()` plays its arrival once more (the rail's rows
    drawing in under the opening), `finish()` puts it in place at once.

        Settle { place: 2; width: parent.width; height: row.implicitHeight; Row { id: row … } }
        Settle { place: index; pop: true; width: 160; height: 240; Poster { … } }   // a tile
*/
Item {
    id: root

    /** Its place in a list of things arriving together. */
    property int place: 0
    /** Extra delay before it starts, in ms. */
    property int wait: 0
    /** Over the rise instead of the settle: for a body or a big figure. */
    property bool slow: false
    /** Set to false to show it at once (e.g. past the first two dozen rows). */
    property bool animated: true
    /** Pops into place: grows from a little smaller and rises a little past its place and back (the spring), for a tile in a grid. */
    property bool pop: false
    /** Held down (a row under a press): it gives a few pixels to the side, and springs back. */
    property bool pushed: false

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    // Out of sight until it arrives, which is when it is on screen.
    opacity: animated ? 0 : 1
    readonly property real fromY: root.slow ? 10 : root.pop ? 14 : 6
    transform: [
        Translate { id: shift; y: root.animated && !Theme.calm ? root.fromY : 0 },
        Scale { id: grow; origin.x: root.width / 2; origin.y: root.height / 2; xScale: root.animated && root.pop && !Theme.calm ? 0.9 : 1; yScale: xScale },
        Translate {
            x: root.pushed && !Theme.calm ? 4 : 0
            Behavior on x { NumberAnimation { duration: root.pushed ? Theme.snap : Theme.settle; easing: root.pushed ? Theme.easeOut : Theme.spring } }
        }
    ]
    /** Arrived late (scrolled to): it comes at once, no stagger. */
    property bool late: false
    property var forget: null
    // Started once the page has had its say, so a page turning has told when it lands (not when it was
    // dropped meanwhile, by a Loader that changed its mind).
    Component.onCompleted: if (animated) forget = Theme.whenSeen(root, waited => { late = waited; Qt.callLater(() => { if (root && typeof root.start === "function") root.start() }) })
    Component.onDestruction: if (forget) forget()
    /** How long until it starts: its stagger, and while its page turns, until the page lands. */
    property real pause: 0
    function start() {
        if (!root) return
        const page = Theme.screenOf(root)
        const lands = page && page.landsAt ? Math.max(0, page.landsAt - Date.now()) : 0
        pause = root.late ? 0 : root.wait + Theme.delay(root.place) + lands
        arrive.restart()
    }
    /** Plays its arrival again, from out of sight, after `wait` and its stagger (nothing with less motion). */
    function again() {
        if (!animated || Theme.calm) return
        arrive.stop()
        opacity = 0
        shift.y = fromY
        grow.xScale = pop ? 0.9 : 1
        late = false
        start()
    }
    /** In its place at once. */
    function finish() { if (arrive.running) arrive.complete() }

    Settling { when: arrive.running }
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.pause }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.slow ? Theme.rise : Theme.beat.arrive; easing: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: root.slow ? Theme.rise : Theme.beat.arrive; easing: root.pop ? Theme.spring : Theme.beat.curve }
            NumberAnimation { target: grow; property: "xScale"; to: 1; duration: Math.max(Theme.beat.arrive, Theme.hit * 3); easing: Theme.spring }
        }
    }
}

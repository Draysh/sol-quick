import QtQuick

/*
    Something taking its place: rises a few pixels and fades in as it
    appears. `place` is its place in a list, so each comes a stagger after
    the one before (never more than 400 ms late). Give it a size; what is
    inside fills it.

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
    transform: [
        Translate { id: shift; y: root.animated && !Theme.calm ? (root.slow ? 10 : root.pop ? 14 : 6) : 0 },
        Scale { id: grow; origin.x: root.width / 2; origin.y: root.height / 2; xScale: root.animated && root.pop && !Theme.calm ? 0.9 : 1; yScale: xScale },
        Translate {
            x: root.pushed && !Theme.calm ? 4 : 0
            Behavior on x { NumberAnimation { duration: root.pushed ? Theme.snap : Theme.settle; easing: root.pushed ? Theme.easeOut : Theme.spring } }
        }
    ]
    /** Arrived late (scrolled to): it comes at once, no stagger. */
    property bool late: false
    property var forget: null
    Component.onCompleted: if (animated) forget = Theme.whenSeen(root, waited => { late = waited; arrive.start() })
    Component.onDestruction: if (forget) forget()

    Settling { when: arrive.running }
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.late ? 0 : root.wait + Theme.delay(root.place) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.slow ? Theme.rise : Theme.settle; easing: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: root.slow ? Theme.rise : Theme.settle; easing: root.pop ? Theme.spring : Theme.easeOut }
            NumberAnimation { target: grow; property: "xScale"; to: 1; duration: Theme.settle; easing: Theme.spring }
        }
    }
}

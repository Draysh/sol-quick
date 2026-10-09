import QtQuick

/*
    Something taking its place: rises a few pixels and fades in as it
    appears. `index` is its place in a list, so each comes a stagger after
    the one before (never more than 400 ms late). Give it a size; what is
    inside fills it.

        Settle { place: 2; width: parent.width; height: row.implicitHeight; Row { id: row … } }
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

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    // Out of sight until it arrives, which is when it is on screen.
    opacity: animated ? 0 : 1
    transform: Translate { id: shift; y: root.animated ? (root.slow ? 10 : 6) : 0 }
    /** Arrived late (scrolled to): it comes at once, no stagger. */
    property bool late: false
    property var forget: null
    Component.onCompleted: if (animated) forget = Theme.whenSeen(root, waited => { late = waited; arrive.start() })
    Component.onDestruction: if (forget) forget()

    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.late ? 0 : root.wait + Theme.delay(root.place) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.slow ? Theme.rise : Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: root.slow ? Theme.rise : Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }
}

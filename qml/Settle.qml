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

    transform: Translate { id: shift; y: 0 }
    opacity: 1

    /** The Flickable this scrolls in, if any. */
    function flickOf() { for (let it = parent; it; it = it.parent) if (it.hasOwnProperty("contentY") && it.hasOwnProperty("contentHeight") && it.hasOwnProperty("contentItem")) return it; return null }
    function inView(f) { if (f.height <= 0) return true; const y = mapToItem(f.contentItem, 0, 0).y; return y < f.contentY + f.height + 40 }
    /** Starts `arrival` now if on screen, else when scrolled to. */
    property var waitingOn: null
    property var waitingCheck: null
    function whenSeen(arrival) {
        const f = flickOf()
        if (!f || inView(f)) { arrival(); return }
        const check = () => { if (inView(f)) { unwait(); arrival() } }
        waitingOn = f; waitingCheck = check
        f.contentYChanged.connect(check)
    }
    function unwait() { if (waitingOn && waitingCheck) { waitingOn.contentYChanged.disconnect(waitingCheck) } waitingOn = null; waitingCheck = null }
    // Gone before it was seen: the Flickable must forget it.
    Component.onDestruction: unwait()

    Component.onCompleted: if (animated) { const f = flickOf(); if (!f || inView(f)) arrive.start(); else { opacity = 0; shift.y = slow ? 10 : 6; whenSeen(() => arrive.start()) } }

    SequentialAnimation {
        id: arrive
        PropertyAction { target: root; property: "opacity"; value: 0 }
        PropertyAction { target: shift; property: "y"; value: root.slow ? 10 : 6 }
        PauseAnimation { duration: root.wait + Theme.delay(root.place) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.slow ? Theme.rise : Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: root.slow ? Theme.rise : Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }
}

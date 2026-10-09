import QtQuick

/*
    A page in the pane. Its `header` (a PageHead) stays put; everything else
    scrolls, padded by the pane's margin. A Sheet as the header is pinned
    instead: the page scrolls under it and it shrinks to a bar. The Shell
    keeps a Screen alive while the history leads to it, so going back
    lands where you left off.

        Screen {
            title: "Settings"
            header: PageHead { title: "Settings" }
            Grid { Card { … } Card { … } }
        }
*/
Item {
    id: screen

    /** The page's name, for the way back to it. */
    property string title: ""
    /** What it was opened with (`Shell.go(path, params)`). */
    property var params: ({})
    /** The Shell it lives in; set by the Shell. */
    property var shell: null
    /** The way back, when this page was opened from another: `{ label, go }`. */
    property var back: null
    /** The picture a page shares with the one that opened it (a poster, a cover): the Shell flies it here. */
    property Item hero: null
    /** Words from the sidebar's field, for a page that filters itself in place; "" when it doesn't. */
    property string filter: ""
    /** Whether this page filters in place (it reads `filter`). */
    property bool filters: false
    /** The Sheet pinned over the page, shrinking as it scrolls, if there is one. */
    property Item pinned: null

    /** A Sheet given as the header pins itself over the page: the page scrolls under it, and it shrinks to a bar. */
    function pin(item) {
        pinned = item
        // The page starts under it, a gap below its line.
        screen.topPad = Qt.binding(() => item.fullHeight + Theme.s4)
        item.collapse = Qt.binding(() => Math.max(0, Math.min(1, flick.contentY / Math.max(1, item.fullHeight - item.compact))))
    }
    /** Pad the sides by the pane's margin; off for a page that starts with a Sheet. */
    property bool padded: true
    /** Space above the content (and, on a page with no header, room for the way back floating over it). */
    property real topPad: (padded ? Theme.s4 : 0) + (floatingBack.visible ? floatingBack.height + Theme.s3 : 0)
    property alias header: headSlot.data
    default property alias content: column.data
    property alias contentY: flick.contentY
    property alias flickable: flick
    /** Something pinned along the bottom of this page (rarely). */
    property alias footer: footSlot.data
    readonly property real margin: Theme.margin(width)
    /** Settles the page in again, as when it first opened; `in` slides from the right, `back` from the left.
        The Shell calls it each time the page shows, so a page must not declare a `reveal` of its own. */
    function reveal(dir) { flick.reveal(dir); revealHead(dir) }
    /** The header's words settle in with the page, when it can (a PageHead). */
    function revealHead(dir) { for (const h of headSlot.children) if (typeof h.reveal === "function") h.reveal(dir) }
    /** Scrolls the page by `dy` pixels (the keys' arrows and pages), eased like a wheel notch. */
    function scrollBy(dy) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, (glide.running ? glide.to : flick.contentY) + dy))
        bounce.stop()
        glide.stop(); glide.from = flick.contentY; glide.to = to
        glide.duration = Theme.fade
        glide.start()
    }
    /** How far a page key scrolls: the visible height, less a line to keep your place. */
    readonly property real pageStep: Math.max(48, flick.height - (pinned ? pinned.compact : 0) - 48)
    /** Where `item` will rest in `into`'s coordinates, once the page's arrival is over (the hero lands there). */
    function restingPoint(item, into) {
        const p = item.mapToItem(flick, 0, 0)
        return screen.mapToItem(into, flick.x + p.x, flick.y + p.y)
    }

    Item {
        id: headSlot
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: childrenRect.height
        z: 10
        onChildrenChanged: { for (const h of children) { h.width = Qt.binding(() => headSlot.width); if (h.hasOwnProperty("screen")) h.screen = screen; if (h.hasOwnProperty("collapse") && h.hasOwnProperty("fullHeight")) screen.pin(h) } }
    }

    // The way back floats over the corner when no PageHead shows it.
    Back {
        id: floatingBack
        visible: !!screen.back && headSlot.children.length === 0
        label: screen.back ? screen.back.label : ""
        floating: true
        x: Theme.s3; y: Theme.s3
        z: 20
        onGo: screen.back.go()
    }

    Flickable {
        id: flick
        anchors.left: parent.left; anchors.right: parent.right
        // Under a pinned Sheet the page starts at the top and scrolls beneath it.
        anchors.top: screen.pinned ? parent.top : headSlot.bottom
        anchors.bottom: footSlot.top
        contentWidth: width
        contentHeight: column.y + column.implicitHeight + Theme.s6
        // Real inertia: a drag past the end gives and springs back; a flick runs out on its own curve.
        boundsBehavior: Flickable.DragAndOvershootBounds
        rebound: Transition { SpringAnimation { properties: "x,y"; spring: 3; damping: 0.32; mass: 0.9 } }
        flickDeceleration: 2200
        maximumFlickVelocity: 6000
        clip: true

        // A wheel notch scrolls a measured step, eased, so it reads as motion, not a jump.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 96
                const max = Math.max(0, flick.contentHeight - flick.height)
                const want = (glide.running ? glide.to : flick.contentY) - step
                const to = Math.max(0, Math.min(max, want))
                // At the end already: the page gives a little and comes back, so the end is felt.
                if ((want < 0 && flick.contentY <= 0) || (want > max && flick.contentY >= max)) {
                    if (!bounce.running) { bounceTo.to = want < 0 ? -24 : max + 24; bounce.restart() }
                    event.accepted = true
                    return
                }
                bounce.stop()
                glide.stop(); glide.from = flick.contentY; glide.to = to
                glide.duration = event.pixelDelta.y !== 0 ? 80 : 260
                glide.start()
                event.accepted = true
            }
        }
        NumberAnimation { id: glide; target: flick; property: "contentY"; easing.type: Easing.OutCubic }
        SequentialAnimation { id: bounce; NumberAnimation { id: bounceTo; target: flick; property: "contentY"; duration: 90; easing.type: Easing.OutCubic } ScriptAction { script: flick.returnToBounds() } }

        Column {
            id: column
            x: screen.padded ? screen.margin : 0
            y: screen.topPad
            width: flick.width - (screen.padded ? screen.margin * 2 : 0)
            spacing: Theme.s4
        }

        // The screen settles into the pane as it opens, and again when the Shell comes back to it.
        opacity: 0
        transform: Translate { id: shift; y: 6; x: 0 }
        Component.onCompleted: { arrive.start(); screen.revealHead("up") }
        function reveal(dir) {
            arrive.stop(); flick.opacity = 0
            shift.y = dir === "in" || dir === "back" ? 0 : 6
            shift.x = dir === "in" ? 28 : dir === "back" ? -16 : 0
            arrive.start()
        }
        ParallelAnimation {
            id: arrive
            NumberAnimation { target: flick; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "x"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }

    // A thin scrollbar, only while the pane moves.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 2
        // Its track starts under a pinned Sheet, not behind it.
        readonly property real trackTop: screen.pinned ? screen.pinned.height : flick.y
        readonly property real track: flick.y + flick.height - trackTop
        y: trackTop + (track - height) * (flick.contentHeight > flick.height ? Math.max(0, Math.min(1, flick.contentY / (flick.contentHeight - flick.height))) : 0)
        width: 3
        height: Math.max(24, track * Math.min(1, flick.height / Math.max(1, flick.contentHeight)))
        radius: 1.5
        color: Theme.tint(Theme.ink, 0.18)
        visible: flick.contentHeight > flick.height
        opacity: flick.moving || glide.running || hover.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        HoverHandler { id: hover }
    }

    Item {
        id: footSlot
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: childrenRect.height
    }
}

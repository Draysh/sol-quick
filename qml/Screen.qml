import QtQuick

/*
    A page in the pane. Its `header` (a PageHead) stays put; everything else
    scrolls, padded by the pane's margin. A Sheet as the header is pinned
    instead: the page scrolls under it and it shrinks to a bar (so is a
    PageHead with a `feature`, which folds away under its band). A page
    opened from another without a header of its own gets the kit's
    PageHead with its title and the way back. The Shell keeps a Screen
    alive while the history leads to it, so going back lands where you
    left off.

    The content starts at the pane's left margin, as a first page's Sheet
    does, and is never wider than `maxWidth` (about 1400 px): a wider pane
    leaves the rest on the right to the still. The page's `side` column (a
    cover, art, a navigator) stands just right of the content, or above it
    when the pane is too narrow for both. A page with little on it says `sparse`: on a
    wide pane its title is set large over the still and its content stands
    under it (beside it, when the title is written down), one group low on
    the left, so the still's figure keeps the rest of the pane.

        Screen {
            title: "Settings"
            header: PageHead { title: "Settings" }
            Grid { Card { … } Card { … } }
        }
        Screen { title: "Album"; header: PageHead { title: album.name }; side: [Picture { … }]; TrackList { … } }
        Screen { title: "Dictionary"; sparse: true; header: PageHead { title: "Dictionary"; jp: "辞書" }; Field { … } }
*/
Item {
    id: screen

    /** The page's name, for the way back to it. */
    /** The world the page belongs to: set by the Shell (a moon's pages carry the moon's id); "" is the app's own. */
    property string world: ""
    property string title: ""
    /** On a page opened from another with no head of its own, the kit's PageHead sets the title in the title face, large (`PageHead.named`): a detail page's name. */
    property bool named: false
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
    /** This page's own actions, `{ label, hint, keys, icon, run }`, in the palette (Ctrl+K) after the window's, and on the `?` sheet: "Rate 8", "Bury this card". */
    property var actions: []
    /** Key art for the whole window behind this page (a file or web address), in place of the world's still. */
    property string ground: ""
    /**
        What the world's navigator says on this page, in its own voice:
        short and warm, about 60 characters at most, never the page's
        title or its empty state again. "" keeps it quiet.
    */
    property string say: ""
    /** The same in Japanese, said first: "続き、見よっか。" */
    property string sayJp: ""
    /** The line of the empty state on show beside its own portrait (Empty sets it): the sidebar's navigator keeps quiet meanwhile. */
    property string emptySay: ""
    /** The Sheet pinned over the page, shrinking as it scrolls, if there is one. */
    property Item pinned: null

    /** A Sheet given as the header (or a PageHead with a feature) pins itself over the page: the page scrolls under it, and it shrinks to a bar. */
    function pin(item) {
        if (pinned === item) return
        pinned = item
        // The page starts under it, a gap below its line; beside it (a Sheet's `aside`), at the top.
        screen.topPad = Qt.binding(() => item.beside ? Theme.s4 : item.fullHeight + Theme.s4)
        item.collapse = Qt.binding(() => item.beside ? 0 : Math.max(0, Math.min(1, flick.contentY / Math.max(1, item.fullHeight - item.compact))))
    }
    /** The Sheet standing beside the page rather than over it (its `aside`, in a window under 1300 px), or null. */
    readonly property Item besideHead: pinned && pinned.beside ? pinned : null
    /** Where a first page's own column starts across the pane (it isn't `padded`): the margin, or past a Sheet beside it. */
    readonly property real startX: besideHead ? besideHead.besideWidth + Theme.s3 : margin
    /** How wide that column is, from `startX` to the margin, never wider than `maxWidth`. */
    readonly property real startWidth: Math.max(0, Math.min(maxWidth, width - startX - margin))
    /** Pad the sides by the pane's margin; off for a page that starts with a Sheet. */
    property bool padded: true
    /** Space above the content (and, on a page with no header, room for the way back floating over it). */
    property real topPad: padded ? Theme.s4 : 0
    /** The widest the content goes; a wider pane leaves the rest to the still (after `side`, when there is one). */
    property real maxWidth: 1400
    /** A column beside the content on a wide pane (above it on a narrow one): a cover, art, a navigator. */
    property alias side: sideSlot.data
    /** On a pane too narrow for the side column beside the content, it goes above it; false leaves it out there (a page that keeps the same things in its column then). */
    property bool sideAbove: true
    /** A page with little on it: on a wide pane, its title large over the still and its content in a column under it, low on the left. */
    property bool sparse: false
    /** The room inside the pane's margins. */
    readonly property real room: Math.max(0, width - margin * 2)
    readonly property bool hasSide: sideSlot.children.length > 0 && (sideAbove || room >= 1040)
    /** The side column beside the content (else above it). */
    readonly property bool sideBeside: hasSide && room >= 1040
    readonly property real sideWidth: !hasSide ? 0 : sideBeside ? Math.round(Math.max(300, Math.min(440, room - maxWidth - sideGap, room * 0.3))) : room
    /** The gutter between the content and the side column: a Grid's own, so a page's gutters are all one. */
    readonly property real sideGap: Theme.s4
    /** Composed to the still: only on a pane wide enough to leave the still its figure. */
    readonly property bool composed: sparse && padded && room >= 960
    /** Where the content starts across the pane, and how wide it is (a PageHead lines its words up with it). */
    readonly property real contentWidth: !padded ? width
        : composed ? Math.min(560, Math.round(room * 0.46), width - margin - groupX - (bigTitle.down ? bigTitle.downWidth + Theme.s5 : 0))
        : sideBeside ? Math.min(maxWidth, room - sideWidth - sideGap)
        : Math.min(maxWidth, room)
    readonly property real contentX: !padded ? 0
        : composed ? groupX + (bigTitle.down ? bigTitle.downWidth + Theme.s5 : 0)
        : margin
    /** Where a composed page's group (its big title and its column) starts: clear of the navigator where its frame breaks the sidebar's edge into the pane. */
    readonly property real groupX: Math.max(margin, shell && shell.navigatorReach > 0 ? shell.navigatorReach + Theme.s6 : 0)
    property alias header: headSlot.data
    default property alias content: column.data
    property alias contentY: flick.contentY
    property alias flickable: flick
    /** Something pinned along the bottom of this page (rarely). */
    property alias footer: footSlot.data
    readonly property real margin: Theme.margin(width)
    /** Settles the page in again, as when it first opened; `in` slides from the right, `back` from the left,
        `up` (a section) in place, each after its turn's hold; `open` lands at once (the opening's last beat),
        `tab` only fades. The Shell calls it each time the page shows, so a page must not declare a `reveal` of its own. */
    function reveal(dir) {
        landsAt = Date.now() + landWait(dir)
        flick.reveal(dir)
        revealHead(dir)
        // Its band stays out of sight until the turn has covered the page before it.
        headIn.stop()
        headCover.duration = landWait(dir) > 0 ? Theme.turnCover : 0
        headIn.start()
    }
    SequentialAnimation {
        id: headIn
        PropertyAction { targets: [headSlot, autoHead]; property: "opacity"; value: 0 }
        PauseAnimation { id: headCover; duration: 0 }
        PropertyAction { targets: [headSlot, autoHead]; property: "opacity"; value: 1 }
    }
    /** The header's words settle in with the page, when it can (a PageHead, a Sheet). */
    function revealHead(dir) { for (const h of headSlot.children) if (typeof h.reveal === "function") h.reveal(dir) }
    /** How long a page arriving `dir` waits under its turn before it lands: until the turn's hold is over. */
    function landWait(dir) { return (dir === "in" || dir === "up" || dir === "back") && !Theme.calm ? Theme.turnReveal : 0 }
    /** When the page lands (`Date.now()` time): its cards and tiles start arriving then, not under the turn. */
    property double landsAt: 0
    /** Scrolls the page by `dy` pixels (the keys' arrows and pages), eased like a wheel notch. */
    function scrollBy(dy) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, (glide.running ? glide.to : flick.contentY) + dy))
        bounce.stop()
        glide.stop(); glide.from = flick.contentY; glide.to = to
        glide.duration = Theme.fade
        glide.start()
    }
    /** How far one notch of a mouse wheel scrolls: a step that grows with the pane, so a tall window isn't slow. */
    readonly property real notch: Math.max(110, Math.min(180, flick.height / 7))
    /**
        Scrolls the page for a wheel event, also one handed on by something
        inside it that only scrolls sideways (a Strip): a mouse wheel's notch
        by `notch`, eased; a touchpad by its own pixels (see `Theme.wheel`).
    */
    function wheel(event) {
        const w = Theme.wheel(event, notch)
        const step = w.y
        if (step === 0) return
        const max = Math.max(0, flick.contentHeight - flick.height)
        const want = (glide.running ? glide.to : flick.contentY) - step
        const to = Math.max(0, Math.min(max, want))
        // At the end already: the page gives a little and comes back, so the end is felt.
        if ((want < 0 && flick.contentY <= 0) || (want > max && flick.contentY >= max)) {
            if (!bounce.running) { bounceTo.to = want < 0 ? -24 : max + 24; bounce.restart() }
            return
        }
        bounce.stop()
        glide.stop(); glide.from = flick.contentY; glide.to = to
        glide.duration = w.notched ? Theme.notchGlide : Theme.touchGlide
        glide.start()
    }
    /** How far a page key scrolls: the visible height, less a line to keep your place. */
    readonly property real pageStep: Math.max(48, flick.height - (pinned && !besideHead ? pinned.compact : 0) - 48)
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
        onChildrenChanged: { for (const h of children) { h.width = Qt.binding(() => headSlot.width); if (h.hasOwnProperty("screen")) h.screen = screen; if (h.hasOwnProperty("collapse") && h.hasOwnProperty("fullHeight") && h.pins !== false) screen.pin(h) } }
    }

    // A page opened from another with no head of its own: the kit's, with its title and the way back.
    Loader {
        id: autoHead
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        z: 10
        active: !!screen.back && headSlot.children.length === 0
        // (Its own `screen` would hide the page's id inside it: both are set from here.)
        sourceComponent: PageHead { }
        onLoaded: { const h = item as PageHead; if (!h) return; h.screen = screen; h.title = Qt.binding(() => screen.title); h.named = Qt.binding(() => screen.named) }
    }

    Flickable {
        id: flick
        anchors.left: parent.left; anchors.right: parent.right
        // Under a pinned Sheet the page starts at the top and scrolls beneath it.
        anchors.top: screen.pinned ? parent.top : autoHead.item ? autoHead.bottom : headSlot.bottom
        anchors.bottom: footSlot.top
        contentWidth: width
        contentHeight: Math.max(column.y + column.implicitHeight, screen.sideBeside ? sideSlot.y + sideSlot.height : 0) + Theme.s6
        // Real inertia: a drag past the end gives and springs back; a flick runs out on its own curve.
        boundsBehavior: Flickable.DragAndOvershootBounds
        rebound: Transition { NumberAnimation { properties: "x,y"; duration: Theme.settle; easing: Theme.spring } }
        flickDeceleration: 2200
        maximumFlickVelocity: 6000
        clip: true

        // A wheel notch scrolls a measured step, eased, so it reads as motion, not a jump.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => { screen.wheel(event); event.accepted = true }
        }
        NumberAnimation { id: glide; target: flick; property: "contentY"; easing: Theme.easeOut }
        SequentialAnimation { id: bounce; NumberAnimation { id: bounceTo; target: flick; property: "contentY"; duration: Theme.touchGlide; easing: Theme.easeOut } ScriptAction { script: flick.returnToBounds() } }

        // The side column: beside the content on a wide pane, above it on a narrow one.
        Item {
            id: sideSlot
            visible: screen.hasSide
            x: screen.sideBeside ? screen.contentX + screen.contentWidth + screen.sideGap : screen.margin
            y: screen.topPad
            width: screen.sideWidth
            height: childrenRect.height
            onChildrenChanged: { for (const c of children) c.width = Qt.binding(() => sideSlot.width) }
        }
        // A page with little on it, on a wide pane: its title large over the still, its content
        // under it (or beside it, written down), one group low on the left that scrolls together.
        Column {
            id: bigTitle
            readonly property var head: headSlot.children.length ? headSlot.children[0] : null
            visible: screen.composed
            x: screen.groupX
            // Over the column; written down, beside it, their feet on one line.
            y: down ? column.y + column.implicitHeight - height : column.y - height - Theme.s4
            width: down ? downWidth : screen.contentWidth
            spacing: Theme.s2
            // Written down with the flavour's `tategaki` (Mercury's), as a hanging scroll.
            readonly property bool down: !!Theme.hud.tategaki
            readonly property real downSize: 96
            /** How wide the title is written down: one character, or its English line when that is wider. */
            readonly property real downWidth: Math.max(downSize, english.visible ? english.implicitWidth : 0)
            readonly property string jp: head && head.jpTitle ? head.jpTitle : ""
            ChromaText {
                width: parent.width
                text: bigTitle.down ? bigTitle.jp.split("").map(c => ({ "、": "︑", "。": "︒", "ー": "︱" })[c] || c).join("\n") : bigTitle.jp
                visible: text !== ""
                elide: bigTitle.down ? Text.ElideNone : Text.ElideRight
                // Written down, each character a square and a little: the face's own line is far taller.
                lineHeightMode: bigTitle.down ? Text.FixedHeight : Text.ProportionalHeight
                lineHeight: bigTitle.down ? Math.round(font.pixelSize * 1.06) : 1
                horizontalAlignment: bigTitle.down ? Text.AlignHCenter : Text.AlignLeft
                font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle
                font.pixelSize: bigTitle.down ? bigTitle.downSize : Theme.textHero
                fontSizeMode: bigTitle.down ? Text.FixedSize : Text.HorizontalFit; minimumPixelSize: 40
                color: Theme.artBright
                style: Text.Raised; styleColor: Theme.tint(Theme.hud.dim || Theme.hud.ground, 0.6)
            }
            Text {
                id: english
                width: parent.width
                text: bigTitle.head && bigTitle.head.title ? bigTitle.head.title : screen.title
                horizontalAlignment: bigTitle.down ? Text.AlignHCenter : Text.AlignLeft
                font.family: Theme.fontDisplay; font.pixelSize: Theme.textM; font.weight: Font.Bold
                font.letterSpacing: Theme.track(Theme.trackHud, Theme.textM); font.capitalization: Font.AllUppercase
                color: Theme.hudAccent
                visible: Theme.capsFor(text)
            }
        }
        Column {
            id: column
            x: screen.contentX
            // Composed to the still, a short column sits low under its big title (beside it, written
            // down); a long one starts under the title and scrolls with it.
            y: screen.composed ? Math.max(screen.topPad + (bigTitle.down ? Math.max(0, bigTitle.height - implicitHeight) : bigTitle.height + Theme.s4), flick.height - implicitHeight - Theme.s6)
                : screen.topPad + (screen.hasSide && !screen.sideBeside ? sideSlot.height + Theme.s4 : 0)
            width: screen.contentWidth
            spacing: Theme.s4
        }

        // The screen settles into the pane as it opens, and again when the Shell comes back to it.
        opacity: 0
        transform: Translate { id: shift; y: Theme.calm ? 0 : 6; x: 0 }
        Component.onCompleted: { arrive.start(); screen.revealHead("open") }
        // Under the Shell's PageTurn, in the world's beat: hidden while the turn covers the pane,
        // then a hard reveal (a `hit` to show) and a landing over what is left of the turn:
        // Neptune's slides in from the way it turns, Terra's comes up into the light with a soft
        // bounce, Saturn's cuts in nearly still, Mercury's shows through without moving. With less
        // motion, or as a tab, a fade only.
        /** Arriving as a tab does: a plain fade, in place. */
        property bool plain: false
        property real wait: 0
        function reveal(dir) {
            arrive.stop(); flick.opacity = 0
            plain = dir === "tab"
            wait = screen.landWait(dir)
            const still = Theme.calm || plain
            const way = dir === "back" ? -1 : 1
            shift.y = still ? 0 : Theme.beat.rise
            shift.x = still || dir === "up" ? 0 : Theme.beat.slide * 2 * way
            arrive.start()
        }
        SequentialAnimation {
            id: arrive
            PauseAnimation { duration: flick.wait }
            ParallelAnimation {
                NumberAnimation { target: flick; property: "opacity"; to: 1; duration: flick.plain || Theme.calm ? Theme.fade : Theme.hit; easing: Theme.easeOut }
                NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.land; easing: Theme.beat.curve }
                NumberAnimation { target: shift; property: "x"; to: 0; duration: Theme.land; easing: Theme.easeOut }
            }
        }
    }

    Settling { when: arrive.running }

    // A thin scrollbar, only while the pane moves.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 2
        // Its track starts under a pinned Sheet, not behind it.
        readonly property real trackTop: screen.pinned && !screen.besideHead ? screen.pinned.height : flick.y
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

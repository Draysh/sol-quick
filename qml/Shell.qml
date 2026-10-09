pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import QtQuick.Effects
// By name: Qt has a `Screen` of its own, which a plain `Screen` finds first.
import Sol.Design as Design

/*
    The frame around every screen: a sidebar on the left (the world, its
    sections, its doors, its status at the bottom) and a pane on the right
    where the pages live. Ctrl + 1…9 jumps to a section, `/` goes to the
    sidebar's field (it filters the page, or searches the app), `?` shows
    the keys; Alt+← / → and the mouse's own buttons go back and forth.
    Going back lands where you left off: each section keeps one page alive
    with its scroll, and a page opened from another lives while the
    history still leads to it.

    The world's light marks the current section and glides to the next one
    when it changes; each screen settles into the pane as it opens.

        Shell {
            world: "terra"
            sections: [{ path: "/", label: "Today", hint: "What's on today" }, { path: "/settings", label: "Settings" }]
            pages: ({ "/": todayPage, "/settings": settingsPage })   // Components
            doors: [{ world: "sol", label: "Sol", open: () => Sol.openInSol() }]
            search: "/search"
            shortcuts: [{ keys: "Space", does: "Play or pause" }]
            status: LinkStatus { online: Sol.online; unsent: Sol.unsent }
        }
*/
Item {
    id: shell

    property string world: "terra"
    /** `{ path, label, hint, world?, badge? }`, in the order of the sidebar. */
    property var sections: []
    /** Path → Component. A path not in the sections is a page opened from another. */
    property var pages: ({})
    /** Doors to other apps, under the sections: `{ world, label, hint, open }`. */
    property var doors: []
    property string home: "/"
    /** Where `/` leads. */
    property string search: ""
    /** The app's own keys, for the sheet `?` opens. */
    property var shortcuts: []
    /** The bottom of the sidebar: LinkStatus. */
    property alias status: statusSlot.data
    /** A bar along the bottom of the pane, e.g. a player's transport. */
    property alias footer: footSlot.data
    /** The window's command palette (Ctrl+K), when it has one. */
    property var commandPalette: null
    /** Where the pages show, beside the sidebar (the window puts notices over it). */
    readonly property alias pageArea: pane
    /** The page on screen. */
    readonly property Item page: history.length ? history[here].item : null
    readonly property string path: history.length ? history[here].path : ""
    readonly property var w: Worlds.get(world)
    readonly property bool rail: width < 760

    // ---- History ---------------------------------------------------------------
    /** `{ path, params, item }`, oldest first; a section's entries share its one page. */
    property var history: []
    property int here: -1
    /** The most steps kept; older ones are forgotten (and their pages, if nothing else leads there). */
    readonly property int remembered: 30
    /** Section path → its page, made the first time it's opened. */
    property var sectionPages: ({})
    property bool keys: false

    // The accent: the world's own colour, or the one chosen for this device; the photo's colours to choose from.
    Settings { id: devicePrefs; category: "sol." + shell.world; property string accent: "" }
    function accent() { Theme.world = devicePrefs.accent !== "" ? devicePrefs.accent : w.color }
    Tone { source: shell.w.image; onPicksChanged: Theme.picks = picks }
    Component.onCompleted: { accent(); go(home) }
    onWorldChanged: accent()

    function isSection(path) { return sections.some(s => s.path === path) }

    /** On the rail, the sidebar's field is folded away until it is used. */
    property bool finding: false
    onRailChanged: finding = false
    /** The sidebar's field gets the keys (on the rail, it unfolds over the pane first). */
    function find() {
        finding = true
        Qt.callLater(() => { finder.input.forceActiveFocus(); finder.input.selectAll() })
    }

    /** Opens `path` with `params`, as a new step in the history. `hero` is
        `{ item, url }`: a picture that flies from `item` to the new page's `hero`. */
    function go(path, params, hero) {
        const component = pages[path]
        if (!component) { console.warn("Shell: no page at", path); return }
        params = params || {}
        if (path === shell.path && JSON.stringify(params) === JSON.stringify(history[here].params)) return
        const section = isSection(path) && Object.keys(params).length === 0
        let item = section ? sectionPages[path] : null
        if (!item) {
            item = component.createObject(paneSlot, { params: params, shell: shell, visible: false, width: Qt.binding(() => paneSlot.width), height: Qt.binding(() => paneSlot.height) })
            if (!item) { console.warn("Shell: page failed", path, component.errorString()); return }
            if (section) sectionPages[path] = item
        }
        // What is ahead of here is forgotten, as a browser does; past `remembered`, the oldest too.
        let kept = history.slice(0, here + 1).concat([{ path: path, params: params, item: item }])
        let dropped = history.slice(here + 1)
        if (kept.length > remembered) { dropped = dropped.concat(kept.slice(0, kept.length - remembered)); kept = kept.slice(kept.length - remembered) }
        history = kept
        release(dropped)
        show(history.length - 1, section ? "up" : "in")
        if (hero && hero.item && hero.url) fly(hero, item)
    }

    /** Destroys the pages of forgotten steps that nothing else leads to; a section's page stays. */
    function release(dropped) {
        for (const e of dropped) {
            if (Object.values(sectionPages).includes(e.item)) continue
            if (history.some(h => h.item === e.item)) continue
            e.item.destroy()
        }
    }

    // ---- The hero: one picture, shared between two pages ------------------
    function fly(hero, page) {
        const from = hero.item.mapToItem(shell, 0, 0)
        flight.stop(); land.stop()
        flyer.source = hero.url
        flyer.x = from.x; flyer.y = from.y; flyer.width = hero.item.width; flyer.height = hero.item.height
        flyer.opacity = 1; flyer.visible = true
        // The new page's hero has its place once the page is laid out (after
        // the next frame, when its Columns have placed it); where it rests,
        // not where the page's own arrival has it this moment.
        landing.page = page
        landing.restart()
        const win = shell.Window.window
        if (win) win.frameSwapped.connect(landing.measure)
    }
    Timer {
        id: landing
        // Without a frame (a hidden window), it measures anyway.
        interval: 50
        property Item page: null
        onTriggered: measure()
        function measure() {
            const win = shell.Window.window
            if (win) win.frameSwapped.disconnect(landing.measure)
            stop()
            const p = page
            page = null
            if (!p) return
            const screen = p as Design.Screen
            const target = screen ? screen.hero : null
            if (!target || !target.visible) { flyer.visible = false; return }
            const to = screen.restingPoint(target, shell)
            toX.to = to.x; toY.to = to.y; toW.to = target.width; toH.to = target.height
            flight.start()
        }
    }
    Image {
        id: flyer
        visible: false
        z: 40
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        layer.enabled: visible
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowOpacity: 0.6; shadowVerticalOffset: 10 }
    }
    SequentialAnimation {
        id: flight
        ParallelAnimation {
            NumberAnimation { id: toX; target: flyer; property: "x"; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { id: toY; target: flyer; property: "y"; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { id: toW; target: flyer; property: "width"; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { id: toH; target: flyer; property: "height"; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
        ScriptAction { script: land.start() }
    }
    SequentialAnimation { id: land; NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: Theme.fade } PropertyAction { target: flyer; property: "visible"; value: false } }

    function back() {
        if (here > 0) { show(here - 1, "out"); return true }
        // Opened first thing: up to its section, or home.
        if (!isSection(path)) { go(upPath()); return true }
        return false
    }

    function forward() {
        if (here < history.length - 1) show(here + 1, "in")
    }

    /** `dir`: `up` for a section (it settles), `in` for a page opened from another (it slides in from
        the right), `out` for going back (the page slides out to the right, the one under it comes back). */
    function show(i, dir) {
        // A leave still running (back and forth quickly) is finished first.
        if (leave.running) { leave.stop(); settleLeaving() }
        const was = here >= 0 ? history[here].item : null
        here = i
        const entry = history[i]
        const item = entry.item
        for (const e of history) if (e.item && e.item !== was && e.item !== item) e.item.visible = false
        item.visible = true
        item.x = 0
        item.opacity = 1
        item.back = backFor(entry)
        if (was && was !== item) {
            // The page that was here leaves under the one arriving; one coming back settles in again.
            leaving.target = was
            slideOut.target = was
            slideOut.to = dir === "out" ? 40 : 0
            slideOut.duration = dir === "out" ? Theme.settle : Theme.lock
            leaving.duration = dir === "out" ? Theme.settle : Theme.lock
            leave.restart()
            if (item.hasOwnProperty("reveal")) item.reveal(dir === "out" ? "back" : dir)
        }
        shell.forceActiveFocus()
        const screen = page as Design.Screen
        if (screen) finder.text = screen.filter
    }
    function settleLeaving() {
        const t = leaving.target as Item
        if (!t) return
        if (t !== shell.page) t.visible = false
        t.opacity = 1
        t.x = 0
    }
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { id: leaving; property: "opacity"; to: 0; duration: Theme.lock }
            NumberAnimation { id: slideOut; property: "x"; to: 0; duration: Theme.lock; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
        ScriptAction { script: shell.settleLeaving() }
    }

    readonly property int current: sections.findIndex(s => s.path === path)

    function upPath() {
        const s = sections.find(s => s.path === home) || sections[0]
        return s ? s.path : home
    }

    /** The way back from `entry`'s page: the step before it, or up to its section. A section has none. */
    function backFor(entry) {
        if (isSection(entry.path)) return null
        const at = history.indexOf(entry)
        if (at > 0) {
            const prev = history[at - 1]
            const section = sections.find(s => s.path === prev.path)
            return { label: section ? section.label : (prev.item.title || "Back"), go: () => shell.back() }
        }
        const up = sections.find(s => s.path === upPath())
        return { label: up ? up.label : "Home", go: () => shell.go(upPath()) }
    }

    // ---- Keys ---------------------------------------------------------------
    function typing() {
        const f = Window.activeFocusItem
        return !!f && (f.hasOwnProperty("cursorPosition") || f.hasOwnProperty("inputMethodComposing"))
    }

    Keys.onPressed: event => {
        if (event.modifiers === Qt.AltModifier && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            if (typing()) return
            if (event.key === Qt.Key_Right) forward(); else if (!back()) return
            event.accepted = true; return
        }
        if (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier) {
            if (typing()) return
            if (event.text === "?") { keys = !keys; event.accepted = true; return }
            if (event.text === "/" && !keys && finder.usable) { find(); event.accepted = true; return }
            if (event.text === "/" && search !== "" && !keys) { go(search); event.accepted = true; return }
            if (event.key === Qt.Key_Escape && keys) { keys = false; event.accepted = true; return }
            // The page scrolls from the keys too: arrows a line, Page Up / Down a page, Home and End.
            const screen = page as Design.Screen
            if (screen && !keys && event.modifiers === Qt.NoModifier) {
                const by = event.key === Qt.Key_Down ? 48 : event.key === Qt.Key_Up ? -48
                    : event.key === Qt.Key_PageDown ? screen.pageStep : event.key === Qt.Key_PageUp ? -screen.pageStep
                    : event.key === Qt.Key_End ? 1e9 : event.key === Qt.Key_Home ? -1e9 : 0
                if (by !== 0) { screen.scrollBy(by); event.accepted = true; return }
            }
        }
        if (event.modifiers === Qt.ControlModifier || event.modifiers === Qt.MetaModifier) {
            const n = event.key - Qt.Key_0
            if (n >= 1 && n <= 9 && sections[n - 1]) { go(sections[n - 1].path); event.accepted = true }
        }
    }
    focus: true

    // The mouse's own back and forward buttons, anywhere in the window.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        z: -1
        onClicked: event => { if (event.button === Qt.BackButton) shell.back(); else shell.forward() }
    }

    // ---- The frame ----------------------------------------------------------
    Rectangle { anchors.fill: parent; color: Theme.space }

    Item {
        id: side
        // Over the pane: the field floats out over it on the rail.
        z: 2
        width: shell.rail ? Theme.rail : Theme.sidebar
        height: parent.height
        Behavior on width { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        // The chrome sits a step deeper than the pane.
        Rectangle { anchors.fill: parent; color: Theme.deep }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

        // The brand: the world's disc, its name, and what the app is for.
        Item {
            id: brand
            x: shell.rail ? 0 : 20
            width: shell.rail ? parent.width : parent.width - 36
            height: Theme.navHeight
            y: Theme.s2
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: shell.rail ? parent.horizontalCenter : undefined
                spacing: 12
                Item {
                    width: 22; height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    scale: brandMouse.containsMouse ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                    Body { world: shell.world; disc: 22; animated: false }
                }
                Column {
                    visible: !shell.rail
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: shell.w.name
                        width: Math.min(implicitWidth, brand.width - 34)
                        elide: Text.ElideRight
                        font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textS
                        font.letterSpacing: Theme.track(0.28, Theme.textS); font.capitalization: Font.AllUppercase
                        color: Theme.textBright
                    }
                    Text {
                        visible: text !== ""
                        text: shell.w.role
                        width: Math.min(implicitWidth, brand.width - 34)
                        elide: Text.ElideRight
                        font.family: Theme.font; font.weight: Theme.weightValue; font.pixelSize: Theme.textXs
                        font.letterSpacing: Theme.track(0.04, Theme.textXs)
                        color: Theme.textWorld
                    }
                }
            }
            MouseArea { id: brandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.go(shell.home) }
            Hint { text: shell.w.tagline; when: brandMouse.containsMouse }
        }

        // The field: filters the page in place when it can, searches the app
        // otherwise; there only when it can do one or the other. On the rail it
        // waits behind a button and floats over the top of the pane while used.
        Item {
            id: findButton
            visible: shell.rail && finder.usable
            y: brand.y + brand.height
            width: parent.width
            height: Theme.control
            activeFocusOnTab: false
            Rectangle { anchors.centerIn: parent; width: Theme.control; height: Theme.control; radius: 6; color: findMouse.containsMouse || shell.finding ? Theme.surface : "transparent"; Behavior on color { ColorAnimation { duration: Theme.fade } } }
            Icon { anchors.centerIn: parent; name: "search"; size: 13; color: findMouse.containsMouse || shell.finding ? Theme.textBright : Theme.textQuiet }
            MouseArea { id: findMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.find() }
            Hint { text: (finder.filtering ? "Filter this page" : "Search") + " · /"; when: findMouse.containsMouse }
        }
        // Its ground while it floats over the pane.
        Rectangle {
            visible: shell.rail && finder.visible
            x: finder.x - Theme.s3; y: finder.y - Theme.s1
            width: finder.width + Theme.s3 * 2; height: finder.height + Theme.s1 * 2
            radius: 6
            color: Theme.deep
            border.width: 1; border.color: Theme.lineMid
        }
        Field {
            id: finder
            readonly property Design.Screen screen: shell.page as Design.Screen
            readonly property bool filtering: !!screen && screen.filters
            readonly property bool usable: filtering || shell.search !== ""
            visible: usable && (!shell.rail || shell.finding)
            x: shell.rail ? side.width + Theme.s4 : 20
            y: shell.rail ? Theme.s2 : brand.y + brand.height
            width: shell.rail ? Math.min(320, shell.width - side.width - Theme.s4 * 2) : parent.width - 36
            label: ""
            placeholder: filtering ? "Filter · /" : "Search · /"
            // Gone (a page that doesn't filter, a search sent), it filters nothing.
            onVisibleChanged: if (!visible) text = ""
            onTextChanged: if (screen) screen.filter = text
            onAccepted: { if (!filtering && shell.search !== "" && text.trim() !== "") { const q = text.trim(); text = ""; shell.finding = false; shell.go(shell.search, { query: q }) } }
            Keys.onEscapePressed: { text = ""; shell.finding = false; shell.forceActiveFocus() }
        }
        // Left empty on the rail, it folds away again.
        Connections { target: finder.input; function onActiveFocusChanged() { if (!finder.input.activeFocus && finder.text === "") shell.finding = false } }

        // The sections, with the world's light on the current one.
        Item {
            id: list
            x: shell.rail ? Theme.s1 : Theme.s2
            y: shell.rail ? (findButton.visible ? findButton.y + findButton.height + Theme.s2 : brand.y + brand.height + Theme.s2)
                : finder.visible ? finder.y + finder.height + Theme.s3 : brand.y + brand.height + Theme.s2
            width: parent.width - x * 2
            height: sectionColumn.implicitHeight

            Rectangle {
                id: light
                x: 0
                width: 2
                height: Theme.control - 18
                color: Theme.accent
                opacity: shell.current >= 0 ? 1 : 0
                y: (shell.current >= 0 ? shell.current : 0) * (Theme.control + 2) + 9
                property bool moved: false
                onYChanged: moved = true
                Behavior on y { enabled: light.moved; SpringAnimation { spring: 3.2; damping: 0.28; mass: 0.9 } }
                Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                RectangularShadow { anchors.fill: parent; blur: 8; spread: 0; color: Theme.accent; z: -1 }
            }

            Column {
                id: sectionColumn
                width: parent.width
                spacing: 2
                Repeater {
                    model: shell.sections
                    delegate: Settle {
                        id: row
                        required property var modelData
                        required property int index
                        place: index
                        width: sectionColumn.width
                        height: Theme.control
                        readonly property bool current: shell.path === row.modelData.path
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: row.current ? Theme.surfaceHover : rowMouse.containsMouse ? Theme.surface : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fade } }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: shell.rail ? parent.horizontalCenter : undefined
                            x: 12
                            spacing: 12
                            Item {
                                width: 10; height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                WorldGlyph { visible: !!row.modelData.world; world: row.modelData.world || "sol"; size: 10 }
                                Rectangle {
                                    visible: !row.modelData.world
                                    anchors.centerIn: parent
                                    width: 6; height: 6; radius: 3
                                    color: row.current ? Theme.textBright : "transparent"
                                    border.width: 1
                                    border.color: row.current || rowMouse.containsMouse ? Theme.textBright : Theme.lineStrong
                                    scale: rowMouse.containsMouse && !row.current ? 1.2 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                                    Behavior on color { ColorAnimation { duration: Theme.lock } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.lock } }
                                }
                            }
                            Text {
                                visible: !shell.rail
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                width: Math.min(implicitWidth, sectionColumn.width - 60 - (badge.visible ? 28 : 0))
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                                color: row.current || rowMouse.containsMouse ? Theme.textBright : Theme.textQuiet
                                transform: Translate { x: rowMouse.containsMouse ? 2 : 0; Behavior on x { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
                                Behavior on color { ColorAnimation { duration: Theme.fade } }
                            }
                        }
                        Rectangle {
                            id: badge
                            visible: !!row.modelData.badge
                            // At the row's end; on the rail, smaller, over the mark's shoulder.
                            x: shell.rail ? parent.width / 2 + 3 : parent.width - 12 - width
                            y: shell.rail ? 2 : (parent.height - height) / 2
                            width: Math.max(height, badgeText.implicitWidth + (shell.rail ? 6 : 10)); height: shell.rail ? 14 : 18; radius: height / 2
                            // The world's light, deepened by day, so the number reads on it in both.
                            color: Theme.textWorld
                            border.width: shell.rail ? 2 : 0; border.color: row.current ? Theme.surfaceHover : Theme.deep
                            Text { id: badgeText; anchors.centerIn: parent; text: row.modelData.badge || ""; font.family: Theme.font; font.pixelSize: shell.rail ? 9 : 10; font.weight: Theme.weightLabel; color: Theme.space }
                            onVisibleChanged: if (visible) pop.restart()
                            SequentialAnimation { id: pop; NumberAnimation { target: badge; property: "scale"; from: 0.6; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                        }
                        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.go(row.modelData.path) }
                        // On the rail only the mark shows: the hint names the section too.
                        Hint { text: [shell.rail ? row.modelData.label + (row.modelData.badge ? " (" + row.modelData.badge + ")" : "") : "", row.modelData.hint, row.index < 9 ? "Ctrl+" + (row.index + 1) : ""].filter(Boolean).join(" · "); when: rowMouse.containsMouse }
                    }
                }
            }
        }

        // Doors to other apps: after the sections, before the status.
        Column {
            id: doorColumn
            visible: shell.doors.length > 0
            x: list.x
            y: list.y + list.height + Theme.s3
            width: list.width
            spacing: 2
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            Item { width: 1; height: Theme.s2 - 2 }
            Repeater {
                model: shell.doors
                delegate: Settle {
                    id: door
                    required property var modelData
                    required property int index
                    place: shell.sections.length + door.index
                    width: doorColumn.width
                    // Another app: its name, and under it what it is for.
                    height: shell.rail || !door.modelData.role ? Theme.control : Theme.target
                    Rectangle { anchors.fill: parent; radius: 6; color: doorMouse.containsMouse ? Theme.surface : "transparent"; Behavior on color { ColorAnimation { duration: Theme.fade } } }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: shell.rail ? parent.horizontalCenter : undefined
                        x: 12; spacing: 12
                        WorldGlyph { world: door.modelData.world; size: 10; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            visible: !shell.rail
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: door.modelData.label
                                width: Math.min(implicitWidth, doorColumn.width - 34)
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                                color: doorMouse.containsMouse ? Theme.textBright : Theme.text
                                Behavior on color { ColorAnimation { duration: Theme.fade } }
                            }
                            Text {
                                visible: !!door.modelData.role
                                text: door.modelData.role || ""
                                width: Math.min(implicitWidth, doorColumn.width - 34)
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue
                                color: Theme.textQuiet
                            }
                        }
                    }
                    MouseArea { id: doorMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: door.modelData.open() }
                    Hint { text: [shell.rail ? door.modelData.label + (door.modelData.role ? " · " + door.modelData.role : "") : "", door.modelData.hint || ""].filter(Boolean).join(" · "); when: doorMouse.containsMouse }
                }
            }
        }

        // The bottom: where the app stands with Sol.
        Column {
            id: statusSlot
            // On the rail it stays, as dots (LinkStatus is compact there).
            x: shell.rail ? Theme.s2 : 20
            width: parent.width - (shell.rail ? Theme.s2 * 2 : 36)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.s3
            spacing: Theme.s2
            Rectangle { width: statusSlot.width; height: 1; color: Theme.line }
        }
    }

    // The pane: the pages, and a footer that is always there.
    Item {
        id: pane
        x: side.width
        width: parent.width - side.width
        height: parent.height
        clip: true

        Item {
            id: paneSlot
            width: parent.width
            height: parent.height - footSlot.height
        }
        // Behind the footer, outside it, so the footer's height follows what is in it.
        Rectangle { anchors.fill: footSlot; color: Theme.deep }
        Item {
            id: footSlot
            anchors.bottom: parent.bottom
            width: parent.width
            height: childrenRect.height
        }
    }

    Loader {
        anchors.fill: parent
        z: 3
        active: shell.keys
        sourceComponent: Shortcuts { shortcuts: shell.shortcuts; finderShown: finder.usable; search: shell.search !== ""; sections: shell.sections.length; onClosed: shell.keys = false }
    }

    Grain { }
}

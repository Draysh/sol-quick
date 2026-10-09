import QtQuick
import QtCore
import QtQuick.Effects

/*
    The frame around every screen: a sidebar on the left (the world, its
    sections, its doors, its status at the bottom) and a pane on the right
    where the pages live. Ctrl + 1…9 jumps to a section, `/` opens the
    app's search, `?` a sheet of the keys; Alt+← / → and the mouse's own
    buttons go back and forth, and going back lands where you left off:
    every page in the history stays alive with its scroll.

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
    /** The page on screen. */
    readonly property Item page: history.length ? history[here].item : null
    readonly property string path: history.length ? history[here].path : ""
    readonly property var w: Worlds.get(world)
    readonly property bool rail: width < 760

    // ---- History: every page stays, with its scroll ----------------------
    property var history: []
    property int here: -1
    property bool keys: false

    // The accent: the world's own colour, or the one chosen for this device; the photo's colours to choose from.
    Settings { id: devicePrefs; category: "sol." + shell.world; property string accent: "" }
    function accent() { Theme.world = devicePrefs.accent !== "" ? devicePrefs.accent : w.color }
    Tone { source: shell.w.image; onPicksChanged: Theme.picks = picks }
    Component.onCompleted: { accent(); go(home) }
    onWorldChanged: accent()

    /** The window's command palette, when it has one. */
    property var commandPalette: null
    /** Opens `path` with `params`, as a new step in the history. `hero` is
        `{ item, url }`: a picture that flies from `item` to the new page's `hero`. */
    function go(path, params, hero) {
        const component = pages[path]
        if (!component) { console.warn("Shell: no page at", path); return }
        if (path === shell.path && JSON.stringify(params || {}) === JSON.stringify(history[here].params || {})) return
        // What is ahead of here is forgotten, as a browser does.
        const dropped = history.slice(here + 1)
        for (const e of dropped) e.item.destroy()
        const entry = { path: path, params: params || {}, item: null }
        const item = component.createObject(paneSlot, { params: entry.params, shell: shell, width: Qt.binding(() => paneSlot.width), height: Qt.binding(() => paneSlot.height) })
        if (!item) { console.warn("Shell: page failed", path, component.errorString()); return }
        entry.item = item
        history = history.slice(0, here + 1).concat([entry])
        show(history.length - 1, sections.some(s => s.path === path) ? "up" : "in")
        if (hero && hero.item && hero.url) fly(hero, item)
    }

    // ---- The hero: one picture, shared between two pages ------------------
    function fly(hero, page) {
        const from = hero.item.mapToItem(shell, 0, 0)
        flight.stop(); land.stop()
        flyer.source = hero.url
        flyer.x = from.x; flyer.y = from.y; flyer.width = hero.item.width; flyer.height = hero.item.height
        flyer.opacity = 1; flyer.visible = true
        // The new page's hero has its place after a layout pass.
        Qt.callLater(() => {
            const target = page.hasOwnProperty("hero") ? page.hero : null
            if (!target || !target.visible) { flyer.visible = false; return }
            const to = target.mapToItem(shell, 0, 0)
            toX.to = to.x; toY.to = to.y; toW.to = target.width; toH.to = target.height
            flight.start()
        })
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
        if (deeper) { go(upPath()); return true }
        return false
    }

    function forward() {
        if (here < history.length - 1) show(here + 1, "in")
    }

    /** `dir`: `up` for a section (it settles), `in` for a page opened from another (it slides in from
        the right), `out` for going back (the page slides out to the right, the one under it comes back). */
    function show(i, dir) {
        const was = here >= 0 ? history[here].item : null
        here = i
        const item = history[i].item
        for (const e of history) if (e.item && e.item !== was && e.item !== item) e.item.visible = false
        item.visible = true
        item.x = 0
        item.back = Qt.binding(() => backTarget())
        if (was && was !== item) {
            // The page that was here leaves under the one arriving; one coming back settles in again.
            leaving.target = was
            slideOut.target = was
            slideOut.to = dir === "out" ? 40 : 0
            slideOut.duration = dir === "out" ? Theme.settle : Theme.lock
            leaving.duration = dir === "out" ? Theme.settle : Theme.lock
            leave.restart()
            if (item.hasOwnProperty("reveal")) item.reveal(dir === "out" ? "back" : dir)
            item.forceActiveFocus()
        }
        if (page && page.hasOwnProperty("filter")) finder.text = page.filter
    }
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { id: leaving; property: "opacity"; to: 0; duration: Theme.lock }
            NumberAnimation { id: slideOut; property: "x"; to: 0; duration: Theme.lock; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
        ScriptAction { script: { if (leaving.target && leaving.target !== shell.page) leaving.target.visible = false; if (leaving.target) { leaving.target.opacity = 1; leaving.target.x = 0 } } }
    }

    /** A page that isn't one of the sections, so it was opened from somewhere. */
    readonly property bool deeper: path !== "" && !sections.some(s => s.path === path)
    readonly property int current: sections.findIndex(s => s.path === path)

    function upPath() {
        const s = sections.find(s => s.path === home) || sections[0]
        return s ? s.path : home
    }

    function backTarget() {
        if (!deeper) return null
        if (here > 0) {
            const prev = history[here - 1]
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
            if (event.text === "/" && !keys && !shell.rail) { finder.input.forceActiveFocus(); finder.input.selectAll(); event.accepted = true; return }
            if (event.text === "/" && search !== "" && !keys) { go(search); event.accepted = true; return }
            if (event.key === Qt.Key_Escape && keys) { keys = false; event.accepted = true; return }
        }
        if (event.modifiers === Qt.ControlModifier || event.modifiers === Qt.MetaModifier) {
            if (event.key === Qt.Key_K && commandPalette) { commandPalette.show(); event.accepted = true; return }
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
        width: shell.rail ? Theme.rail : Theme.sidebar
        height: parent.height
        Behavior on width { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

        // The brand: the world's disc and name.
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
                Text {
                    visible: !shell.rail
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.w.name
                    font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textS
                    font.letterSpacing: Theme.track(0.28, Theme.textS); font.capitalization: Font.AllUppercase
                    color: Theme.textBright
                }
            }
            MouseArea { id: brandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.go(shell.home) }
            Hint { text: shell.w.tagline; when: brandMouse.containsMouse }
        }

        // The field: filters the page in place when it can, searches the app otherwise.
        Field {
            id: finder
            visible: !shell.rail
            x: 20
            y: brand.y + brand.height
            width: parent.width - 36
            label: ""
            placeholder: shell.page && shell.page.filters ? "Filter · /" : shell.search !== "" ? "Search · /" : "Find · /"
            readonly property bool filtering: !!shell.page && shell.page.filters
            onTextChanged: if (shell.page && shell.page.hasOwnProperty("filter")) shell.page.filter = text
            onAccepted: { if (!filtering && shell.search !== "" && text.trim() !== "") { const q = text.trim(); text = ""; shell.go(shell.search, { query: q }) } }
            Keys.onEscapePressed: { text = ""; shell.forceActiveFocus() }
        }

        // The sections, with the world's light on the current one.
        Item {
            id: list
            x: shell.rail ? Theme.s1 : Theme.s2
            y: shell.rail ? brand.y + brand.height + Theme.s2 : finder.y + finder.height + Theme.s3
            width: parent.width - x * 2
            height: sectionColumn.implicitHeight

            Rectangle {
                id: light
                x: 0
                width: 2
                height: Theme.control - 18
                color: Theme.world
                opacity: shell.current >= 0 ? 1 : 0
                y: (shell.current >= 0 ? shell.current : 0) * (Theme.control + 2) + 9
                property bool moved: false
                onYChanged: moved = true
                Behavior on y { enabled: light.moved; SpringAnimation { spring: 3.2; damping: 0.28; mass: 0.9 } }
                Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                RectangularShadow { anchors.fill: parent; blur: 8; spread: 0; color: Theme.world; z: -1 }
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
                        readonly property bool current: shell.path === modelData.path
                        Rectangle {
                            anchors.fill: parent
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
                            visible: !shell.rail && !!row.modelData.badge
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(18, badgeText.implicitWidth + 10); height: 18; radius: 9
                            color: Theme.world
                            Text { id: badgeText; anchors.centerIn: parent; text: row.modelData.badge || ""; font.family: Theme.font; font.pixelSize: 10; font.weight: Theme.weightLabel; color: Theme.space }
                            onVisibleChanged: if (visible) pop.restart()
                            SequentialAnimation { id: pop; NumberAnimation { target: badge; property: "scale"; from: 0.6; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                        }
                        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: shell.go(row.modelData.path) }
                        Hint { text: [row.modelData.hint, row.index < 9 ? "Ctrl+" + (row.index + 1) : ""].filter(Boolean).join(" · "); when: rowMouse.containsMouse }
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
                    place: shell.sections.length + index
                    width: doorColumn.width
                    height: Theme.control
                    Rectangle { anchors.fill: parent; color: doorMouse.containsMouse ? Theme.surface : "transparent"; Behavior on color { ColorAnimation { duration: Theme.fade } } }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: shell.rail ? parent.horizontalCenter : undefined
                        x: 12; spacing: 12
                        WorldGlyph { world: door.modelData.world; size: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            visible: !shell.rail
                            anchors.verticalCenter: parent.verticalCenter
                            text: door.modelData.label
                            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                            color: doorMouse.containsMouse ? Theme.textBright : Theme.textQuiet
                            Behavior on color { ColorAnimation { duration: Theme.fade } }
                        }
                    }
                    MouseArea { id: doorMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: door.modelData.open() }
                    Hint { text: door.modelData.hint || ""; when: doorMouse.containsMouse }
                }
            }
        }

        // The bottom: where the app stands with Sol.
        Column {
            id: statusSlot
            visible: !shell.rail
            x: 20
            width: parent.width - 36
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
        Item {
            id: footSlot
            anchors.bottom: parent.bottom
            width: parent.width
            height: childrenRect.height
            Rectangle { anchors.fill: parent; color: Theme.space; z: -1 }
        }
    }

    // Notices drop in at the top edge.
    Column {
        id: noticeStack
        x: pane.x + (pane.width - width) / 2
        y: Theme.s3
        width: Math.min(440, shell.width - 32)
        spacing: Theme.s2
        z: 50
        Repeater {
            model: Notices.list
            delegate: Notice { required property int index; width: noticeStack.width; model: Notices.list.get(index) }
        }
    }

    Loader {
        anchors.fill: parent
        active: shell.keys
        sourceComponent: Shortcuts { shortcuts: shell.shortcuts; search: shell.search !== ""; sections: shell.sections.length; onClosed: shell.keys = false }
    }

    Grain { }
}

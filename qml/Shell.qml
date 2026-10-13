pragma ComponentBehavior: Bound
import QtQuick
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
    history still leads to it. A section opened with params from another
    page (`/write?day=…` from the Diary) is a page opened from it: it
    slides in and shows the way back.

    A section may have children (`children: [{ path, label, icon? }]`):
    one row that opens out to them while it or one of them is open; Ctrl +
    1…9 count only the sections. A page with tabs (a PageHead's `tabs`)
    keeps its tab in its path (`/schedule?tab=calendar`): a section opened
    with only its tab is still the section, and choosing a tab changes the
    step in the history instead of adding one (`retab`). A tab may be a page
    of its own: `pages: ({ "/schedule": calendar, "/schedule?tab=timeline":
    timeline })`, each with the same PageHead tabs; choosing one puts its
    page in that step. Paths that moved stay reachable through `aliases`
    (`{ "/calendar": "/schedule?tab=calendar" }`).

    The world's light marks the current section and glides to the next one
    when it changes; each screen settles into the pane as it opens, under
    the world's own way of turning a page (`PageTurn`).

        Shell {
            world: "terra"
            sections: [{ path: "/", label: "Today", icon: "sun", hint: "What's on today" }, { path: "/settings", label: "Settings", icon: "settings" }]
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
    /** `{ path, label, hint, icon?, world?, badge?, children?, tabs? }`, in the order of the sidebar; `icon` is an `Icon`
        name. `children` are pages of their own under it, `{ path, label, hint?, icon? }`: the row opens out to them
        while it or one of them is open. `tabs` (`{ id, label }`, as its PageHead has them) are offered by the palette. */
    property var sections: []
    /** Every row of the sidebar, a section's children after it (`child: true`, `parent` its path, `top` its section's place). */
    readonly property var rows: {
        const out = []
        sections.forEach((s, i) => {
            out.push(Object.assign({}, s, { top: i, child: false }))
            for (const c of s.children || []) out.push(Object.assign({ world: s.world }, c, { top: i, child: true, parent: s.path }))
        })
        return out
    }
    /** Path → Component. A path not in the sections is a page opened from another. A section's tab that is a
        page of its own is its path with the tab: `/schedule?tab=timeline`. */
    property var pages: ({})
    /** Paths that moved, still reachable (links, other apps and quick capture may name them): path →
        `/path?key=value`, its params under the ones asked with (`/season?year=2024` → `/discover?tab=season&year=2024`).
        A page at the path itself comes first. */
    property var aliases: ({})
    /** Where `path` leads through `aliases`, and its params: `[path, params]`. */
    function resolve(path, params) {
        const to = pages[path] ? undefined : aliases[path]
        if (!to) return [path, params]
        const [p, query] = to.split("?")
        const own = {}
        for (const pair of (query || "").split("&").filter(Boolean)) {
            const [k, v] = pair.split("=").map(decodeURIComponent)
            own[k] = v || ""
        }
        return [p, Object.assign(own, params)]
    }
    /** The page `path` opens with `params`: its tab's own page (`/schedule?tab=timeline`), or the path's. */
    function pageKey(path, params) {
        const tab = params ? params.tab : undefined
        return tab !== undefined && pages[path + "?tab=" + tab] ? path + "?tab=" + tab : path
    }
    /** The moons this app carries (their ids): pages under `/<moon>` are theirs. */
    property var moons: []
    /** The world a path's page belongs to: a carried moon's under `/<moon>`, else the app's own. */
    function worldOf(path) {
        for (const m of moons) if (path === "/" + m || path.indexOf("/" + m + "/") === 0) return m
        return world
    }
    /** Doors to other apps, under the sections: `{ world, label, hint, open }`. */
    property var doors: []
    property string home: "/"
    /** Where `/` leads. */
    property string search: ""
    /** The app's own keys, for the sheet `?` opens. */
    property var shortcuts: []
    /** The bottom of the sidebar: LinkStatus. */
    property alias status: side.status
    /** A bar along the bottom of the pane, e.g. a player's transport. */
    property alias footer: footSlot.data
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
    /** Section path (or a tab's own page's, `pageKey`) → its page, made the first time it's opened. */
    property var sectionPages: ({})
    /** Section path → the tab it was left on. */
    property var tabOf: ({})
    /** Remembers the tab a section's step is on (none: its first). */
    function keepTab(path, params) {
        if (!isSection(path) || !ownParams(params)) return
        if (params.tab !== undefined) tabOf[path] = params.tab
        else delete tabOf[path]
    }
    property bool keys: false

    // The accent: every page, a moon's too, wears the flavour's own light; a moon with a
    // flavour of its own (Luna's evening) wears that one while its page is open.
    function accent() {
        const of = here >= 0 && history[here] ? worldOf(history[here].path) : world
        Theme.worldId = Theme.yozoraLooks[of] ? of : world
        Theme.world = Theme.hudAccent
        // And in its own voice.
        Sounds.world = of
    }
    Component.onCompleted: { accent(); go(home) }
    onWorldChanged: accent()

    /** The section or the child of one at `path`, or null. */
    function sectionOf(path) {
        for (const s of sections) {
            if (s.path === path) return s
            for (const c of s.children || []) if (c.path === path) return c
        }
        return null
    }
    function isSection(path) { return !!sectionOf(path) }
    /** Params that leave a section the section: none, its tab, or the part of it to show (`/settings?part=titan`). */
    function ownParams(params) { return Object.keys(params).every(k => k === "tab" || k === "part") }

    /** On the rail, the sidebar's field is folded away until it is used. */
    property bool finding: false
    onRailChanged: finding = false
    /** The sidebar's field gets the keys (on the rail, it unfolds over the pane first). */
    function find() {
        finding = true
        Qt.callLater(() => { side.finder.input.forceActiveFocus(); side.finder.input.selectAll() })
    }

    /** Opens `path` with `params`, as a new step in the history. `hero` is
        `{ item, url }`: a picture that flies from `item` to the new page's `hero`. */
    function go(path, params, hero) {
        // A moon's page may name its own pages as the moon's app did (`/moon`): where the app
        // has no page of that path, it is the moon's, under `/<moon>`.
        const from = here >= 0 && history[here] ? worldOf(history[here].path) : world
        if (from !== world && !pages[path] && (pages["/" + from + path] || aliases["/" + from + path])) path = "/" + from + path
        const to = resolve(path, params || {})
        path = to[0]
        params = to[1]
        if (!pages[path]) { console.warn("Shell: no page at", path); return }
        const section = isSection(path) && ownParams(params)
        // A section opened without a tab comes back on the tab it was left on.
        if (section && params.tab === undefined && tabOf[path] !== undefined) params = Object.assign({ tab: tabOf[path] }, params)
        if (path === shell.path && JSON.stringify(params) === JSON.stringify(history[here].params)) return
        const key = pageKey(path, params)
        let item = section ? sectionPages[key] : null
        if (item && JSON.stringify(item.params) !== JSON.stringify(params)) item.params = params
        if (!item) {
            item = make(path, key, params)
            if (!item) return
            if (section) sectionPages[key] = item
        }
        keepTab(path, params)
        // What is ahead of here is forgotten, as a browser does; past `remembered`, the oldest too.
        let kept = history.slice(0, here + 1).concat([{ path: path, params: params, item: item }])
        let dropped = history.slice(here + 1)
        if (kept.length > remembered) { dropped = dropped.concat(kept.slice(0, kept.length - remembered)); kept = kept.slice(kept.length - remembered) }
        history = kept
        release(dropped)
        show(history.length - 1, section ? "up" : "in")
        if (hero && hero.item && hero.url) fly(hero, item)
    }

    /** A page for `path` from its Component at `key` (the path, or its tab's own), hidden until shown. */
    function make(path, key, params) {
        const of = worldOf(path)
        const props = { params: params, shell: shell, visible: false, width: Qt.binding(() => paneSlot.width), height: Qt.binding(() => paneSlot.height) }
        // A moon's page is the moon's; the app's own keep theirs (a page may say its own `world`).
        if (of !== world) props.world = of
        const item = pages[key].createObject(paneSlot, props)
        if (!item) console.warn("Shell: page failed", key, pages[key].errorString())
        return item
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
        flyerScale.xScale = 1; flyerScale.yScale = 1
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
            // The flyer takes the landing's size at once and is scaled back down to where it
            // left from: the flight moves and scales it (the compositor's work), never resizes it.
            const fromW = flyer.width, fromH = flyer.height
            flyer.width = target.width; flyer.height = target.height
            flyerScale.xScale = target.width > 0 ? fromW / target.width : 1
            flyerScale.yScale = target.height > 0 ? fromH / target.height : 1
            toX.to = to.x; toY.to = to.y
            flight.start()
        }
    }
    Item {
        id: flyer
        property alias source: flyerImage.source
        visible: false
        z: 40
        transform: Scale { id: flyerScale }
        layer.enabled: visible
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowOpacity: 0.6; shadowVerticalOffset: 10 }
        Image {
            id: flyerImage
            anchors.fill: parent
            visible: false
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            // Decoded no wider than a Picture ever asks for, however large the file.
            sourceSize.width: 1280
        }
        Rounded { anchors.fill: parent; image: flyerImage; radius: 0 }
    }
    Settling { when: flight.running || land.running || landing.running || leave.running }
    SequentialAnimation {
        id: flight
        ParallelAnimation {
            NumberAnimation { id: toX; target: flyer; property: "x"; duration: Theme.settle; easing: Theme.easeOut }
            NumberAnimation { id: toY; target: flyer; property: "y"; duration: Theme.settle; easing: Theme.easeOut }
            NumberAnimation { target: flyerScale; property: "xScale"; to: 1; duration: Theme.settle; easing: Theme.easeOut }
            NumberAnimation { target: flyerScale; property: "yScale"; to: 1; duration: Theme.settle; easing: Theme.easeOut }
        }
        ScriptAction { script: land.start() }
    }
    SequentialAnimation { id: land; NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: Theme.fade } PropertyAction { target: flyer; property: "visible"; value: false } }

    function back() {
        if (here > 0) { show(here - 1, "out"); return true }
        // Opened first thing: up to its section, or home.
        if (opened(history[here])) { go(upPath()); return true }
        return false
    }

    function forward() {
        if (here < history.length - 1) show(here + 1, "in")
    }

    /** The page on screen takes `params` in place of its own, the same step in the history (a tab
        chosen: `retab(Object.assign({}, page.params, { tab: "calendar" }))`), so going back and forth
        and the palette find it as it was left. */
    function retab(params) {
        if (here < 0) return
        const e = history[here]
        const was = e.item
        const before = pageKey(e.path, e.params)
        const key = pageKey(e.path, params)
        e.params = params
        keepTab(e.path, params)
        if (key === before) { was.params = params; return }
        // The tab is a page of its own: it takes this step's place, settling in as a section does.
        const section = isSection(e.path) && ownParams(params)
        let item = section ? sectionPages[key] : null
        if (item && JSON.stringify(item.params) !== JSON.stringify(params)) item.params = params
        if (!item) {
            item = make(e.path, key, params)
            if (!item) return
            if (section) sectionPages[key] = item
        }
        e.item = item
        // A page that was no section's goes once it has left.
        if (!Object.values(sectionPages).includes(was)) dropping = was
        show(here, "up", was)
    }
    /** A page left by `retab` that nothing leads to any more: destroyed once it has left. */
    property Item dropping: null

    /** `dir`: `up` for a section (it settles), `in` for a page opened from another (it slides in from
        the right), `out` for going back (the page slides out to the right, the one under it comes back).
        `from`: the page leaving, when it isn't the one at `here` (a tab's own page taking its step). */
    function show(i, dir, from) {
        // A leave still running (back and forth quickly) is finished first.
        if (leave.running) { leave.stop(); settleLeaving() }
        const was = from !== undefined ? from : here >= 0 ? history[here].item : null
        here = i
        const entry = history[i]
        const item = entry.item
        for (const e of history) if (e.item && e.item !== was && e.item !== item) e.item.visible = false
        item.visible = true
        // A section's one page, back on the tab this step had.
        if (isSection(entry.path) && JSON.stringify(item.params) !== JSON.stringify(entry.params)) item.params = entry.params
        keepTab(entry.path, entry.params)
        item.x = 0
        item.opacity = 1
        item.back = backFor(entry)
        accent()
        if (was && was !== item) {
            // The page that was here leaves under the one arriving; one coming back settles in again.
            // Saturn's cut: the page that was here is gone at once, as in a film; with less motion, a fade only.
            const cut = Theme.hud.motif === "dusk" && !Theme.calm
            leaving.target = was
            slideOut.target = was
            slideOut.to = dir === "out" && !Theme.calm && !cut ? 40 : 0
            slideOut.duration = cut ? Theme.snap : dir === "out" ? Theme.turn : Theme.lock
            leaving.duration = cut ? Theme.snap : dir === "out" ? Theme.turn : Theme.lock
            leave.restart()
            if (item.hasOwnProperty("reveal")) item.reveal(dir === "out" ? "back" : dir)
            turn.play(dir === "out" ? "back" : dir)
        }
        shell.forceActiveFocus()
        const screen = page as Design.Screen
        if (screen) side.finder.text = screen.filter
    }
    function settleLeaving() {
        const t = leaving.target as Item
        if (!t) return
        if (t === dropping) { dropping = null; leaving.target = null; slideOut.target = null; t.destroy(); return }
        if (t !== shell.page) t.visible = false
        t.opacity = 1
        t.x = 0
    }
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { id: leaving; property: "opacity"; to: 0; duration: Theme.lock }
            NumberAnimation { id: slideOut; property: "x"; to: 0; duration: Theme.lock; easing: Theme.easeOut }
        }
        ScriptAction { script: shell.settleLeaving() }
    }

    /** The section on screen, or the one whose child is, by its place in `sections`; -1 for none. */
    readonly property int current: sections.findIndex(s => s.path === path || (s.children || []).some(c => c.path === path))
    /** The sidebar row on screen (a child's own row when a child is), by its place in `rows`; -1 for none. */
    readonly property int currentRow: rows.findIndex(r => r.path === path)

    function upPath() {
        const s = sections.find(s => s.path === home) || sections[0]
        return s ? s.path : home
    }

    /** Whether `entry`'s page was opened from another: a page that isn't a section, or a section's
        path opened with params from another path (`/write?day=…` from the Diary). */
    function opened(entry) {
        if (!isSection(entry.path)) return true
        if (ownParams(entry.params)) return false
        const at = history.indexOf(entry)
        return at <= 0 || history[at - 1].path !== entry.path
    }

    /** The way back from `entry`'s page: the step before it, or up to its section. A section has none. */
    function backFor(entry) {
        if (!opened(entry)) return null
        const at = history.indexOf(entry)
        if (at > 0) {
            const prev = history[at - 1]
            const section = sectionOf(prev.path)
            return { label: section ? section.label : (prev.item.title || "Back"), go: () => shell.back() }
        }
        const up = sectionOf(upPath())
        return { label: up ? up.label : "Home", go: () => shell.go(upPath()) }
    }

    /** Closes the keys and opens the window's first-run tour again (the `?` sheet's button). */
    function takeTour() { keys = false; const w = Window.window; if (w && w.tourSheet) w.tourSheet.show() }

    // ---- Keys ---------------------------------------------------------------
    /** Keys go to a field that takes text, not to the Shell. */
    function typing() { return Theme.typing(Window.activeFocusItem) }

    Keys.onPressed: event => {
        if (event.modifiers === Qt.AltModifier && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            if (typing()) return
            if (event.key === Qt.Key_Right) forward(); else if (!back()) return
            event.accepted = true; return
        }
        if (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier) {
            if (typing()) return
            if (event.text === "?") { keys = !keys; event.accepted = true; return }
            if (event.text === "/" && !keys && side.finder.usable) { find(); event.accepted = true; return }
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
    /** Under everything: the page's still in the world's grade, which HudGlass blurs. */
    readonly property Item ground: groundItem
    /** The ground blurred once for the whole window: every HudGlass on a page reads the part under it. */
    readonly property Item groundBlur: groundBlurItem
    /** The world's stills on this computer (`Theme.groundsOf`). */
    readonly property var stills: Theme.groundsOf(world)
    /**
        The still under the page on screen: its own `ground` (a title's key art), else
        one of the world's stills, the same for every page of a section (a moon's
        group counts on from its planet's, or stands on the moon's own stills when
        it has some), so going from section to section turns the stills over.
    */
    readonly property string groundSource: {
        const screen = page as Design.Screen
        if (screen && screen.ground !== "") return screen.ground
        // A page opened from another stands on the still of the section it came from.
        let row = null
        for (let i = here; i >= 0; i--) {
            row = rows.find(r => r.path === history[i].path) || null
            if (row) break
        }
        // A moon with stills of its own (Luna's evening) stands on them, counted from its first section.
        const moon = row && row.world && row.world !== world ? Theme.ownGroundsOf(row.world) : []
        if (moon.length) return moon[(row.top - rows.find(r => r.world === row.world).top) % moon.length]
        if (!stills.length) return ""
        return stills[(row ? row.top : 0) % stills.length]
    }
    /**
        What the world's navigator says (the Navigator, in the sidebar's
        foot), in English and in Japanese: the page's own `say` and
        `sayJp`, else a greeting on the first page, else nothing (it keeps
        quiet). While the page's empty state speaks beside its own
        portrait (`Screen.emptySay`), this one keeps quiet and steps away
        (`navigatorAway`): one navigator and one bubble at a time.
    */
    /** The page's empty state has the navigator beside it: the sidebar's steps away meanwhile. */
    readonly property bool navigatorAway: { const screen = page as Design.Screen; return !!screen && screen.emptySay !== "" }
    readonly property string navigatorLine: navigatorSays.line
    readonly property string navigatorJp: navigatorSays.jp
    readonly property var navigatorSays: {
        const screen = page as Design.Screen
        if (!screen || screen.emptySay !== "") return { jp: "", line: "" }
        if (screen.say !== "" || screen.sayJp !== "") return { jp: screen.sayJp, line: screen.say }
        if (path !== home) return { jp: "", line: "" }
        const h = Worlds.now.getHours()
        return h < 5 || h >= 23 ? { jp: "まだ起きてるの？", line: "Still up? Welcome back." }
            : h < 11 ? { jp: "おはよう。", line: "Good morning. Welcome back." }
            : h < 17 ? { jp: "おかえり。", line: "Good afternoon. Welcome back." }
            : { jp: "こんばんは。", line: "Good evening. Welcome back." }
    }
    /** How far the navigator reaches past the sidebar into the pane: a sparse page's big title keeps clear of it. */
    readonly property real navigatorReach: side.navigatorReach

    Design.DuskGround { id: groundItem; anchors.fill: parent; source: shell.groundSource }
    // Drawn only into the panels that read it: a quarter of the pixels, blurred, redrawn
    // only when the ground changes (a still fading in), never while it rests.
    MultiEffect {
        id: groundBlurItem
        anchors.fill: parent
        visible: false
        source: groundPicture
        blurEnabled: true
        // Enough to make words on glass read, little enough that the shapes of the still show through.
        blur: 0.78
        blurMax: 48
        autoPaddingEnabled: false
        layer.enabled: true
        ShaderEffectSource {
            id: groundPicture
            anchors.fill: parent
            visible: false
            live: true
            sourceItem: groundItem
            textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
        }
    }

    // The sidebar floats on its own glass, clear of the window's edges.
    readonly property real sideInset: !rail ? Theme.s4 : 0
    Sidebar { id: side; frame: shell; x: shell.sideInset; y: shell.sideInset; height: parent.height - shell.sideInset * 2 }

    // The pane: the pages, and a footer that is always there.
    Item {
        id: pane
        x: side.x + side.width
        width: parent.width - x
        height: parent.height
        clip: true

        Item {
            id: paneSlot
            width: parent.width
            height: parent.height - footSlot.height
        }
        // The world's way of turning a page, over the page as it arrives.
        Design.PageTurn { id: turn; anchors.fill: paneSlot; z: 5 }
        // Behind the footer, outside it, so the footer's height follows what is in it.
        Design.HudGlass { visible: footSlot.height > 0; anchors.fill: footSlot; cuts: [0, 0, 0, 0] }
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
        sourceComponent: Shortcuts { tour: !!shell.Window.window && !!shell.Window.window.tour && shell.Window.window.tour.length > 0; onTourAsked: shell.takeTour(); shortcuts: shell.shortcuts; actions: (shell.Window.window && shell.Window.window.allCommands) || []; finderShown: side.finder.usable; search: shell.search !== ""; sections: shell.sections.length; onClosed: shell.keys = false }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtCore
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    A world app's window, the same for every world: the Connect screen
    until the app is paired, then the Shell with the app's sections and
    pages. Remembers its size, comes up when another copy is started, and
    stays out of sight when a moon runs with its planet. Closing it hides it
    while there is a tray to come back from (or, for a moon, while its
    planet runs); Quit, from the tray or anywhere, closes it for good.

        AppWindow {
            world: "exoplanet"
            sections: [{ path: "/", label: "Log", icon: "list", hint: "What happened, newest first" }, { path: "/settings", label: "Settings", icon: "settings", hint: "Sol, the world’s settings and updates" }]
            pages: ({ "/": log, "/settings": settings })
            Component { id: log; LogPage { } }
            Component { id: settings; SettingsPage { } }
        }
*/
Window {
    id: win

    property string world: Sol.world
    property var sections: []
    property var pages: ({})
    property string home: "/"
    property string search: ""
    property var shortcuts: []
    /** What the app is doing right now instead of syncing, e.g. `Syncing AniList`. */
    property string busy: ""
    /** Something wrong beside Sol, e.g. `Navidrome · not answering`. */
    property string warn: ""
    /** A bar along the bottom of the pane (a Component), e.g. a player's transport. */
    property Component footer: null
    readonly property var w: Worlds.get(world)
    /** The Shell, once paired. */
    readonly property Shell shell: frame.item as Shell
    /** One right-click menu and one dialog for the whole app. */
    readonly property alias menu: contextMenu
    readonly property alias ask: askBox
    /** The writes kept aside instead of sent (conflicts and the like): `keptAside.open()`. */
    readonly property alias keptAside: keptBox
    /** Why this device's copy didn't open, or null: the window asks what to do instead of showing the app. */
    readonly property var problem: Sol.problem || stagedProblem
    // `_problem=newer|damaged` in the shot path: the same, staged for a picture (from the start, so the Shell never loads).
    readonly property var stagedProblem: {
        const m = SolBackend.shotPath.match(/[?&]_problem=(\w+)/)
        return m ? { problem: m[1], path: "/home/you/.local/share/digital.sachi.sol." + world + "/" + world + ".db", detail: "file is not a database" } : null
    }
    /** What glass panels (menus, notices, hints) blur: the frame the pages live in. */
    readonly property Item backdrop: frame
    /** The command palette's own entries: `{ label, hint, keys, icon, run }` (`icon` optional, an `Icon` name). */
    property var commands: []
    /** What the palette finds as you type: `function(query) → Promise<[{ label, hint, run }]>`. */
    property var find: null
    readonly property alias commandPalette: paletteBox
    /** What the palette offers to do: the window's `commands`, then the page's own (`Screen.actions`). */
    readonly property var allCommands: {
        const p = shell ? shell.page as Design.Screen : null
        return commands.concat(p && p.actions ? p.actions : [],
            tour.length ? [{ label: "Take the tour", icon: "info", hint: "What " + w.name + " does, its best key, where to start", run: () => tourBox.show() }] : [])
    }
    /**
        The world's first-run tour: three cards, `{ title, body, keys?, icon?, go?, start? }`
        (what it does, its best key, where to start). Shown once on this device
        the first time the window is in front (never in a preview or a picture,
        unless `_tour=1` stages it); `?` and the palette open it again.
    */
    property var tour: []
    readonly property alias tourSheet: tourBox
    Settings { id: tourPrefs; category: "sol." + win.world; property bool toured: false }
    // Once the Shell is up and the window in front, a moment after, so the first page has settled.
    readonly property bool tourDue: tour.length > 0 && !tourPrefs.toured && !Sol.preview && SolBackend.shot === "" && SolBackend.drive === "" && !!shell && Theme.alive
    onTourDueChanged: if (tourDue) tourLater.restart()
    Timer { id: tourLater; interval: 1400; onTriggered: if (win.tourDue && !momentBox.showing) tourBox.show() }
    /** The window's moment, over everything: `moment.play({ occasion, scene, facts, chime })` (see Moment). */
    readonly property alias moment: momentBox
    /**
        The world's moments a picture can stage, by name: `_moment=<name>` in
        the shot path (or `<name>:<arg>`) plays one, without its occasion. Each
        is `{ scene, facts, chime, length }`, or a function of the arg giving
        one (or a promise of one): `moments: ({ sunrise: () => ({ scene: sunrise, facts: … }) })`.
    */
    property var moments: ({})
    function stageMoment(spec) {
        const at = spec.indexOf(":"), name = at < 0 ? spec : spec.slice(0, at)
        const m = win.moments[name]
        if (!m) { if (Object.keys(win.moments).length) console.warn("no moment called " + name + " to stage"); return }
        Promise.resolve(typeof m === "function" ? m(at < 0 ? "" : spec.slice(at + 1)) : m)
            .then(o => { if (o) momentBox.play(Object.assign({}, o, { occasion: "" })) })
            .catch(why => console.warn("the staged moment failed", why))
    }
    /** Quick capture is open over the desktop (its key, through the door); false closes it. */
    property bool capturing: false
    /** `_capture=<line>` in the shot path: quick capture opened with that line typed, and a picture of it. */
    property string stagedCapture: ""
    /** What the app shows on the desktop when asked to (a Component), and what it is called: "Now playing". */
    property Component widget: null
    property string widgetName: ""
    /** Whether the widget shows, and in which corner: per device, from Settings → On this device. */
    readonly property alias widgetPrefs: widgetPrefs
    Settings { id: widgetPrefs; category: "sol." + win.world; property bool widget: false; property string corner: "top-right" }
    /** Layer-shell surfaces need Wayland; elsewhere there is no widget to offer. */
    readonly property bool widgetsHere: Qt.platform.pluginName === "wayland"

    // What the app is for, beside its name, in the taskbar and the window switcher.
    title: w.role ? w.name + " · " + w.role : w.name
    color: Theme.space
    minimumWidth: 360
    minimumHeight: 560
    width: 1180
    height: 800
    visible: !Sol.background

    // The size as it was left; written only when it changes, and never the
    // maximized size (the size to come back to stays).
    property var saved: ({})
    property bool restored: false
    Component.onCompleted: {
        shots.read()
        try { saved = JSON.parse(SolBackend.windowState() || "{}") } catch (e) { saved = {} }
        if (saved.width >= minimumWidth && saved.height >= minimumHeight) { width = saved.width; height = saved.height }
        if (saved.maximized) showMaximized()
        restored = true
        Qt.callLater(win.begin)
    }
    function remember() {
        const maximized = visibility === Window.Maximized
        const s = maximized ? Object.assign({}, saved, { maximized: true }) : { width: width, height: height, maximized: false }
        if (JSON.stringify(s) === JSON.stringify(saved)) return
        saved = s
        SolBackend.saveWindow(JSON.stringify(s))
    }
    onWidthChanged: if (restored) keep.restart()
    onHeightChanged: if (restored) keep.restart()
    onVisibilityChanged: if (restored) keep.restart()
    Timer { id: keep; interval: 800; onTriggered: win.remember() }

    /** Closes the window for good and ends the app (the tray's Quit, an update, a picture taken). */
    property bool quitting: false
    function quit() { quitting = true; remember(); Qt.quit() }
    onClosing: close => {
        remember()
        // Hidden, not closed: the tray brings it back, or the planet keeps the moon working.
        if (!quitting && (SolBackend.tray || SolBackend.background)) { close.accepted = false; win.hide() }
    }

    /**
        The moment to start the app's own work (read its setup, load what
        the sidebar counts): once it is paired, at once in preview. Comes
        once a run, and again only after an unpair and a new pairing, never
        when the app merely goes offline and back. After the window's own
        `Component.onCompleted`, so what that sets up is there.

            onStarted: Saturn.start()
    */
    signal started()
    /** Whether `started` has come for this pairing. */
    property bool begun: false
    function begin() {
        const ready = Sol.paired || Sol.preview
        if (ready && !begun) { begun = true; started() }
        else if (!ready && !!Sol.status && Sol.status.state === "unpaired") begun = false
    }
    Connections { target: Sol; function onStatusChanged() { win.begin() } }

    // Writes kept aside: a notice when there are more than before, with a
    // way to see them. While unpaired the Connect screen says it instead.
    property var keptBefore: ({ conflicts: 0, rejected: 0, earlier: 0 })
    Connections { target: Sol; function onKeptChanged() { win.tellKept() } }
    function tellKept() {
        const k = Sol.kept, b = keptBefore
        keptBefore = k
        if (!Sol.paired) return
        const see = () => keptBox.open()
        const n = (count, one, many) => count === 1 ? one : count + " " + many
        if (k.conflicts > b.conflicts)
            Notices.show({ world: win.world, title: "Changed on another device too", action: "See both", run: see,
                body: n(k.conflicts, "Both copies are kept; you choose which stays.", "things changed on two devices; both copies of each are kept.") })
        if (k.rejected > b.rejected)
            Notices.show({ world: win.world, title: "Sol couldn’t take a change", tone: "error", action: "See it", run: see,
                body: "It is kept on this device, so nothing is lost." })
        if (k.earlier > b.earlier)
            Notices.show({ world: win.world, title: "Changes from before", action: "See them", run: see,
                body: n(k.earlier, "A change made before this device was paired again is kept here.", "changes made before this device was paired again are kept here.") })
    }

    // Awake: visible and in front. Everything that breathes, drifts or polls stops otherwise.
    readonly property bool awake: visible && active
    Binding { target: Theme; property: "alive"; value: win.awake }

    Connections {
        target: SolBackend
        function onActivate() { win.show(); win.raise(); win.requestActivate() }
        function onPlanetGone() { if (!win.visible) win.quit() }
        function onQuitRequested() { win.quit() }
        function onOpenRequested(path) { win.goTo(path) }
        function onCaptureRequested() { if (win.capturing && captureLoader.item) captureLoader.item.requestActivate(); else win.capturing = true }
    }

    // Quick capture: one line over the desktop, from outside the compiled
    // module like the widget (it needs layer-shell); see Capture.qml.
    Loader {
        id: captureLoader
        active: win.capturing && win.widgetsHere
        Component.onCompleted: setSource(Qt.resolvedUrl("../assets/capture/Capture.qml"), { host: win })
        onStatusChanged: if (status === Loader.Error) { console.warn("no quick capture here (layer-shell missing?)"); win.capturing = false }
    }

    /**
        Opens a page given as `/title?key=x` (another app asked for it, or
        `--open`) in `into` (the window's Shell when not given: the Shell
        itself passes itself while it is still being made, before
        `shell` is set); keys starting with `_` stage a screenshot instead
        of being params. Returns those staging keys at once; the page opens
        a moment later, after the Shell has opened its home, so it is the
        one left showing.
    */
    function goTo(spec, into) {
        const [path, query] = spec.split("?")
        const params = {}, stage = {}
        for (const pair of (query || "").split("&").filter(Boolean)) {
            const [k, v] = pair.split("=").map(decodeURIComponent)
            if (k.startsWith("_")) stage[k] = v || "1"; else params[k] = v || ""
        }
        const target = into || win.shell
        if (target && path) Qt.callLater(() => target.go(path, params))
        return stage
    }

    // Ctrl+K anywhere, inside a field too.
    Shortcut { sequence: "Ctrl+K"; enabled: !!win.shell; onActivated: paletteBox.show() }

    // SOL_FPS=1: how many frames the window really paints a second, in the journal: 0 while
    // nothing moves (a FrameAnimation would count ticks, and keep ticking, instead).
    QtObject { id: frames; property int n: 0 }
    Connections { target: win; enabled: SolBackend.fps; function onFrameSwapped() { frames.n++ } }
    Timer { interval: 1000; repeat: true; running: SolBackend.fps; onTriggered: { console.info("fps", frames.n); frames.n = 0 } }

    // The widget on the desktop, from outside the compiled module (see DesktopWidget.qml).
    /** The widget's own window while it shows, else null. */
    readonly property Window desktopWidget: widgetLoader.item as Window
    Loader {
        id: widgetLoader
        active: !!win.widget && win.widgetPrefs.widget && win.widgetsHere
        // Handed the window, which it reads its content and corner from.
        Component.onCompleted: setSource(Qt.resolvedUrl("../assets/widget/DesktopWidget.qml"), { host: win })
        onStatusChanged: if (status === Loader.Error) console.warn("no desktop widget here (layer-shell missing?)")
    }

    // SOL_DRIVE=<file.qml>: a script from outside the app that drives the window
    // through real input events, to check it end to end. Handed the window.
    // A script that doesn't load says so in the journal and leaves the rest
    // (a screenshot, the window) alone.
    Loader {
        active: SolBackend.drive !== ""
        source: active ? Sol.fileUrl(SolBackend.drive) : ""
        onLoaded: item.win = win
        onStatusChanged: if (status === Loader.Error) console.warn("SOL_DRIVE: the script didn't load:", SolBackend.drive)
    }

    // Pictures of the window for review: SOL_SHOT=<file.png> (one, of
    // SOL_SHOT_PATH), or SOL_SHOTS (many, one after another in this run:
    // `<file.png>=<path?keys>` each, a line or `;` apart). Each opens its
    // page, scrolls it (`_scroll=N`, `end`), stages what its keys ask for and
    // is taken once the page is ready: nothing arriving or loading
    // (Theme.settling), every command answered (Sol.waiting), then 150 ms
    // without a new frame (or a second, when something keeps moving: a
    // breathing button, a turning world). SOL_SHOT_AFTER (8 s unless given)
    // is the most a picture waits; `_after=<ms>` makes one wait at least that
    // long, for what the rule can't see. The clock starts when the window
    // shows what it is for (the Shell, Connect), not when it opened. Beside a
    // SOL_DRIVE script it doesn't quit: the script ends the run.
    QtObject {
        id: shots
        /** `{ png, path }`, in order. */
        property var list: []
        property int at: -1
        /** Where the current picture is: `page`, `scrolled`, `staged`, `taking`. */
        property string step: ""
        property var stage: ({})
        property double since: 0
        property double calmSince: 0
        property double lastFrame: 0
        property Item scrolledPage: null
        readonly property bool active: at >= 0 && at < list.length

        function read() {
            const out = []
            for (const line of SolBackend.shots.split(/[\n;]/)) {
                const l = line.trim()
                if (l === "" || l.startsWith("#")) continue
                const eq = l.indexOf("=")
                if (eq <= 0) { console.warn("SOL_SHOTS: not <file.png>=<path>:", l); continue }
                out.push({ png: l.slice(0, eq).trim(), path: l.slice(eq + 1).trim() })
            }
            if (!out.length && SolBackend.shot !== "") out.push({ png: SolBackend.shot, path: SolBackend.shotPath })
            list = out
            if (out.length) { SolBackend.shot = out[0].png; SolBackend.shotPath = out[0].path }
            // The frame may have loaded before the window was complete.
            if (frame.item && frame.sourceComponent !== waiting) Qt.callLater(begin)
        }
        function begin() { if (list.length && at < 0) take(0) }
        function take(i) {
            at = i
            const e = list[i]
            if (i > 0) clear()
            SolBackend.shot = e.png
            SolBackend.shotPath = e.path
            stage = win.goTo(e.path)
            step = "page"
            // What was calm stays calm: a page that is already there and settled (the same one,
            // scrolled elsewhere next) is taken at once; one that changes counts itself busy.
            since = Date.now()
            if (i === 0) calmSince = since
            tick.start()
        }
        // What the picture before staged goes, so the next starts from the page alone.
        function clear() {
            paletteBox.close(); askBox.finish(false); contextMenu.close(); tourBox.close()
            if (keptBox.shown) keptBox.close()
            momentBox.dismiss()
            win.capturing = false
            while (Notices.list.count) Notices.dismiss(Notices.list.get(0).key)
        }
        function ready() {
            const t = Date.now()
            const waitFor = Number(stage._after || 0)
            if (!SolBackend.shotReady) return t - since >= (step === "page" ? Math.min(1200, SolBackend.shotAfter) : SolBackend.shotAfter)
            const busy = Theme.settling > 0 || Sol.waiting > 0 || frame.sourceComponent === waiting
                || (momentBox.showing && !momentBox.calm && momentBox.progress < 0.6) || t - since < waitFor
            if (busy) { calmSince = t; return false }
            if (t - calmSince < 150) return false
            // Frames that never stop are something that keeps moving: then a while longer than the
            // slowest arrival nothing counts (a rise), or with SOL_SHOT_CALM, when nothing takes time, less.
            return t - lastFrame >= 150 || t - calmSince >= (SolBackend.shotCalm ? 300 : 1000)
        }
        function advance() {
            if (Date.now() - since >= SolBackend.shotAfter) {
                console.warn("SOL_SHOT: " + list[at].png + " wasn't ready after " + SolBackend.shotAfter + " ms; taken as it was")
                return grab()
            }
            if (!ready()) return
            if (step === "page") {
                step = "scrolled"
                const p = win.shell ? win.shell.page as Design.Screen : null
                if (p && (stage._scroll || scrolledPage === p)) {
                    const max = Math.max(0, p.flickable.contentHeight - p.flickable.height)
                    p.contentY = stage._scroll === "end" ? max : Math.min(max, Number(stage._scroll || 0))
                    scrolledPage = stage._scroll ? p : null
                    calmSince = Date.now()
                    return
                }
            }
            if (step === "scrolled") {
                step = "staged"
                if (win.staging(stage)) { calmSince = Date.now(); return }
            }
            if (step === "staged") grab()
        }
        function grab() {
            step = "taking"
            tick.stop()
            const png = list[at].png
            win.contentItem.grabToImage(result => {
                result.saveToFile(png)
                const cap = captureLoader.item as Window
                if (win.capturing && cap) cap.contentItem.grabToImage(r => { r.saveToFile(png.replace(/\.png$/, "") + "-capture.png"); shots.next() })
                else next()
            })
        }
        function next() {
            if (at + 1 < list.length) { take(at + 1); return }
            at = list.length
            if (SolBackend.drive === "") win.quit()
        }
    }
    Timer { id: tick; interval: 30; repeat: true; onTriggered: shots.advance() }
    Connections { target: win; enabled: shots.active; function onFrameSwapped() { shots.lastFrame = Date.now() } }

    /** Stages what a picture's `_` keys ask for over its page; true when it staged something. */
    function staging(stage) {
        let any = false
        const did = () => { any = true }
        if (stage._notice === "button") { did(); Notices.show({ world: win.world, title: "Changed on another device too", body: "Both copies are kept; you choose which stays.", action: "See both", run: () => { } }) }
        else if (stage._notice) { did(); Notices.show({ world: win.world, title: "Saved", body: "A notice, on glass, over the page." }) }
        if (stage._ask) { did(); win.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove") }
        if (stage._notify) { did(); Sol.call("notify", { title: "A notification", body: "From " + win.w.name + ", on the desktop.", action: ["hello", "Say hello"] }).catch(why => console.warn("notify failed", why)) }
        if (stage._palette) { did(); paletteBox.show(stage._palette === "1" ? "" : stage._palette) }
        if (stage._kept) { did(); keptBox.open([
            { seq: 1, why: "conflict", kind: "put", collection: "habits", id: "walk", data: { name: "Walk outside, 30 min" }, theirs: { version: 9, deleted: false, data: { name: "Walk outside" } } },
            { seq: 2, why: "rejected", kind: "put", collection: "entries", id: "2026-10-10", data: { text: "A very long diary entry" }, message: "a document is at most 1 MiB" },
            { seq: 3, why: "earlier", kind: "event", data: { summary: "Did “Read”, 4 days in a row" } }]) }
        if (stage._capture) { did(); win.stagedCapture = stage._capture === "1" ? "" : stage._capture; win.capturing = true }
        if (stage._tour) { did(); tourBox.show(); tourBox.at = Math.max(0, Math.min(win.tour.length - 1, Number(stage._tour) - 1)) }
        if (stage._moment) { did(); win.stageMoment(stage._moment) }
        return any
    }

    Loader {
        id: frame
        anchors.fill: parent
        // The Shell's keys work from the start, not only after the first click.
        focus: true
        sourceComponent: win.problem ? problemView : !Sol.status ? waiting : Sol.paired || Sol.preview ? shellView : connectView
        // A new frame (the Shell after pairing) comes up out of the dark.
        onLoaded: {
            opacity = 0; frameIn.restart()
            if (sourceComponent !== waiting) shots.begin()
        }
        Settling { when: frameIn.running }
        NumberAnimation { id: frameIn; target: frame; property: "opacity"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }
    // Notices drop in at the top of the pages: over the frame, not in it,
    // so their glass blurs the pages and not themselves.
    // A view, not a column, so a notice that goes fades out and the rest
    // close up after it instead of jumping.
    ListView {
        id: noticeStack
        readonly property Item area: win.shell ? win.shell.pageArea : null
        x: area ? area.x + (area.width - width) / 2 : (win.width - width) / 2
        y: Theme.s3
        width: Math.min(440, (area ? area.width : win.width) - 32)
        height: contentHeight
        spacing: Theme.s2
        z: 50
        interactive: false
        model: Notices.list
        delegate: Notice { width: noticeStack.width }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease }
                NumberAnimation { property: "scale"; to: 0.97; duration: Theme.fade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease }
            }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }
    Tour { id: tourBox; world: win.world; cards: win.tour; go: path => win.shell && win.shell.go(path); onClosed: if (!Sol.preview) tourPrefs.toured = true }
    Moment { id: momentBox }
    ContextMenu { id: contextMenu }
    KeptAside { id: keptBox }
    Ask { id: askBox }
    CommandPalette { id: paletteBox; sections: win.sections; commands: win.allCommands; find: win.find; go: path => win.shell && win.shell.go(path); onClosed: if (win.shell) win.shell.forceActiveFocus() }

    Component {
        id: waiting
        Item { Waiting { anchors.centerIn: parent } }
    }
    Component {
        id: connectView
        Connect { world: win.world }
    }
    // This device's copy didn't open: start again from Sol's (the old file
    // stays), or quit and leave everything as it is.
    Component {
        id: problemView
        Item {
            Rectangle { anchors.fill: parent; color: Theme.space }
            Grain { }
            Card {
                anchors.centerIn: parent
                width: Math.min(460, parent.width - 32)
                radius: Theme.radiusL
                title: win.problem && win.problem.problem === "newer" ? "Written by a newer " + win.w.name
                    : win.problem && win.problem.problem === "damaged" ? "This device’s copy is damaged" : "This device’s copy won’t open"
                gap: Theme.s4
                Words { width: parent.width
                    text: !win.problem ? "" : win.problem.problem === "newer"
                        ? "A newer version of " + win.w.name + " ran here and changed its copy of your data in a way this version can’t read. Your data is safe in Sol."
                        : win.problem.problem === "damaged"
                        ? win.w.name + "’s copy of your data on this device can’t be read any more. Your data is safe in Sol."
                        : win.w.name + " couldn’t open its copy of your data on this device." }
                Words { width: parent.width; small: true; quiet: true
                    text: !win.problem ? "" : win.problem.problem === "other"
                        ? win.problem.detail
                        : "Start fresh sets this copy aside (it stays in " + win.problem.path.replace(/\/[^/]*$/, "") + ") and fetches everything from Sol again; changes not yet sent stay in the old copy. Or quit, and install the newer version again." }
                Row { spacing: Theme.s2
                    Button { visible: !!win.problem && win.problem.problem !== "other"; variant: "primary"; text: "Start fresh"
                        onClicked: Sol.call("start_fresh").catch(why => Sol.fail("Not started fresh", why)) }
                    Button { variant: "quiet"; text: "Quit"; onClicked: win.quit() } }
            }
        }
    }
    Component {
        id: shellView
        Shell {
            id: theShell
            world: win.world
            sections: win.sections
            pages: win.pages
            home: win.home
            search: win.search
            shortcuts: win.shortcuts
            status: LinkStatus { width: parent.width; compact: theShell.rail; online: Sol.online; unsent: Sol.unsent; busy: win.busy; warn: win.warn }
            footer: Loader { width: parent.width; sourceComponent: win.footer }
            // The doors are the world's: another world (the gallery's, a picture's `_world`) has its own.
            onWorldChanged: Sol.doors(win.world).then(d => theShell.doors = d)
            Component.onCompleted: {
                Sol.doors(win.world).then(d => theShell.doors = d)
                // A page asked for before the window was up.
                if (SolBackend.openPath !== "") win.goTo(SolBackend.openPath, theShell)
            }
        }
    }
}

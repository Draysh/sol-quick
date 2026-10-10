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
            sections: [{ path: "/", label: "Log", hint: "What happened, newest first" }, { path: "/settings", label: "Settings", hint: "Sol, the world’s settings and updates" }]
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
    /** The command palette's own entries: `{ label, hint, keys, run }`. */
    property var commands: []
    /** What the palette finds as you type: `function(query) → Promise<[{ label, hint, run }]>`. */
    property var find: null
    readonly property alias commandPalette: paletteBox
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
        source: active ? "file://" + SolBackend.drive : ""
        onLoaded: item.win = win
        onStatusChanged: if (status === Loader.Error) console.warn("SOL_DRIVE: the script didn't load:", SolBackend.drive)
    }

    // A picture of the window for review: SOL_SHOT=<file.png> [SOL_SHOT_AFTER=<ms>],
    // counted from when the window shows what it is for (the Shell, Connect),
    // not from when it opened, so a first run that fills its sample data
    // shoots the same page. Beside a SOL_DRIVE script it doesn't quit: the
    // script ends the run (one that quits sooner leaves no picture).
    Timer {
        id: shot
        interval: SolBackend.shotAfter
        onTriggered: win.contentItem.grabToImage(result => {
            result.saveToFile(SolBackend.shot)
            if (SolBackend.drive === "") win.quit()
        })
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
            if (SolBackend.shot !== "" && sourceComponent !== waiting && !shot.running) shot.start()
        }
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
    ContextMenu { id: contextMenu }
    KeptAside { id: keptBox }
    Ask { id: askBox }
    CommandPalette { id: paletteBox; sections: win.sections; commands: win.commands; find: win.find; go: path => win.shell && win.shell.go(path); onClosed: if (win.shell) win.shell.forceActiveFocus() }

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
            // `_scroll=N` in the shot path: scrolls the page once its data is there.
            property real shotScroll: 0
            Timer { id: scrollLater; interval: 1800; onTriggered: { const p = theShell.page as Design.Screen; if (p) p.contentY = theShell.shotScroll } }
            Component.onCompleted: {
                Sol.doors(win.world).then(d => theShell.doors = d)
                // A page asked for before the window was up.
                if (SolBackend.openPath !== "") win.goTo(SolBackend.openPath, theShell)
                if (SolBackend.shotPath === "") return
                // `/title?key=x` opens the page with its params; `_`-keys stage the picture.
                const stage = win.goTo(SolBackend.shotPath, theShell)
                if (stage._notice === "button") Notices.show({ world: win.world, title: "Changed on another device too", body: "Both copies are kept; you choose which stays.", action: "See both", run: () => { } })
                else if (stage._notice) Notices.show({ world: win.world, title: "Saved", body: "A notice, on glass, over the page." })
                if (stage._ask) win.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove")
                if (stage._notify) Sol.call("notify", { title: "A notification", body: "From " + win.w.name + ", on the desktop.", action: ["hello", "Say hello"] }).catch(why => console.warn("notify failed", why))
                if (stage._palette) paletteBox.show()
                if (stage._kept) keptBox.open([
                    { seq: 1, why: "conflict", kind: "put", collection: "habits", id: "walk", data: { name: "Walk outside, 30 min" }, theirs: { version: 9, deleted: false, data: { name: "Walk outside" } } },
                    { seq: 2, why: "rejected", kind: "put", collection: "entries", id: "2026-10-10", data: { text: "A very long diary entry" }, message: "a document is at most 1 MiB" },
                    { seq: 3, why: "earlier", kind: "event", data: { summary: "Did “Read”, 4 days in a row" } }])
                if (stage._scroll) { theShell.shotScroll = Number(stage._scroll); scrollLater.restart() }
            }
        }
    }
}

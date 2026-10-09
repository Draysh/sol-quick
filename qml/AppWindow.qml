pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Sol.Design

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
    readonly property Item shell: frame.item && frame.item.hasOwnProperty("sections") ? frame.item : null
    /** One right-click menu and one dialog for the whole app. */
    readonly property alias menu: contextMenu
    readonly property alias ask: askBox
    /** What glass panels (menus, notices, hints) blur: the frame the pages live in. */
    readonly property Item backdrop: frame
    /** The command palette's own entries: `{ label, hint, keys, run }`. */
    property var commands: []
    /** What the palette finds as you type: `function(query) → Promise<[{ label, hint, run }]>`. */
    property var find: null
    readonly property alias commandPalette: paletteBox

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

    // Awake: visible and in front. Everything that breathes, drifts or polls stops otherwise.
    readonly property bool awake: visible && active
    Binding { target: Theme; property: "alive"; value: win.awake }

    Connections {
        target: SolBackend
        function onActivate() { win.show(); win.raise(); win.requestActivate() }
        function onPlanetGone() { if (!win.visible) win.quit() }
        function onQuitRequested() { win.quit() }
    }

    // Ctrl+K anywhere, inside a field too.
    Shortcut { sequence: "Ctrl+K"; enabled: !!win.shell; onActivated: paletteBox.show() }

    // SOL_FPS=1: how many frames the window paints a second, in the journal.
    FrameAnimation {
        id: frames
        running: SolBackend.fps && Theme.alive
        property int n: 0
        property real since: 0
        onTriggered: { n++; if (elapsedTime - since >= 1) { console.info("fps", Math.round(n / (elapsedTime - since))); n = 0; since = elapsedTime } }
    }

    // SOL_DRIVE=<file.qml>: a script from outside the app that drives the window
    // through real input events, to check it end to end. Handed the window.
    Loader {
        active: SolBackend.drive !== ""
        source: active ? "file://" + SolBackend.drive : ""
        onLoaded: item.win = win
    }

    // A picture of the window for review: SOL_SHOT=<file.png> [SOL_SHOT_AFTER=<ms>].
    Timer {
        interval: SolBackend.shotAfter
        running: SolBackend.shot !== ""
        onTriggered: win.contentItem.grabToImage(result => { result.saveToFile(SolBackend.shot); win.quit() })
    }

    Loader {
        id: frame
        anchors.fill: parent
        // The Shell's keys work from the start, not only after the first click.
        focus: true
        sourceComponent: !Sol.status ? waiting : Sol.paired || Sol.preview ? shellView : connectView
        // A new frame (the Shell after pairing) comes up out of the dark.
        onLoaded: { opacity = 0; frameIn.restart() }
        NumberAnimation { id: frameIn; target: frame; property: "opacity"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }
    // Notices drop in at the top of the pages: over the frame, not in it,
    // so their glass blurs the pages and not themselves.
    Column {
        id: noticeStack
        readonly property Item area: win.shell ? win.shell.pageArea : null
        x: area ? area.x + (area.width - width) / 2 : (win.width - width) / 2
        y: Theme.s3
        width: Math.min(440, (area ? area.width : win.width) - 32)
        spacing: Theme.s2
        z: 50
        Repeater { model: Notices.list; delegate: Notice { width: noticeStack.width } }
    }
    ContextMenu { id: contextMenu }
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
            status: LinkStatus { width: parent.width; online: Sol.online; unsent: Sol.unsent; busy: win.busy; warn: win.warn }
            footer: Loader { width: parent.width; sourceComponent: win.footer }
            commandPalette: paletteBox
            // `_scroll=N` in the shot path: scrolls the page once its data is there.
            property real shotScroll: 0
            Timer { id: scrollLater; interval: 1800; onTriggered: { const p = theShell.page; if (p && p.hasOwnProperty("contentY")) p.contentY = theShell.shotScroll } }
            Component.onCompleted: {
                Sol.doors(win.world).then(d => theShell.doors = d)
                if (SolBackend.shotPath === "") return
                // `/title?key=x` opens the page with its params; `_`-keys stage the picture.
                const [path, query] = SolBackend.shotPath.split("?")
                const params = {}, stage = {}
                for (const pair of (query || "").split("&").filter(Boolean)) {
                    const [k, v] = pair.split("=").map(decodeURIComponent)
                    if (k.startsWith("_")) stage[k] = v || "1"; else params[k] = v || ""
                }
                theShell.go(path, params)
                if (stage._notice) Notices.show({ world: win.world, title: "Saved", body: "A notice, on glass, over the page." })
                if (stage._ask) win.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove")
                if (stage._notify) Sol.call("notify", { title: "A notification", body: "From " + win.w.name + ", on the desktop.", action: ["hello", "Say hello"] }).catch(why => console.warn("notify failed", why))
                if (stage._palette) paletteBox.show()
                if (stage._scroll) { theShell.shotScroll = Number(stage._scroll); scrollLater.restart() }
            }
        }
    }
}

import QtQuick
import QtQuick.Window
import Sol.Design

/*
    A world app's window, the same for every world: the Connect screen
    until the app is paired, then the Shell with the app's sections and
    pages. Remembers its size, comes up when another copy is started, and
    stays out of sight when a moon runs with its planet.

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

    title: w.name
    color: Theme.space
    minimumWidth: 360
    minimumHeight: 560
    width: 1180
    height: 800
    visible: !Sol.background

    Component.onCompleted: {
        try {
            const s = JSON.parse(SolBackend.windowState() || "{}")
            if (s.width >= minimumWidth && s.height >= minimumHeight) { width = s.width; height = s.height }
            if (s.maximized) showMaximized()
        } catch (e) { }
    }
    function remember() {
        SolBackend.saveWindow(JSON.stringify({ width: width, height: height, maximized: visibility === Window.Maximized }))
    }
    // Closing keeps the app in the tray; Quit is in the tray's menu.
    onClosing: close => { remember(); if (SolBackend.tray) { close.accepted = false; win.hide() } }
    // Awake: visible and in front. Everything that breathes or drifts stops otherwise.
    readonly property bool awake: visible && active
    onAwakeChanged: Theme.alive = awake
    Component.onDestruction: Theme.alive = false
    onWidthChanged: keep.restart()
    onHeightChanged: keep.restart()
    Timer { id: keep; interval: 800; onTriggered: win.remember() }

    Connections {
        target: SolBackend
        function onActivate() { win.show(); win.raise(); win.requestActivate() }
        function onPlanetGone() { if (!win.visible) Qt.quit() }
    }

    // SOL_FPS=1: how many frames the window paints a second, in the journal.
    FrameAnimation {
        id: frames
        running: SolBackend.fps && Theme.alive
        property int n: 0
        property real since: 0
        onTriggered: { n++; if (elapsedTime - since >= 1) { console.info("fps", Math.round(n / (elapsedTime - since))); n = 0; since = elapsedTime } }
    }

    // A picture of the window for review: SOL_SHOT=<file.png> [SOL_SHOT_AFTER=<ms>].
    Timer {
        interval: SolBackend.shotAfter
        running: SolBackend.shot !== ""
        onTriggered: win.contentItem.grabToImage(result => { result.saveToFile(SolBackend.shot); Qt.quit() })
    }

    Loader {
        id: frame
        anchors.fill: parent
        sourceComponent: !Sol.status ? waiting : Sol.paired || Sol.preview ? shellView : connectView
        // A new frame (the Shell after pairing) comes up out of the dark.
        onLoaded: { opacity = 0; frameIn.restart() }
        NumberAnimation { id: frameIn; target: frame; property: "opacity"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }
    ContextMenu { id: contextMenu }
    Ask { id: askBox }
    Palette { id: paletteBox; sections: win.sections; commands: win.commands; find: win.find; go: path => win.shell && win.shell.go(path) }

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
            Timer { id: scrollLater; interval: 1800; onTriggered: { const p = theShell.page; if (p && p.hasOwnProperty("contentY")) p.contentY = Number(SolBackend.shotPath.split("_scroll=")[1]) } }
            Component.onCompleted: {
                Sol.doors(win.world).then(d => theShell.doors = d)
                if (SolBackend.shotPath !== "") {
                    // `/title?key=x` opens the page with its params, for a screenshot.
                    const [path, query] = SolBackend.shotPath.split("?")
                    const params = {}
                    for (const pair of (query || "").split("&").filter(Boolean)) { const [k, v] = pair.split("="); params[decodeURIComponent(k)] = decodeURIComponent(v || "") }
                    theShell.go(path, params)
                    // `_notice=1` and `_ask=1` put a notice and the dialog in the picture too.
                    if (params._notice) Notices.show({ world: win.world, title: "Saved", body: "A notice, on glass, over the page." })
                    if (params._ask) win.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove")
                    if (params._notify) Sol.call("notify", { title: "A notification", body: "From " + win.w.name + ", on the desktop.", action: ["hello", "Say hello"] }).then(id => console.info("notified", id)).catch(why => console.warn("notify failed", why))
                    if (params._palette) paletteBox.show()
                    if (params._scroll) scrollLater.restart()
                }
            }
        }
    }
}

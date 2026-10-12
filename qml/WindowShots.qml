pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    Pictures of a window for review, and what they stage: SOL_SHOT=<file.png>
    (one, of SOL_SHOT_PATH), or SOL_SHOTS (many, one after another in this
    run: `<file.png>=<path?keys>` each, a line or `;` apart). Each opens its
    page, scrolls it (`_scroll=N`, `end`), stages what its keys ask for and
    is taken once the page is ready: nothing arriving or loading
    (Theme.settling), every command answered (Sol.waiting), then 150 ms
    without a new frame (or a second, when something keeps moving: a
    breathing button, a turning world). SOL_SHOT_AFTER (8 s unless given) is
    the most a picture waits; `_after=<ms>` makes one wait at least that
    long, for what the rule can't see. The clock starts when the window
    shows what it is for (the Shell, Connect), not when it opened. Beside a
    SOL_DRIVE script it doesn't quit: the script ends the run.

    Also the window's measures: SOL_FPS (the frames painted each second, in
    the journal) and SOL_TRACE (the first frame, each page loaded and
    settled, and the frames drawn in two seconds of nothing happening after
    the last picture). `AppWindow` keeps one; its `staging` and
    `stageMoment` are these.

        WindowShots { id: shots; host: win; moons: carried; frameLoader: frame; waitView: waiting; capture: captureLoader; starView: starScene }
*/
Item {
    id: shots

    /** The window, its carried moons, the Loader its frame is in and the Component it waits with, quick capture's Loader, and the star's scene. */
    property Design.AppWindow host
    property Design.CarriedMoons moons
    property Loader frameLoader
    property Component waitView
    property Loader capture
    property Component starView

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
    /** `SOL_TRACE`: this picture's page has had every reply it asked for. */
    property bool loaded: false
    /** The frame shows what the window is for (the Shell, Connect, a problem), not the wait. */
    readonly property bool framed: !!frameLoader && frameLoader.sourceComponent !== waitView

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
        if (framed && frameLoader.item) Qt.callLater(begin)
    }
    function begin() { if (list.length && at < 0) take(0) }
    function take(i) {
        at = i
        const e = list[i]
        if (i > 0) clear()
        SolBackend.shot = e.png
        SolBackend.shotPath = e.path
        stage = host.goTo(e.path)
        step = "page"
        loaded = false
        // What was calm stays calm: a page that is already there and settled (the same one,
        // scrolled elsewhere next) is taken at once; one that changes counts itself busy.
        since = Date.now()
        if (i === 0) calmSince = since
        tick.start()
    }
    // What the picture before staged goes, so the next starts from the page alone.
    function clear() {
        host.commandPalette.close(); host.ask.finish(false); host.menu.close(); host.tourSheet.close()
        if (host.keptAside.shown) host.keptAside.close()
        host.moment.dismiss()
        host.capturing = false
        host.stagedComet = false
        host.stagedSky = ""
        while (Notices.list.count) Notices.dismiss(Notices.list.get(0).key)
    }
    function ready() {
        const t = Date.now()
        if (SolBackend.traceOn && step === "page" && !loaded && Sol.waiting === 0 && framed) {
            loaded = true
            SolBackend.trace("page-loaded " + list[at].path + " " + (t - since) + "ms")
        }
        const waitFor = Number(stage._after || 0)
        if (!SolBackend.shotReady) return t - since >= (step === "page" ? Math.min(1200, SolBackend.shotAfter) : SolBackend.shotAfter)
        const moment = host.moment
        const busy = Theme.settling > 0 || Sol.waiting > 0 || !framed
            || (moment.showing && !moment.calm && moment.progress < 0.6) || t - since < waitFor
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
            if (SolBackend.traceOn) SolBackend.trace("page-settled " + list[at].path + " " + (Date.now() - since) + "ms")
            step = "scrolled"
            const p = host.shell ? host.shell.page as Design.Screen : null
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
            if (staging(stage)) { calmSince = Date.now(); return }
        }
        if (step === "staged") grab()
    }
    function grab() {
        step = "taking"
        tick.stop()
        const png = list[at].png
        host.contentItem.grabToImage(result => {
            result.saveToFile(png)
            const cap = shots.capture ? shots.capture.item as Window : null
            if (host.capturing && cap) cap.contentItem.grabToImage(r => { r.saveToFile(png.replace(/\.png$/, "") + "-capture.png"); shots.next() })
            else next()
        })
    }
    function next() {
        if (at + 1 < list.length) { take(at + 1); return }
        at = list.length
        // `SOL_TRACE`: then, once a button's breaths have had their time, two seconds of nothing
        // happening, counting the frames drawn (0 is right).
        if (SolBackend.traceOn) { rest.start(); return }
        if (SolBackend.drive === "") host.quit()
    }

    /** Stages what a picture's `_` keys ask for over its page; true when it staged something. */
    function staging(stage) {
        let any = false
        const did = () => { any = true }
        if (stage._notice === "button") { did(); Notices.show({ world: host.world, title: "Changed on another device too", body: "Both copies are kept; you choose which stays.", action: "See both", run: () => { } }) }
        else if (stage._notice) { did(); Notices.show({ world: host.world, title: "Saved", body: "A notice, on glass, over the page." }) }
        if (stage._ask) { did(); host.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove") }
        if (stage._notify) { did(); Sol.call("notify", { title: "A notification", body: "From " + host.w.name + ", on the desktop.", action: ["hello", "Say hello"] }).catch(why => console.warn("notify failed", why)) }
        if (stage._palette) { did(); host.commandPalette.show(stage._palette === "1" ? "" : stage._palette) }
        if (stage._kept) { did(); host.keptAside.open([
            { seq: 1, why: "conflict", kind: "put", collection: "habits", id: "walk", data: { name: "Walk outside, 30 min" }, theirs: { version: 9, deleted: false, data: { name: "Walk outside" } } },
            { seq: 2, why: "rejected", kind: "put", collection: "entries", id: "2026-10-10", data: { text: "A very long diary entry" }, message: "a document is at most 1 MiB" },
            { seq: 3, why: "earlier", kind: "event", data: { summary: "Did “Read”, 4 days in a row" } }]) }
        if (stage._capture) { did(); host.stagedCapture = stage._capture === "1" ? "" : stage._capture; host.capturing = true }
        if (stage._tour) { did(); host.tourSheet.show(); host.tourSheet.at = Math.max(0, Math.min(host.tour.length - 1, Number(stage._tour) - 1)) }
        if (stage._moment) { did(); stageMoment(stage._moment) }
        if (stage._comet) { did(); host.stagedComet = true }
        if (stage._sky) { did(); host.stagedSky = stage._sky }
        return any
    }
    /** Plays one of the window's moments (or a carried moon's, or the kit's `star`) by `<name>[:<arg>]`, without its occasion. */
    function stageMoment(spec) {
        const at = spec.indexOf(":"), name = at < 0 ? spec : spec.slice(0, at)
        const carried = shots.moons ? shots.moons.moment(name) : null
        // The kit's own: a star lighting in the Sky.
        const m = host.moments[name] || carried || (name === "star" ? { scene: starView, chime: true, facts: { title: "100 nights", story: "A hundred nights logged, one at a time.", constellation: "100 Nights" } } : null)
        if (!m) { if (Object.keys(host.moments).length) console.warn("no moment called " + name + " to stage"); return }
        Promise.resolve(typeof m === "function" ? m(at < 0 ? "" : spec.slice(at + 1)) : m)
            .then(o => { if (o) host.moment.play(Object.assign({}, o, { occasion: "" })) })
            .catch(why => console.warn("the staged moment failed", why))
    }

    Timer { id: tick; interval: 30; repeat: true; onTriggered: shots.advance() }
    Connections { target: shots.host; enabled: shots.active; function onFrameSwapped() { shots.lastFrame = Date.now() } }
    // Three breaths of 5.2 s (Button), with a little to spare.
    Timer { id: rest; interval: 16500; onTriggered: { idle.frames = 0; idle.start() } }
    Timer {
        id: idle
        property int frames: 0
        interval: 2000
        onTriggered: { SolBackend.trace("idle-frames " + idle.frames + " in 2000ms"); if (SolBackend.drive === "") shots.host.quit() }
    }
    Connections { target: shots.host; enabled: idle.running; function onFrameSwapped() { idle.frames++ } }
    // `SOL_TRACE`: when the window first shows what it is for.
    property bool traced: false
    Connections {
        target: shots.host
        enabled: SolBackend.traceOn && !shots.traced && !!shots.frameLoader && shots.frameLoader.status === Loader.Ready && shots.framed
        function onFrameSwapped() { shots.traced = true; SolBackend.trace("first-frame") }
    }

    // SOL_FPS=1: how many frames the window really paints a second, in the journal: 0 while
    // nothing moves (a FrameAnimation would count ticks, and keep ticking, instead).
    QtObject { id: frames; property int n: 0 }
    Connections { target: shots.host; enabled: SolBackend.fps; function onFrameSwapped() { frames.n++ } }
    Timer { interval: 1000; repeat: true; running: SolBackend.fps; onTriggered: { console.info("fps", frames.n); frames.n = 0 } }
}

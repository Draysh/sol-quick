pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    A moment: a scene over the whole window for something that earns one
    (a series finished, every habit done today, a year ago tonight). It
    fades in over the page, plays once for a few seconds and goes; any key
    or click sends it away sooner. An occasion plays at most once for the
    person, on any device: the kit's `moment` command keeps it in the
    world's own `moments` collection (list it in `sol-world.json`). It
    plays only while the window is in front; one that comes while it isn't
    waits for it. It goes in rhythm: the frame and its bars slam in, the
    title slams in with the flavour's sting (`slamAt`), its figures count
    up, a hold, and the subtitle is said on the beat (MomentCaption). With
    less motion (`Theme.calm`) the scene shows its last frame, still, for a
    shorter while. The window has one: `win.moment`.

        win.moment.play({ occasion: "saturn.finished." + key, scene: finished, facts: { … }, chime: true })

    `scene` is a Component whose root has `property var moment`: it reads
    `moment.progress` (0 → 1 over the moment, 1 at once with less motion),
    `moment.elapsed` (its milliseconds) and `moment.slamAt`,
    `moment.facts` (what `play` was given) and `moment.calm`.

    A moment is a scene from a film: the page's still (or `ground` in the spec) fills the window, darkened
    and pushed slowly in, black bars close in at the top and the bottom,
    and a HUD line runs along the top (the world, `hud` from the spec);
    MomentCaption sets its words as the film's title and subtitles.
*/
FocusScope {
    id: root

    /** The scene playing, or null. */
    property var current: null
    readonly property bool showing: current !== null
    /** What the scene shows: the `facts` it was played with. */
    readonly property var facts: current ? current.facts || ({}) : ({})
    readonly property bool calm: Theme.calm
    /** 0 → 1 while the moment plays. */
    property real progress: 0
    /** Milliseconds into the scene (all of it at once with less motion). */
    readonly property real elapsed: calm ? 1e9 : progress * length
    /** When the scene's title slams in (MomentCaption), its sting with it: once the frame is up and a beat after. */
    readonly property real slamAt: Theme.fade + Theme.hit * 3
    /** How long the scene plays, in ms: `length` in the spec, `Theme.scene` unless given; half of it with less motion. */
    readonly property int length: !current ? 0 : calm ? Theme.scene / 2 : (current.length || Theme.scene)
    /** The moments waiting for the window to come to the front. */
    property var waiting: []
    property Item before: null
    /** The still behind the scene: the spec's `ground`, else the page's. */
    property string still: ""
    /** The letterbox, 0 (open) → 1 (closed in to the scene): slammed in over the frame's first beats. */
    readonly property real bars: calm ? 1 : 1 - Math.pow(1 - Math.min(1, elapsed / Math.max(1, Theme.hit * 3)), 3)
    // The sting, as the title slams in.
    property bool stung: false
    onElapsedChanged: if (!stung && current && elapsed >= slamAt) { stung = true; if (current.chime) Sounds.moment() }

    anchors.fill: parent
    // Over everything in the window while it plays: a hint the pointer left up, an open menu
    // or the palette (the notices step aside for it themselves).
    z: 1100
    visible: opacity > 0
    opacity: 0
    enabled: showing

    /**
        Plays a moment once for its `occasion` (or every time, without one).
        `{ occasion, scene, facts, length, chime, world, hud, ground }`
        (`world`: a moon the app carries, whose `moments` keep the
        occasion; `hud` and `ground`: the HUD line and the still). Resolves true
        when it will play, false when the occasion has been shown before.
    */
    function play(spec) {
        if (!spec.occasion) { waiting = waiting.concat([spec]); pump(); return Promise.resolve(true) }
        return Sol.callIn(spec.world || "", "moment", { occasion: spec.occasion }).then(fresh => {
            if (fresh) { waiting = waiting.concat([spec]); pump() }
            return fresh
        })
    }
    /** Sends the moment away now. */
    function dismiss() {
        if (!showing || leave.running) return
        run.stop(); hold.stop(); arrive.stop()
        leave.start()
    }
    function pump() {
        if (showing || !waiting.length || !Theme.alive) return
        const next = waiting[0]
        waiting = waiting.slice(1)
        begin(next)
    }
    function begin(spec) {
        before = root.Window.activeFocusItem
        current = spec
        const w = root.Window.window as AppWindow
        still = spec.ground || (w && w.shell ? (w.shell as Shell).groundSource : "")
        progress = calm ? 1 : 0
        stung = calm
        scene.sourceComponent = spec.scene
        root.forceActiveFocus()
        arrive.start()
        if (!calm) run.start()
        hold.restart()
        if (calm && spec.chime) Sounds.moment()
    }
    Connections { target: Theme; function onAliveChanged() { root.pump() } }

    Keys.onPressed: event => { event.accepted = true; root.dismiss() }

    Settling { when: arrive.running || leave.running }
    // In over a fade, the bars slamming in; out sharply, back to the page.
    NumberAnimation { id: arrive; target: root; property: "opacity"; to: 1; duration: Theme.fade; easing: Theme.easeOut }
    SequentialAnimation {
        id: leave
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.calm ? Theme.fade : Theme.settle; easing: Theme.easeIn }
        ScriptAction { script: {
            scene.sourceComponent = undefined
            root.current = null
            if (root.before) root.before.forceActiveFocus()
            root.before = null
            Qt.callLater(root.pump)
        } }
    }
    // Once through, in step with the moment; it waits while the window is behind another.
    NumberAnimation { id: run; target: root; property: "progress"; from: 0; to: 1; duration: root.length; paused: running && !Theme.alive }
    Timer { id: hold; interval: root.length; running: false; onTriggered: root.dismiss() }

    // The page goes dark under the scene.
    Rectangle { anchors.fill: parent; color: Theme.tint(Theme.veil, 0.96) }
    // The film: the still, darkened, coming slowly closer as the moment plays.
    Item {
        anchors.fill: parent
        visible: root.still !== ""
        clip: true
        Image {
            anchors.fill: parent
            source: root.still
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            scale: 1.02 + 0.05 * root.progress
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.tint(Theme.hud.ground, 0.62) }
                GradientStop { position: 0.6; color: Theme.tint(Theme.hud.ground, 0.48) }
                GradientStop { position: 1; color: Theme.tint(Theme.hud.ground, 0.78) }
            }
        }
        // A shade down the left, where the title stands.
        Rectangle {
            width: parent.width * 0.6; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(Theme.hud.ground, 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Loader {
        id: scene
        anchors.fill: parent
        onLoaded: if (item && item.hasOwnProperty("moment")) item.moment = root
    }
    // The letterbox, and the HUD line along its top bar.
    readonly property real barHeight: Math.max(36, Math.min(height * 0.15, (height - width / 2.39) / 2))
    Rectangle { width: parent.width; height: root.barHeight * root.bars; color: "#000000" }
    Rectangle { y: parent.height - height; width: parent.width; height: root.barHeight * root.bars; color: "#000000" }
    Row {
        x: Theme.s5
        y: Math.max(Theme.s3, (root.barHeight - height) / 2)
        spacing: Theme.s3
        opacity: Math.max(0, root.bars * 2 - 1)
        readonly property var world: Worlds.get(Theme.worldId)
        // The world's name in Japanese (the title serif, never tracked), then the HUD line in capitals.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.jpOf(Theme.worldId)
            font.family: Theme.titleFace(Theme.textXs + 2); font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 2; font.weight: Theme.titleWeight(Theme.textXs + 2)
            color: Theme.tint(Theme.artBright, 0.72)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: [parent.world ? parent.world.name : "", root.current ? root.current.hud || "" : ""].filter(t => t !== "").join("  ·  ")
            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.tint(Theme.artBright, 0.72)
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: Theme.s5
        y: Math.max(Theme.s3, (root.barHeight - height) / 2)
        text: "Press any key"
        font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold
        font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
        color: Theme.tint(Theme.artBright, 0.72)
        opacity: root.progress > 0.25 || root.calm ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.rise } }
    }
    MouseArea { anchors.fill: parent; enabled: root.showing; onClicked: root.dismiss(); onWheel: wheel => root.dismiss() }
}

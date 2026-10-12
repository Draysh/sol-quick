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
    waits for it. With less motion (`Theme.calm`) the scene shows its last
    frame, still, for a shorter while. The window has one: `win.moment`.

        win.moment.play({ occasion: "saturn.finished." + key, scene: finished, facts: { … }, chime: true })

    `scene` is a Component whose root has `property var moment`: it reads
    `moment.progress` (0 → 1 over the moment, 1 at once with less motion),
    `moment.facts` (what `play` was given) and `moment.calm`.
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
    /** How long the scene plays, in ms: `length` in the spec, 5200 unless given; 2600 with less motion. */
    readonly property int length: !current ? 0 : calm ? 2600 : (current.length || 5200)
    /** The moments waiting for the window to come to the front. */
    property var waiting: []
    property Item before: null

    anchors.fill: parent
    z: 200
    visible: opacity > 0
    opacity: 0
    enabled: showing

    /**
        Plays a moment once for its `occasion` (or every time, without one).
        `{ occasion, scene, facts, length, chime, world }` (`world`: a moon
        the app carries, whose `moments` keep the occasion). Resolves true
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
        progress = calm ? 1 : 0
        scene.sourceComponent = spec.scene
        root.forceActiveFocus()
        arrive.start()
        if (!calm) run.start()
        hold.restart()
        if (spec.chime) Sounds.chime()
    }
    Connections { target: Theme; function onAliveChanged() { root.pump() } }

    Keys.onPressed: event => { event.accepted = true; root.dismiss() }

    Settling { when: arrive.running || leave.running }
    NumberAnimation { id: arrive; target: root; property: "opacity"; to: 1; duration: root.calm ? Theme.fade : 700; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: leave
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.calm ? Theme.fade : 800; easing.type: Easing.InOutCubic }
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
    Loader {
        id: scene
        anchors.fill: parent
        onLoaded: if (item && item.hasOwnProperty("moment")) item.moment = root
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s4
        text: "Any key to go on"
        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
        font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase
        color: Theme.textFaint
        opacity: root.progress > 0.25 || root.calm ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.rise } }
    }
    MouseArea { anchors.fill: parent; enabled: root.showing; onClicked: root.dismiss(); onWheel: wheel => root.dismiss() }
}

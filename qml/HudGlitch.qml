pragma ComponentBehavior: Bound
import QtQuick

/*
    Neptune's glitch in the Yozora look: as a page opens, a scan line runs
    down it and a few bands of the picture tear sideways in red and cyan,
    for a quarter of a second, then nothing. Only with Neptune's flavour
    (`Theme.hud.motif` "neon") and full motion; at rest it draws nothing.
    Screen plays it over every page as the page arrives.

        HudGlitch { anchors.fill: parent; z: 15 }   // then glitch.play()
*/
Item {
    id: root

    /** Whether it plays at all: the look on, Neptune's flavour, full motion. */
    readonly property bool wanted: Theme.yozora && Theme.hud.motif === "neon" && !Theme.calm
    /** A new pattern of tears each time. */
    property int seed: 0

    function play() {
        if (!wanted || width <= 0 || height <= 0) return
        seed = (seed + 1) % 997
        run.restart()
    }

    visible: run.running
    enabled: false

    /** A number from 0 to 1 for `i`, always the same one. */
    function noise(i) { const s = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }

    // The tears: thin bands of the two lights, shifted sideways, each lit for a step or two.
    Repeater {
        model: 5
        delegate: Rectangle {
            id: tear
            required property int index
            property real r: root.noise(root.seed * 7 + index)
            property int step: 0
            x: (root.noise(root.seed * 13 + index) - 0.5) * 24 + (step % 2 ? 6 : -4)
            y: root.height * (0.08 + r * 0.8)
            width: root.width * (0.35 + root.noise(root.seed * 3 + index) * 0.6)
            height: 1 + Math.round(root.noise(root.seed * 5 + index) * 7)
            color: Theme.tint(index % 2 ? Theme.hudSecond : Theme.hudAccent, 0.42)
            visible: (step + index) % 3 !== 0
            Connections { target: ticks; function onTriggered() { tear.step++ } }
        }
    }
    // The scan line: a bright hairline with a soft band of light above it.
    Item {
        id: scan
        width: root.width
        height: 48
        y: -height
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.tint(Theme.hudSecond, 0) }
                GradientStop { position: 1; color: Theme.tint(Theme.hudSecond, 0.16) }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.tint(Theme.hudSecond, 0.75) }
    }
    Timer { id: ticks; interval: 45; repeat: true; running: run.running }
    SequentialAnimation {
        id: run
        NumberAnimation { target: scan; property: "y"; from: -scan.height; to: root.height; duration: 260; easing.type: Easing.InOutQuad }
    }
    Settling { when: run.running }
}

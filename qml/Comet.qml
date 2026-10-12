pragma ComponentBehavior: Bound
import QtQuick

/*
    The comet: on a few days a year (a world's own, the same on every
    device) one crosses the Sheet, slowly, from the upper right down to the
    left. Catch it with a click and it becomes a star in the world's Sky
    (the kit's `catch_comet`, whose `sky.lit` plays the star's moment);
    missed, it crosses again the next time the Sheet is made that day, and
    is gone the day after. It moves only while the window is in front; with
    less motion it rests in the band for a while instead. The Sheet has
    one; `_comet=1` holds one mid-way for a picture.

        Comet { anchors.fill: parent }
*/
Item {
    id: root

    /** The comet's day (`YYYY-MM-DD`) when one crosses, else "". */
    property string day: ""
    readonly property AppWindow win: root.Window.window as AppWindow
    readonly property bool staged: !!win && win.stagedComet
    /** 0 → 1 along its way; held at 0.42 for a picture. */
    property real t: staged ? 0.42 : 0
    property bool caught: false
    readonly property bool due: (day !== "" || staged) && !caught

    Component.onCompleted: Sol.near(root).call("comet").then(d => { if (d) root.day = d }).catch(why => console.warn("the comet couldn’t be asked for", why))

    // Its way: in from beyond the upper right, out past the lower left.
    readonly property real x0: width + 60
    readonly property real y0: height * 0.12
    readonly property real x1: -120
    readonly property real y1: height * 0.78
    readonly property real angle: Math.atan2(y1 - y0, x1 - x0)
    readonly property real hx: Theme.calm && !staged ? width * 0.56 : x0 + (x1 - x0) * t
    readonly property real hy: Theme.calm && !staged ? height * 0.14 : y0 + (y1 - y0) * t
    readonly property color tone: Qt.tint("#e8f4ff", Theme.tint(Theme.world, 0.25))

    visible: due && (crossing.running || staged || rest.running)
    NumberAnimation {
        id: crossing
        target: root; property: "t"; from: 0; to: 1; duration: 14000
        running: root.due && !root.staged && !Theme.calm && Theme.alive && root.width > 0
        onRunningChanged: if (!running && root.t >= 1) root.day = ""
    }
    // With less motion it rests in the band, still, for twenty seconds: above the
    // name, where no world puts its callout.
    Timer { id: rest; interval: 20000; running: root.due && !root.staged && Theme.calm && Theme.alive; onTriggered: root.day = "" }

    Item {
        x: root.hx
        y: root.hy
        rotation: root.angle * 180 / Math.PI + 180
        // The tail, behind it (to the right, before rotation).
        Rectangle {
            x: 0; y: -1.5
            width: Math.min(260, root.width * 0.22); height: 3
            radius: 1.5
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(root.tone, 0.85) }
                GradientStop { position: 0.25; color: Theme.tint(root.tone, 0.32) }
                GradientStop { position: 1; color: Theme.tint(root.tone, 0) }
            }
        }
        Rectangle {
            x: 0; y: -6
            width: Math.min(150, root.width * 0.13); height: 12
            radius: 6
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(root.tone, 0.25) }
                GradientStop { position: 1; color: Theme.tint(root.tone, 0) }
            }
        }
    }
    // The head, and the hand that catches it.
    Rectangle {
        x: root.hx - 14; y: root.hy - 14; width: 28; height: 28; radius: 14
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.tint(root.tone, 0) }
            GradientStop { position: 0.5; color: Theme.tint(root.tone, 0.3) }
            GradientStop { position: 1; color: Theme.tint(root.tone, 0) }
        }
    }
    Rectangle { x: root.hx - 3; y: root.hy - 3; width: 6; height: 6; radius: 3; color: root.tone }
    MouseArea {
        id: hand
        x: root.hx - 26; y: root.hy - 26; width: 52; height: 52
        enabled: root.due
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const day = root.day
            root.caught = true
            crossing.stop()
            if (day === "") return
            Sol.near(root).call("catch_comet", { day: day }).catch(why => Sol.near(root).fail("The comet got away", why))
        }
        Hint { text: "Catch the comet"; when: hand.containsMouse }
    }
}

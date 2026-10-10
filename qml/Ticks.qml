pragma ComponentBehavior: Bound
import QtQuick

/*
    Keyboard focus, the same on every control: two corner ticks lock onto
    their parent, like a reticle finding its target, and let go when the
    keys move on. Put one inside anything that takes the keys; `out` is how
    far past the parent's edge they rest, `radius` the parent's own corner:
    the ticks bend round it, `out` further out, so a rounded control has
    rounded ticks (0 for square ones). A Card's ticks are these too.

        Ticks { on: root.activeFocus; radius: Theme.radiusM }
*/
Item {
    id: ticks

    property bool on: false
    property real out: 6
    /** The corner of what they lock onto. */
    property real radius: Theme.radiusM
    /** Their own curve: the corner `out` further out (concentric with it), or 0 for square ticks. */
    property real round: radius > 0 ? radius + out : 0
    /** How long each tick's hairlines run. */
    property real arm: 10
    property color color: Theme.textBright

    anchors.fill: parent
    // Never in the way of the pointer.
    enabled: false

    Tick { at: "tl" }
    Tick { at: "br" }

    component Tick: Item {
        id: tick
        property string at: "tl"
        readonly property bool tl: at === "tl"
        property real gap: ticks.on ? ticks.out : ticks.out + 4
        readonly property real round: ticks.round
        // A round tick runs a little past its arc.
        width: round > 0 ? Math.max(ticks.arm, round + ticks.arm / 2) : ticks.arm
        height: width
        opacity: ticks.on ? 1 : 0
        visible: opacity > 0
        x: tick.tl ? -tick.gap : ticks.width + tick.gap - width
        y: tick.tl ? -tick.gap : ticks.height + tick.gap - height
        // Only the corner of the outline below shows.
        clip: round > 0
        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
        Behavior on gap { NumberAnimation { duration: Theme.lock; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Rectangle { visible: tick.round <= 0; width: tick.width; height: 1; y: tick.tl ? 0 : tick.height - 1; color: ticks.color }
        Rectangle { visible: tick.round <= 0; width: 1; height: tick.height; x: tick.tl ? 0 : tick.width - 1; color: ticks.color }
        Rectangle {
            visible: tick.round > 0
            width: tick.width * 2 + tick.round; height: width
            x: tick.tl ? 0 : tick.width - width
            y: tick.tl ? 0 : tick.height - height
            radius: tick.round
            color: "transparent"
            border.width: 1
            border.color: ticks.color
        }
    }
}

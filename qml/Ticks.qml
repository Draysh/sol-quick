pragma ComponentBehavior: Bound
import QtQuick

/*
    Keyboard focus, the same on every control: two corner ticks lock onto
    their parent, like a reticle finding its target, and let go when the
    keys move on. Put one inside anything that takes the keys; `out` is how
    far past the parent's edge they rest.

        Ticks { on: root.activeFocus }
*/
Item {
    id: ticks

    property bool on: false
    property real out: 6

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
        width: 10; height: 10
        opacity: ticks.on ? 1 : 0
        visible: opacity > 0
        x: tick.tl ? -tick.gap : ticks.width + tick.gap - width
        y: tick.tl ? -tick.gap : ticks.height + tick.gap - height
        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
        Behavior on gap { NumberAnimation { duration: Theme.lock; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Rectangle { width: tick.width; height: 1; y: tick.tl ? 0 : tick.height - 1; color: Theme.textBright }
        Rectangle { width: 1; height: tick.height; x: tick.tl ? 0 : tick.width - 1; color: Theme.textBright }
    }
}

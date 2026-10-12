pragma ComponentBehavior: Bound
import QtQuick

/*
    How far along, as a row of slanted ticks (skewed −20°) in the Yozora
    look: those done in a light, the rest faint. Ten by default; a part
    done lights the next tick part-way.

        SlantTicks { width: parent.width; value: 7 / 12 }
*/
Item {
    id: root

    /** How far along, 0 to 1. */
    property real value: 0
    property int count: 10
    property color done: Theme.hudAccent
    property color rest: Qt.rgba(1, 1, 1, 0.16)
    property real gap: 4
    /** The lean, in degrees: negative leans the tops forward. */
    property real skew: -20

    implicitWidth: 160
    implicitHeight: 8
    readonly property real tick: (width - gap * (count - 1)) / Math.max(1, count)
    readonly property real shear: Math.tan(skew * Math.PI / 180)

    Repeater {
        model: root.count
        delegate: Item {
            id: one
            required property int index
            /** How much of this tick is done. */
            readonly property real lit: Math.max(0, Math.min(1, root.value * root.count - index))
            x: index * (root.tick + root.gap)
            width: root.tick
            height: root.height
            // Leaning about its middle, so the row keeps its place.
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.shear, 0, -root.shear * root.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            Rectangle { anchors.fill: parent; color: root.rest; antialiasing: true }
            Rectangle { width: parent.width * one.lit; height: parent.height; color: root.done; antialiasing: true }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick

/*
    Thin corner brackets in a light, on a HUD panel's uncut corners: an L
    of `Theme.hudBracket` each way, the panel's own hairline under it.
    Nothing shows while `color` is transparent.

        HudBrackets { anchors.fill: parent; color: Theme.hudAccent; cuts: [0, Theme.hudCut, 0, 0] }
*/
Item {
    id: root

    property color color: "transparent"
    /** The panel's cut corners (top-left, top-right, bottom-right, bottom-left): those get none. */
    property var cuts: [0, 0, 0, 0]
    /** How thick a bracket is drawn. */
    property real weight: 1.5

    visible: color.a > 0
    enabled: false

    Repeater {
        model: 4
        delegate: Item {
            id: corner
            required property int index
            readonly property bool atRight: index === 1 || index === 2
            readonly property bool atBottom: index >= 2
            visible: !(root.cuts[corner.index] > 0)
            x: corner.atRight ? root.width - Theme.hudBracket : 0
            y: corner.atBottom ? root.height - Theme.hudBracket : 0
            width: Theme.hudBracket; height: Theme.hudBracket
            Rectangle { x: 0; y: corner.atBottom ? parent.height - root.weight : 0; width: parent.width; height: root.weight; color: root.color }
            Rectangle { x: corner.atRight ? parent.width - root.weight : 0; y: 0; width: root.weight; height: parent.height; color: root.color }
        }
    }
}

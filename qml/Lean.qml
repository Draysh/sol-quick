import QtQuick

/*
    Makes a thing answer the pointer: while pointed at it leans a little
    towards it (`reach` pixels at most), and with `presses` it gives under
    a press, as a real card would. Put it last inside the thing (so it sees
    the press before the thing's own MouseArea, which still gets it) and
    list its `transforms` in the thing's `transform`. Nothing moves with
    less motion; at rest it costs nothing.

        Item { id: tile; transform: lean.transforms; …; MouseArea { … }; Lean { id: lean; anchors.fill: parent; presses: true } }
*/
Item {
    id: root

    /** It gives under a press: for a thing that does something when clicked. */
    property bool presses: false
    /** How far it leans towards the pointer, in pixels. */
    property real reach: 2.5
    /** How far in a press pushes it (1 is not at all). */
    property real give: 0.97
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: press.active
    /** For the thing's `transform`. */
    readonly property list<QtObject> transforms: [shift, push]

    z: 100
    readonly property bool moves: !Theme.calm && width > 0 && height > 0

    HoverHandler { id: hover }
    PointHandler { id: press; enabled: root.presses; acceptedButtons: Qt.LeftButton }

    // In half pixels: leaning moves the thing under a still pointer, which moves the lean again;
    // whole steps settle at once instead of chasing a smaller and smaller difference for ever.
    function step(v) { return Math.round(v * 2) / 2 }
    property Translate shift: Translate {
        x: root.moves && hover.hovered ? root.step(root.reach * Math.max(-1, Math.min(1, hover.point.position.x / root.width * 2 - 1))) : 0
        y: root.moves && hover.hovered ? root.step(root.reach * 0.6 * Math.max(-1, Math.min(1, hover.point.position.y / root.height * 2 - 1))) : 0
        Behavior on x { NumberAnimation { duration: Theme.lock * 2; easing: Theme.easeOut } }
        Behavior on y { NumberAnimation { duration: Theme.lock * 2; easing: Theme.easeOut } }
    }
    property Scale push: Scale {
        origin.x: root.width / 2; origin.y: root.height / 2
        xScale: root.moves && press.active ? root.give : 1
        // A tall thing gives as much as a short one, not a share of its height.
        yScale: 1 - (1 - xScale) * Math.min(1, 300 / Math.max(1, root.height))
        Behavior on xScale { NumberAnimation { duration: press.active ? Theme.snap : Theme.settle; easing: press.active ? Theme.easeOut : Theme.spring } }
    }
}

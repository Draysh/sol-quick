import QtQuick

/*
    A line between two stars on a `StarField`, a pixel wide, from its own
    x, y to `x2`, `y2` (on the same plane), in `color`.

        StarLine { x: map.sx(a.x); y: map.sy(a.y); x2: map.sx(b.x); y2: map.sy(b.y); color: Theme.tint(map.words, 0.3) }
*/
Rectangle {
    /** Where the line ends. */
    property real x2: 0
    property real y2: 0

    width: Math.hypot(x2 - x, y2 - y)
    height: 1
    transformOrigin: Item.Left
    rotation: Math.atan2(y2 - y, x2 - x) * 180 / Math.PI
    antialiasing: true
}

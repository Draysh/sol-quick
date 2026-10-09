import QtQuick

/* A tiny crescent in the world's colour, for navigation and lists. */
Item {
    id: root
    property string world: "sol"
    property int size: 10
    /** Draw it hollow, e.g. while the app isn't answering. */
    property bool hollow: false

    readonly property var w: Worlds.get(world)
    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.hollow ? "transparent" : root.w.color
        border.width: root.hollow ? 1 : 0
        border.color: root.w.color
        antialiasing: true
    }
    Rectangle {
        visible: !root.hollow && root.w.kind !== "star"
        x: -root.size * 0.2
        y: 0
        width: root.size
        height: root.size
        radius: width / 2
        color: Theme.space
        antialiasing: true
    }
}

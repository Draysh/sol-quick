import QtQuick
import QtQuick.Shapes

/*
    A tiny crescent in the world's colour, for navigation and lists: a disc
    for a star, the lit sliver for a planet or a moon. Drawn as its own
    shape, so it sits on any ground (a card, the sidebar, glass).
*/
Item {
    id: root
    property string world: "sol"
    property int size: 10
    /** Draw it hollow, e.g. while the app isn't answering. */
    property bool hollow: false

    readonly property var w: Worlds.get(world)
    readonly property color tone: w.color
    readonly property bool disc: hollow || w.kind === "star"
    width: size
    height: size

    Rectangle {
        visible: root.disc
        anchors.fill: parent
        radius: width / 2
        color: root.hollow ? "transparent" : root.tone
        border.width: root.hollow ? 1 : 0
        border.color: root.tone
        antialiasing: true
    }
    // The crescent: the disc less a second one a fifth to the left.
    Shape {
        id: crescent
        visible: !root.disc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        readonly property real r: root.size / 2
        // Where the two circles cross: halfway between their centres.
        readonly property real cx: r * 0.8
        readonly property real dy: r * Math.sqrt(1 - 0.04)
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.tone
            startX: crescent.cx; startY: crescent.r - crescent.dy
            PathArc { x: crescent.cx; y: crescent.r + crescent.dy; radiusX: crescent.r; radiusY: crescent.r; useLargeArc: true; direction: PathArc.Clockwise }
            PathArc { x: crescent.cx; y: crescent.r - crescent.dy; radiusX: crescent.r; radiusY: crescent.r; useLargeArc: false; direction: PathArc.Counterclockwise }
        }
    }
}

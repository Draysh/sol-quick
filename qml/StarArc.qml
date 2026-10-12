import QtQuick

/*
    How far along, as a thin arc round a star on a `StarField`: from the top,
    clockwise, `progress` of the way round (never less than a sliver), with
    round ends. Drawn by one small shader; centred on its own x, y.

        StarArc { x: map.sx(s.x); y: map.sy(s.y); radius: 8; progress: s.progress; tone: map.warm }
*/
Item {
    id: arc

    /** The arc's colour, its distance from the middle and its width, in pixels. */
    property color tone: "white"
    property real radius: 8
    property real thickness: 1.4
    /** How far round, 0–1. */
    property real progress: 0

    ShaderEffect {
        readonly property real reach: arc.radius + arc.thickness + 1
        x: -reach
        y: -reach
        width: reach * 2
        height: reach * 2
        // The colour opaque and its alpha apart, however Qt hands colours to shaders.
        property color tone: Qt.rgba(arc.tone.r, arc.tone.g, arc.tone.b, 1)
        property real alpha: arc.tone.a
        property size size: Qt.size(width, height)
        property real radius: arc.radius
        property real thickness: arc.thickness
        property real sweep: Math.max(6 / 360, arc.progress)
        fragmentShader: "../shaders/arc.frag.qsb"
    }
}

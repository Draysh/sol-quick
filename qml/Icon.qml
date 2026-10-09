import QtQuick
import QtQuick.Shapes

/*
    The few line glyphs the chrome uses, drawn as hairlines in the current
    colour: `arrow-left`, `arrow-right`, `arrow-up-right`, `close`, `tick`,
    `chevron-down`, `search`, `plus`, `minus`, `play`, `sound`.
*/
Shape {
    id: root

    property string name: "close"
    property color color: Theme.text
    property real stroke: 1.2
    property int size: 12

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    readonly property var paths: ({
        "arrow-left": "M 8 2 L 3 7 L 8 12 M 3 7 L 13 7",
        "arrow-right": "M 6 2 L 11 7 L 6 12 M 11 7 L 1 7",
        "arrow-up-right": "M 3 11 L 11 3 M 4 3 L 11 3 L 11 10",
        "close": "M 2 2 L 12 12 M 12 2 L 2 12",
        "tick": "M 2 7.5 L 5.5 11 L 12 3",
        "chevron-down": "M 2 5 L 7 10 L 12 5",
        "search": "M 6 1 A 5 5 0 1 0 6 11 A 5 5 0 1 0 6 1 M 9.6 9.6 L 13 13",
        "plus": "M 7 1 L 7 13 M 1 7 L 13 7",
        "minus": "M 1 7 L 13 7",
        "play": "M 4 2 L 12 7 L 4 12 Z",
        "sound": "M 2 5 L 4.5 5 L 8 2 L 8 12 L 4.5 9 L 2 9 Z M 10.5 4.5 A 3.5 3.5 0 0 1 10.5 9.5"
    })

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.size / 14, root.size / 14)
        PathSvg { path: root.paths[root.name] || "" }
    }
}

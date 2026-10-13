import QtQuick
import QtQuick.Shapes

/*
    The world's emblem as a scaffold behind the pages, as SSS by applibot
    stands its S huge behind each section: the rail's diamond, solid, in a
    soft grey that fades from its top, with the world's kanji cut out of
    it, so large that the window crops it on the right and at the foot. One
    crisp shape, drawn once for the window's size; the panels stand over
    it. Only for a flavour with `scaffold`; nothing otherwise. Over a light
    flavour's paper it is a pale grey-blue.

        Scaffold { anchors.fill: parent }
*/
Item {
    id: root

    /** The kanji cut out of it: the world's. */
    property string glyph: Theme.hud.glyph || ""
    /** The diamond's height, corner to corner, and where its middle stands, as shares of the window. */
    property real reach: 1.2
    property point centre: Qt.point(0.98, 0.5)
    /** Its grey: white over a dark still; over a light one (Terra's paper and blue), a pale grey-blue of the paper. */
    readonly property color ink: Theme.paperArt ? Qt.tint(Theme.paper, Theme.tint(Theme.hud.ground, 0.08)) : Theme.artBright

    visible: !!Theme.hud.scaffold && width > 0 && height > 0
    enabled: false

    readonly property real half: height * reach / 2
    readonly property real cx: width * centre.x
    readonly property real cy: height * centre.y
    readonly property real glyphSize: Math.round(half * 0.82)
    FontMetrics { id: metrics; font.family: Theme.fontTitle; font.pixelSize: root.glyphSize }
    readonly property rect glyphBox: metrics.tightBoundingRect(glyph)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            // The kanji's strokes lie inside the diamond, so every other edge crossed is a hole.
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: root.cx; y1: root.cy - root.half
                x2: root.cx; y2: root.cy + root.half
                GradientStop { position: 0; color: Theme.tint(root.ink, Theme.paperArt ? 0.5 : 0.14) }
                GradientStop { position: 1; color: Theme.tint(root.ink, Theme.paperArt ? 0.14 : 0.05) }
            }
            startX: root.cx; startY: root.cy - root.half
            PathLine { x: root.cx + root.half; y: root.cy }
            PathLine { x: root.cx; y: root.cy + root.half }
            PathLine { x: root.cx - root.half; y: root.cy }
            PathLine { x: root.cx; y: root.cy - root.half }
            PathText {
                // Its pen across and its ink's top down (where a path's text stands), so the kanji's ink is in the diamond's middle.
                x: root.cx - root.glyphBox.x - root.glyphBox.width / 2
                y: root.cy - root.glyphBox.height / 2
                text: root.glyph
                font.family: Theme.fontTitle
                font.pixelSize: root.glyphSize
            }
        }
    }
}

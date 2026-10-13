pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    The moment a star lights in a world's Sky: a point of light swells in
    the dark, throws its cross, and a faint line reaches back to the star
    before it in its constellation; the words stand low on the left: 「星が
    灯った。」 ("a star lit") slams in over the milestone's name. The
    window plays it when the kit hears `sky.lit` (a world's milestone
    reached, or a comet caught), so a world writes nothing for it;
    `_moment=star` stages it.

        win.moment.play({ scene: starScene, chime: true, facts: { title, story, constellation } })
*/
Item {
    id: scene

    property var moment
    readonly property real p: moment ? moment.progress : 1
    readonly property var facts: moment ? moment.facts : ({})
    /** The light coming up, eased; whole at once with less motion. */
    readonly property real swell: moment && moment.calm ? 1 : 1 - Math.pow(1 - Math.min(1, p * 2.4), 3)
    /** The line back to the star before, drawn after the light. */
    readonly property real reach: moment && moment.calm ? 1 : Math.max(0, Math.min(1, (p - 0.25) * 3))
    readonly property color warm: Qt.tint("#fff2df", Theme.tint(Theme.world, 0.45))
    // The star stands up and to the right; its words on the left, as a film's title card.
    readonly property real cx: width * 0.7
    readonly property real cy: height * 0.32

    // The star before: already lit, quiet, up and to the left.
    readonly property real bx: cx - Math.min(220, width * 0.2)
    readonly property real by: cy - Math.min(90, height * 0.1)
    Rectangle {
        x: scene.bx - 3; y: scene.by - 3; width: 6; height: 6; radius: 3
        color: scene.warm
        opacity: 0.55 * scene.swell
    }
    Rectangle {
        x: scene.bx
        y: scene.by
        width: Math.hypot(scene.cx - scene.bx, scene.cy - scene.by) * scene.reach
        height: 1
        transformOrigin: Item.Left
        rotation: Math.atan2(scene.cy - scene.by, scene.cx - scene.bx) * 180 / Math.PI
        antialiasing: true
        color: Theme.tint(scene.warm, 0.5)
    }

    // The new star: its glow, its cross, its heart.
    Shape {
        id: glow
        readonly property real r: 90 * scene.swell
        x: scene.cx - r; y: scene.cy - r; width: r * 2; height: r * 2
        visible: r > 0
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: glow.r; centerY: glow.r; centerRadius: glow.r
                focalX: glow.r; focalY: glow.r
                GradientStop { position: 0; color: Theme.tint(scene.warm, 0.5) }
                GradientStop { position: 0.18; color: Theme.tint(scene.warm, 0.2) }
                GradientStop { position: 0.5; color: Theme.tint(scene.warm, 0.05) }
                GradientStop { position: 1; color: Theme.tint(scene.warm, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: glow.width; y: 0 }
            PathLine { x: glow.width; y: glow.height }
            PathLine { x: 0; y: glow.height }
            PathLine { x: 0; y: 0 }
        }
    }
    Repeater {
        model: [0, 90]
        delegate: Rectangle {
            required property int modelData
            x: scene.cx - width / 2; y: scene.cy
            width: 220 * scene.swell; height: 1
            rotation: modelData
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(scene.warm, 0) }
                GradientStop { position: 0.5; color: Theme.tint(scene.warm, 0.85) }
                GradientStop { position: 1; color: Theme.tint(scene.warm, 0) }
            }
        }
    }
    Rectangle {
        readonly property real r: 2 + 5 * scene.swell
        x: scene.cx - r; y: scene.cy - r; width: r * 2; height: r * 2; radius: r
        color: scene.warm
    }

    MomentCaption {
        moment: scene.moment
        centred: false
        width: Math.min(scene.width - Theme.s6 * 2, 760)
        x: Theme.s6
        // Low on the left, over the bars, as the other moments' title cards stand.
        y: scene.height - implicitHeight - (scene.moment ? scene.moment.barHeight : 0) - Theme.s6
        lead: scene.facts.constellation ? "A star in " + scene.facts.constellation : "A new star in your sky"
        jp: "星が灯った。"
        title: scene.facts.title || ""
        titleSize: Theme.textXl
        line: scene.facts.story || ""
    }
}

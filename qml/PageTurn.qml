pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    How a page turns in the pane, in the world's own way, over the old page
    and the new: one beat of anticipation (the old page darkens), then a
    wipe at full strength with a solid edge in the world's light that
    covers the pane (`Theme.turnCover`, when the old page goes), a hold on
    that frame, and a hard reveal of the new page (`Theme.turnReveal`, when
    its words land). All of it inside `Theme.turn`; then it draws nothing.
    The way is the beat's `turn`:

    - Neptune's "slice": bands of the pane slice across, each a little
      apart, a red edge with a cyan one split off it; held, they jitter;
      they go in two flickers.
    - Saturn's "cut": a film's black bars slam in, close to black with an
      amber line where they meet, hold, and the page cuts in.
    - Mercury's "ink": ink blooms from the page's title, edged in the
      seal's vermilion, until the pane is ink; then it is gone.
    - Terra's "sweep": a broad sweep of sunlight with a sunflower edge
      fills the pane with light, and the page comes up into it.

    Going back runs the other way. It never takes the pointer or the keys;
    with less motion it doesn't play at all. The Shell plays it over its
    pane as it shows a page (never for a tab, which only fades).

        PageTurn { anchors.fill: pages }   …   turn.play("in")   // "in", "up" (a section) or "back"
*/
Item {
    id: root

    /** The flavour's way: "slice", "cut", "ink" or "sweep". */
    readonly property string kind: Theme.beat.turn
    /** The way it runs: 1 left to right, -1 back. */
    property int way: 1
    /** Where Mercury's ink starts: the page's title, top left. */
    property point origin: Qt.point(Theme.margin(width) + 40, 30)

    enabled: false
    visible: run.running
    clip: true

    function play(dir) {
        run.stop()
        if (Theme.calm || Theme.turn === 0 || width <= 0 || height <= 0) return
        way = dir === "back" ? -1 : 1
        seed = (seed + 1) % 997
        run.start()
    }

    /** A new pattern of slices each time. */
    property int seed: 0
    /** A number from 0 to 1 for `i`, always the same one. */
    function noise(i) { const s = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }

    /** How far into the turn it is, in ms. */
    property real at: 0
    readonly property real hit: Math.max(1, Theme.hit)
    readonly property real cover: Math.max(hit + 1, Theme.turnCover)
    readonly property real reveal: Math.max(cover + 1, Theme.turnReveal)
    /** 0 → 1 over the anticipation. */
    readonly property real before: Math.min(1, at / hit)
    /** 0 → 1 as the wipe crosses (anticipation to cover), and 1 → 0 over the reveal. */
    readonly property real across: Math.max(0, Math.min(1, (at - hit) / (cover - hit)))
    readonly property bool held: at >= cover && at < reveal
    readonly property bool revealing: at >= reveal
    /** 0 → 1 over the reveal. */
    readonly property real gone: Math.max(0, Math.min(1, (at - reveal) / Math.max(1, Theme.turn - reveal)))
    /** A step of the hold's jitter, a `flicker` each. */
    readonly property int step: Math.floor(at / Math.max(1, Theme.flicker))
    /** An exit's sharp curve, 0 → 1: slow to start, then quick (easeIn's shape). */
    function sharp(t) { return t * t * t }
    function soft(t) { return 1 - Math.pow(1 - t, 3) }

    NumberAnimation { id: run; target: root; property: "at"; from: 0; to: Theme.turn; duration: Theme.turn }
    Settling { when: run.running }

    // The anticipation: the old page darkens for one beat before the wipe takes it.
    Rectangle {
        anchors.fill: parent
        color: Theme.hud.ground
        opacity: root.revealing ? 0 : 0.32 * root.before
    }

    // ---- Neptune: slices --------------------------------------------------------
    Repeater {
        model: root.kind === "slice" ? 9 : 0
        delegate: Item {
            id: slice
            required property int index
            readonly property real n: root.noise(root.seed * 11 + index)
            // Its band of the pane: nine of a little different heights.
            y: root.height * index / 9
            height: Math.ceil(root.height / 9) + 1
            width: root.width
            // Each starts a little after the one before it would (a noise apart), then snaps across.
            readonly property real t: Math.max(0, Math.min(1, (root.at - root.hit - slice.n * (root.cover - root.hit) * 0.45) / ((root.cover - root.hit) * 0.55)))
            readonly property real reach: root.sharp(1 - Math.pow(1 - slice.t, 2)) * (root.width + 60)
            // Held, it jitters a few pixels a flicker; it goes in two flickers, the odd ones first.
            readonly property real jitter: root.held ? (root.noise(root.seed * 5 + index * 3 + root.step) - 0.5) * 14 : 0
            visible: !root.revealing || (index % 2 === 0 && root.at < root.reveal + Theme.flicker)
            readonly property real lead: root.way > 0 ? slice.reach + slice.jitter : root.width - slice.reach + slice.jitter
            Rectangle {
                x: root.way > 0 ? 0 : slice.lead
                width: root.way > 0 ? Math.max(0, slice.lead) : Math.max(0, root.width - slice.lead)
                height: slice.height
                color: Theme.tint(Theme.hud.ground, 0.74)
            }
            // The edge: the light, and the second light split off it.
            Rectangle { x: slice.lead - (root.way > 0 ? 4 : 0); width: 4; height: slice.height; color: Theme.hudAccent; visible: slice.t > 0 }
            Rectangle { x: slice.lead + root.way * 6; width: 2; height: slice.height; color: Theme.tint(Theme.hudSecond, 0.85); visible: slice.t > 0 }
            // Held, a tear along its top in the two lights, split apart and jumping a flicker at a time.
            readonly property bool torn: root.held && root.noise(root.seed * 3 + index + root.step * 7) > 0.55
            Rectangle {
                visible: slice.torn
                x: (root.noise(root.seed + index * 5 + root.step) - 0.5) * root.width * 0.3
                width: root.width * (0.4 + root.noise(root.seed * 2 + index + root.step) * 0.6); height: 2
                color: Theme.hudAccent
            }
            Rectangle {
                visible: slice.torn
                x: (root.noise(root.seed + index * 5 + root.step) - 0.5) * root.width * 0.3 + 10
                y: 3
                width: root.width * (0.3 + root.noise(root.seed * 4 + index + root.step) * 0.5); height: 1
                color: Theme.tint(Theme.hudSecond, 0.85)
            }
        }
    }

    // ---- Saturn: the film's bars, a black hold, a cut ---------------------------------
    Repeater {
        model: root.kind === "cut" ? 2 : 0
        delegate: Rectangle {
            id: bar
            required property int index
            // Slammed in to a letterbox over the anticipation, closed to black over the wipe;
            // at the reveal they jump back to the letterbox and are gone.
            readonly property real letterbox: 0.12
            readonly property real closed: root.revealing ? bar.letterbox * (1 - root.soft(root.gone))
                : root.at < root.hit ? bar.letterbox * root.soft(root.before)
                : bar.letterbox + (0.5 - bar.letterbox) * root.sharp(root.across)
            width: root.width
            height: Math.ceil(root.height * bar.closed) + 1
            y: bar.index === 0 ? 0 : root.height - height
            // not a token: a film's bars are black, whatever the flavour
            color: "#000000"
            // The amber line along its inner edge, where the two meet when closed.
            Rectangle {
                width: parent.width; height: 2
                y: bar.index === 0 ? parent.height - height : 0
                color: Theme.hudAccent
                opacity: root.revealing ? 0 : 1
            }
        }
    }

    // ---- Mercury: ink from the title ----------------------------------------------
    Item {
        anchors.fill: parent
        visible: root.kind === "ink"
        opacity: root.revealing ? 1 - root.soft(Math.min(1, root.gone * 1.6)) : 1
        readonly property real far: Math.hypot(root.width, root.height) * 1.1
        // A drop at the title over the anticipation, then a bloom to the far corner.
        readonly property real r: root.at < root.hit ? 48 * root.soft(root.before) : 48 + (far - 48) * root.sharp(root.across)
        readonly property real cx: root.way > 0 ? root.origin.x : root.width - root.origin.x
        readonly property real cy: root.origin.y
        id: ink
        // The bloom and two lobes that lag at its edge, so it isn't a perfect circle.
        Repeater {
            model: [{ dx: 0, dy: 0, k: 1 }, { dx: 0.5, dy: 0.35, k: 0.62 }, { dx: -0.2, dy: 0.7, k: 0.5 }]
            delegate: Shape {
                id: blot
                required property var modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property real r: Math.max(1, ink.r * blot.modelData.k)
                readonly property real x0: ink.cx + root.way * blot.modelData.dx * ink.r * 0.7
                readonly property real y0: ink.cy + blot.modelData.dy * ink.r * 0.7
                ShapePath {
                    fillColor: Theme.tint(Theme.hud.ground, 0.8)
                    // Only the bloom itself is edged; the lobes pool into it.
                    strokeColor: blot.modelData.k === 1 ? Theme.tint(Theme.hud.seal || Theme.hudAccent, 0.9) : "transparent"
                    strokeWidth: blot.modelData.k === 1 ? 3 : 0
                    startX: blot.x0 + blot.r; startY: blot.y0
                    PathArc { x: blot.x0 - blot.r; y: blot.y0; radiusX: blot.r; radiusY: blot.r }
                    PathArc { x: blot.x0 + blot.r; y: blot.y0; radiusX: blot.r; radiusY: blot.r }
                }
            }
        }
    }

    // ---- Terra: a sweep of sunlight ---------------------------------------------
    Shape {
        id: sun
        visible: root.kind === "sweep"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.revealing ? 1 - root.soft(Math.min(1, root.gone * 1.4)) : 1
        // The light's leading edge, slanted, and the light it leaves behind it.
        readonly property real lean: root.height * 0.22
        readonly property real edge: -sun.lean + (root.width + sun.lean * 2) * (root.at < root.hit ? 0 : root.soft(root.across))
        readonly property real lead: root.way > 0 ? sun.edge : root.width - sun.edge
        readonly property color light: Theme.artSecond
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: sun.lead - root.way * 260; y1: 0; x2: sun.lead; y2: 0
                GradientStop { position: 0; color: Theme.tint(Theme.artBright, 0.55) }
                GradientStop { position: 1; color: Qt.tint(Theme.tint(Theme.artBright, 0.7), Theme.tint(sun.light, 0.5)) }
            }
            startX: root.way > 0 ? -sun.lean : root.width + sun.lean; startY: 0
            PathLine { x: sun.lead + root.way * sun.lean; y: 0 }
            PathLine { x: sun.lead; y: root.height }
            PathLine { x: root.way > 0 ? -sun.lean : root.width + sun.lean; y: root.height }
        }
        // The gathering glow at the edge over the anticipation.
        ShapePath {
            strokeWidth: 3; strokeColor: Theme.tint(Theme.hudPrimary, root.at < root.hit ? root.before : 1); fillColor: "transparent"
            startX: sun.lead + root.way * sun.lean; startY: 0
            PathLine { x: sun.lead; y: root.height }
        }
    }
}

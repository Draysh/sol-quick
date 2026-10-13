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
    - "curtain" (a flavour's own `turn`: Neptune's and Saturn's, after SSS
      by applibot): a flat panel of the light sweeps across and covers the
      pane, is held, torn for one frame, and sweeps on off the far side. The
      tear is the flavour's `tear`: sideways for a glitch (Neptune's),
      "bars", a film's black bars slamming shut and open again (Saturn's),
      "brush", one stroke of ink slashed across it, drops flung off its
      start and its tail run dry (Mercury's), "flare", a flare of sunlight
      across it (Terra's), or "moon", a rip across it showing the night, its
      edges lit as by the moon (Luna's). A curtain keeps the colours it
      started in, so a turn that crosses into another flavour (Terra's page
      to Luna's) is covered in the one it leaves and lifts on the new one.

    In a flavour with an impact colour (`Theme.impacts`), and on any curtain, the hold is an eyecatch, as a TV
    anime's between its halves: the page arriving's character (`glyph`)
    huge on the darkest ink, one slash across, and its name (`name`) in
    English; the flavour's wipe still covers and reveals it (Neptune's
    slices tear over it). On a curtain the character and its name are set in
    the ink on the light.

    Going back runs the other way. It never takes the pointer or the keys;
    with less motion it doesn't play at all. The Shell plays it over its
    pane as it shows a page (never for a tab, which only fades).

        PageTurn { anchors.fill: pages }   …   turn.play("in")   // "in", "up" (a section) or "back"
*/
Item {
    id: root

    /** The flavour's way: "slice", "cut", "ink", "sweep" or "curtain". */
    readonly property string kind: Theme.beat.turn
    /** The way it runs: 1 left to right, -1 back. */
    property int way: 1
    /** The page arriving's character and name, for the eyecatch on the hold (`Theme.impacts`, or a curtain). */
    property string glyph: ""
    property string name: ""
    readonly property bool eyecatch: (Theme.impacts || kind === "curtain") && glyph !== ""
    /** A curtain's colours and its torn frame, as they were when it started: the light, the ink on it, the tear and its flash. */
    property color sheet: Theme.hudAccent
    property color sheetInk: Theme.cardInk
    property string tearKind: Theme.hud.tear || ""
    property color flash: Theme.impact
    /** Where Mercury's ink starts: the page's title, top left. */
    property point origin: Qt.point(Theme.margin(width) + 40, 30)

    enabled: false
    visible: run.running
    clip: true

    function play(dir) {
        run.stop()
        if (Theme.calm || Theme.turn === 0 || width <= 0 || height <= 0) return
        way = dir === "back" ? -1 : 1
        sheet = Theme.hudAccent
        sheetInk = Theme.cardInk
        tearKind = Theme.hud.tear || ""
        flash = Theme.impact
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

    // The anticipation: the old page darkens for one beat before the wipe takes it (on a light flavour's
    // paper, pales).
    Rectangle {
        anchors.fill: parent
        color: Theme.light ? Theme.paper : Theme.hud.ground
        opacity: root.revealing ? 0 : 0.32 * root.before
    }

    // ---- A curtain of the light (a flavour's `turn: "curtain"`) -------------------------
    /** The one torn frame of the hold, a `flicker` long: a glitch, or a film's bars (the flavour's `tear`). */
    readonly property bool torn: kind === "curtain" && held && at >= cover + Theme.flicker && at < cover + Theme.flicker * 2
    readonly property bool barred: tearKind === "bars"
    readonly property bool brushed: tearKind === "brush"
    readonly property bool flared: tearKind === "flare"
    readonly property bool ripped: tearKind === "moon"
    /** A glitch: three bands of the curtain jumping sideways (no tear of the flavour's own). */
    readonly property bool glitched: torn && !barred && !brushed && !flared && !ripped
    Item {
        id: curtain
        visible: root.kind === "curtain" && root.at >= root.hit
        width: root.width
        height: root.height
        // In from the side it runs from, covering the pane; held; then on off the far side.
        x: root.way * (root.revealing ? root.width * root.sharp(root.gone) : -root.width * (1 - root.soft(root.across)))
        Rectangle { anchors.fill: parent; color: root.sheet }
        // Torn: three bands of it jump sideways, the dark showing in the gaps.
        Repeater {
            model: root.glitched ? 3 : 0
            delegate: Rectangle {
                required property int index
                readonly property real n: root.noise(root.seed * 7 + index * 13)
                y: root.height * (0.12 + index * 0.3 + n * 0.12)
                height: 6 + n * 22
                x: (n - 0.5) * 120
                width: root.width
                color: root.sheetInk
                Rectangle { x: (0.5 - n) * 80 + 30; width: parent.width; height: parent.height; color: root.sheet }
            }
        }
    }

    // Barred: for that frame a film's black bars shut over the curtain to a slit, an amber line along each.
    Repeater {
        model: root.torn && root.barred ? 2 : 0
        delegate: Rectangle {
            id: shut
            required property int index
            width: root.width
            height: Math.ceil(root.height * 0.38)
            y: shut.index === 0 ? 0 : root.height - height
            z: 2
            // not a token: a film's bars are black, whatever the flavour
            color: "#000000"
            Rectangle { width: parent.width; height: 2; y: shut.index === 0 ? parent.height - height : 0; color: root.sheet }
        }
    }

    // Brushed: for that frame one stroke of ink slashes across the curtain and the character on it,
    // rising the way the turn runs, broad in its belly, its tail run dry, drops flung off where it began.
    Shape {
        id: brush
        visible: root.torn && root.brushed
        anchors.fill: parent
        z: 2
        preferredRendererType: Shape.CurveRenderer
        readonly property real n: root.noise(root.seed * 3 + 1)
        /** A point `t` (0 to 1) along the stroke's middle, and how broad the stroke is there. */
        function along(t) {
            const w = root.width, h = root.height
            const x = -0.04 * w + t * 1.08 * w
            const y = h * (0.66 + brush.n * 0.08) - t * h * 0.34 + Math.sin(t * Math.PI) * h * 0.05
            return Qt.point(root.way > 0 ? x : w - x, y)
        }
        function broad(t) { return root.height * (t < 0.12 ? 0.04 + t / 0.12 * 0.13 : 0.17 - Math.pow(Math.max(0, t - 0.55) / 0.45, 1.6) * 0.14) }
        /** Its outline: down one edge and back along the other, the nib held flat. */
        readonly property var outline: {
            const top = [], foot = []
            for (let i = 0; i <= 24; i++) {
                // Each edge a little ragged, as bristles leave it.
                const t = i / 24, p = brush.along(t), b = brush.broad(t) / 2
                const up = 1 + (root.noise(root.seed * 13 + i) - 0.5) * 0.22, down = 1 + (root.noise(root.seed * 17 + i * 3) - 0.5) * 0.22
                top.push(Qt.point(p.x - b * 0.28, p.y - b * up))
                foot.unshift(Qt.point(p.x + b * 0.28, p.y + b * down))
            }
            return top.concat(foot, [top[0]])
        }
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"; fillColor: root.sheetInk
            PathPolyline { path: brush.outline }
        }
        // The dry tail: hairs of the curtain showing through its last third.
        ShapePath {
            strokeWidth: Math.max(2, root.height * 0.006); strokeColor: root.sheet; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathPolyline { path: [0.6, 0.7, 0.8, 0.9, 1].map(t => { const p = brush.along(t); return Qt.point(p.x, p.y - brush.broad(t) * 0.18) }) }
        }
        ShapePath {
            strokeWidth: Math.max(1, root.height * 0.004); strokeColor: root.sheet; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathPolyline { path: [0.7, 0.8, 0.9, 1].map(t => { const p = brush.along(t); return Qt.point(p.x, p.y + brush.broad(t) * 0.22) }) }
        }
    }
    // The drops flung off where the stroke began.
    Repeater {
        model: root.torn && root.brushed ? 7 : 0
        delegate: Rectangle {
            required property int index
            readonly property real n: root.noise(root.seed * 5 + index * 11)
            readonly property point from: brush.along(0.05 + n * 0.12)
            z: 2
            width: Math.round(root.height * (0.008 + n * 0.022)); height: width; radius: width / 2
            x: from.x + root.way * (n - 0.6) * root.height * 0.3 - width / 2
            y: from.y + (index % 2 ? -1 : 1) * root.height * (0.1 + root.noise(index * 7 + root.seed) * 0.12)
            color: root.sheetInk
        }
    }

    // Flared: for that frame a flare of sunlight crosses the curtain on the diagonal, rising the way the
    // turn runs: a broad soft band of paper light round a hot core, and the lens's rings along it.
    Item {
        id: flare
        visible: root.torn && root.flared
        anchors.fill: parent
        z: 2
        readonly property real n: root.noise(root.seed * 3 + 2)
        readonly property real reach: Math.hypot(root.width, root.height) * 1.2
        readonly property real broad: root.height * (0.3 + flare.n * 0.08)
        Rectangle {
            x: (root.width - width) / 2
            y: root.height * (0.42 + flare.n * 0.16) - height / 2
            width: flare.reach
            height: flare.broad
            rotation: root.way * -24
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.tint(root.sheetInk, 0) }
                GradientStop { position: 0.36; color: Theme.tint(root.sheetInk, 0.5) }
                GradientStop { position: 0.5; color: root.sheetInk }
                GradientStop { position: 0.64; color: Theme.tint(root.sheetInk, 0.5) }
                GradientStop { position: 1; color: Theme.tint(root.sheetInk, 0) }
            }
        }
        // The lens's rings: a few soft circles of light strung along the flare from its source.
        Repeater {
            model: root.torn && root.flared ? 4 : 0
            delegate: Rectangle {
                required property int index
                readonly property real t: [0.16, 0.38, 0.62, 0.8][index]
                readonly property real d: root.height * [0.24, 0.08, 0.16, 0.05][index]
                readonly property real across: root.way > 0 ? root.width * flare.t : root.width * (1 - flare.t)
                readonly property real lift: Math.tan(24 * Math.PI / 180) * (across - root.width / 2) * root.way
                x: across - width / 2
                y: root.height * (0.42 + flare.n * 0.16) - lift - height / 2
                width: d; height: d; radius: d / 2
                color: Theme.tint(root.sheetInk, index % 2 ? 0.55 : 0.22)
                border.width: Math.max(1, d * 0.04); border.color: Theme.tint(root.sheetInk, 0.8)
            }
        }
    }

    // Ripped: for that frame the curtain is torn across, the night showing through the rip and its
    // ragged edges lit as by the moon.
    Shape {
        id: rip
        visible: root.torn && root.ripped
        anchors.fill: parent
        z: 2
        preferredRendererType: Shape.CurveRenderer
        readonly property real n: root.noise(root.seed * 3 + 4)
        /** Where the rip's middle runs at `t` across (0 to 1), falling the way the turn runs. */
        function at(t) { return root.height * (0.4 + rip.n * 0.18) + (root.way > 0 ? t - 0.5 : 0.5 - t) * root.height * 0.22 }
        /** One ragged edge, above (-1) or below (1) the middle. */
        function edge(side) {
            const out = []
            for (let i = 0; i <= 28; i++) {
                const t = i / 28
                const open = root.height * (0.012 + 0.05 * Math.sin(t * Math.PI))
                const jag = (root.noise(root.seed * 19 + i * (side > 0 ? 5 : 3)) - 0.5) * root.height * 0.05
                out.push(Qt.point(-4 + t * (root.width + 8), rip.at(t) + side * open + jag))
            }
            return out
        }
        readonly property var upper: edge(-1)
        readonly property var lower: edge(1)
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"; fillColor: root.sheetInk
            PathPolyline { path: rip.upper.concat(rip.lower.slice().reverse(), [rip.upper[0]]) }
        }
        ShapePath {
            strokeWidth: Math.max(2, root.height * 0.004); strokeColor: root.flash; fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: rip.upper }
        }
        ShapePath {
            strokeWidth: Math.max(1, root.height * 0.0025); strokeColor: Theme.tint(root.flash, 0.7); fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: rip.lower }
        }
    }

    // ---- The eyecatch, on the hold (`Theme.impacts`, or a curtain) --------------------
    Item {
        id: catcher
        anchors.fill: parent
        visible: root.eyecatch && root.held
        z: 1
        // On a curtain, the curtain is its ground and it is set in the ink.
        readonly property bool onCurtain: root.kind === "curtain"
        Rectangle { visible: !catcher.onCurtain; anchors.fill: parent; color: Theme.cardInk }
        Text {
            id: catchGlyph
            text: root.glyph.charAt(0)
            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle
            font.pixelSize: Math.round(root.height * 0.74)
            color: catcher.onCurtain ? root.sheetInk : Theme.hudAccent
            x: (root.way > 0 ? Math.round(root.width * 0.08) : root.width - width - Math.round(root.width * 0.08)) + (root.glitched ? 14 : 0)
            y: (root.height - height) / 2
        }
        // One slash across, on the flavour's diagonal.
        Rectangle {
            visible: !catcher.onCurtain
            width: Math.hypot(root.width, root.height) * 1.2
            height: Theme.s2
            x: (root.width - width) / 2
            y: root.height / 2
            rotation: -90 + Theme.slant
            color: Theme.artBright
            antialiasing: true
        }
        Text {
            text: root.name
            // Clear of the character where the pane is narrow.
            x: root.way > 0 ? Math.max(root.width * 0.55, catchGlyph.x + catchGlyph.width + Theme.s4) : root.width * 0.12
            y: root.height * 0.62
            font.family: Theme.fontCaps; font.pixelSize: Theme.textXl; font.weight: Font.Bold
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXl); font.capitalization: Font.AllUppercase
            color: catcher.onCurtain ? root.sheetInk : Theme.artBright
        }
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
                // Held over an eyecatch, only the slices' edges and tears show over it.
                visible: !(catcher.visible)
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
                width: root.width * (0.3 + root.noise(root.seed * 4 + slice.index + root.step) * 0.5); height: 1
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

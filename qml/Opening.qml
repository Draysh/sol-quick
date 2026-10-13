pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    The world's opening, once a launch, about a second: over a
    dark frame the world's kanji (its flavour's `glyph`; with `openingName`
    its whole name: Neptune's 海王星, torn twice by a glitch in its hold,
    Saturn's 土星) slams in in the
    title face (SlamText), with its name under it (Mercury's 水星 is written
    instead, in one stroke of the brush in Yuji Syuku, the ink blooming
    round it as it soaks in and the seal pressed beside it; Terra's 地球
    drops in with a soft bounce on a bright summer sky, a furin swinging
    beside it as its sting chimes; Luna's 月 rises out of an indigo night in
    the moon's yellow, in a halo of moonlight); a hold; then the frame
    goes the world's way as the rail draws in row by row, and the first
    page's title lands. Neptune's frame slices away in glitches; Saturn's is
    a film's title card (its whole name, 土星, on the night between black
    letterbox bars that slam in with it, an amber line along each), cut to
    black for a hold, then cut to the page; Mercury's ink clears from the
    kanji, Terra's is swept away by sunlight, Luna's night lifts quietly.
    Its sting plays with the slam. A window opened on a carried moon's page
    with a flavour of its own (`sol-luna`, `--open /luna`) opens in the
    moon's way (the flavour's `opening`).

    It plays only for a window opened to be seen (not one started out of
    sight, with the computer). It never stands in the way: the first page is made and ready under it
    from the start, any key or click ends it at once and still does what
    it does (the click lands on what is under it), and with less motion it
    doesn't play. Nor in pictures (SOL_SHOT, SOL_SHOTS) unless the
    picture's path asks for it with `_opening=1`. The Shell plays it as it
    goes home.

        Opening { anchors.fill: parent; z: 30; shell: shell; rail: side }   …   opening.play()
*/
Item {
    id: root

    /** The Shell it opens (its first page lands at the end) and its sidebar (its rows draw in). */
    property Item shell: null
    property Design.Sidebar rail: null

    /** Milliseconds into the opening; past `end` when it isn't playing. */
    property real at: 1e9
    readonly property bool playing: run.running

    // The beats: the slam (a hit), a hold, the frame going as the rail draws in, the page landing.
    /** Mercury's one stroke of the brush, writing the name from left to right. */
    readonly property real stroke: Theme.hold * 2
    // Every opening holds its name about half a second, long enough to be read, and is gone
    // within 0.7 to 1.1 s, each in its own rhythm: Saturn's film cuts at 0.72 s, Neptune's slices
    // and Terra's sunlight are gone by 0.9, Mercury's ink and Luna's night take the longest,
    // clearing slowly (about 1.06).
    readonly property real leaveAt: kind === "ink" ? stroke + Theme.hold * 2 : kind === "moon" ? Theme.hit + Theme.hold * 4 : Theme.hit + Theme.hold * 3
    readonly property real leaveFor: kind === "ink" ? Theme.turn : Math.round(Theme.turn * 0.8)
    /** When the page lands: a hold after the frame starts going; Terra's sunlight and Luna's night uncover it landing, so it never blinks out under them. */
    readonly property real landAt: kind === "sweep" || kind === "moon" ? leaveAt : leaveAt + Theme.hold
    /** A film's card (Saturn's) goes to black at `leaveAt`, holds, and cuts to the page here, all at once. */
    readonly property real cutAt: leaveAt + Theme.hold
    /** When the rail draws in: as the frame goes, or at a film's cut. */
    readonly property real railAt: kind === "cut" ? cutAt : leaveAt
    readonly property real end: leaveAt + leaveFor
    /** 0 → 1 as the frame goes. */
    readonly property real going: Math.max(0, Math.min(1, (at - leaveAt) / Math.max(1, leaveFor)))
    /** The world's way: its flavour's `opening` (Luna's "moon"), else its page turn's ("slice", "cut", "ink", "sweep"). */
    readonly property string kind: Theme.hud.opening || Theme.beat.turn

    visible: playing
    // Whether a picture asked for it: `_opening=1` in its path.
    readonly property bool staged: /[?&]_opening=1(&|$)/.test(SolBackend.shotPath)

    /** Plays it, if this launch hasn't yet and nothing says not to. */
    function play() {
        const win = root.Window.window as Design.AppWindow
        if (win && win.opened) return
        if (win) win.opened = true
        const shooting = SolBackend.shot !== "" || SolBackend.shots !== ""
        if (Theme.calm || Theme.turn === 0 || (shooting && !staged) || Sol.background) return
        // Opened on a moon's page (`sol-luna`, `--open /luna`): the moon's look from the first frame,
        // before the Shell gets there a moment later, so its own opening plays and its sting sounds.
        const asked = String(SolBackend.openPath !== "" ? SolBackend.openPath : staged ? SolBackend.shotPath : "").split("?")[0]
        const s = shell as Design.Shell
        const of = s && asked !== "" ? s.worldOf(asked) : ""
        if (of !== "" && Theme.yozoraLooks[of]) Theme.worldId = of
        railed = false
        landed = false
        run.restart()
        Sounds.opening()
    }
    /** Ends it at once: the frame gone, the rail's rows in their places, its sting fading; the page is there already. */
    function skip() {
        if (!run.running) return
        run.stop()
        Sounds.hushOpening()
        at = 1e9
        if (rail && railed) rail.drawnIn()
    }

    property bool railed: false
    property bool landed: false
    onAtChanged: {
        if (!run.running) return
        if (!railed && at >= railAt) { railed = true; if (rail) rail.drawIn() }
        if (!landed && at >= landAt) {
            landed = true
            const page = shell ? (shell as Design.Shell).page as Design.Screen : null
            if (page) page.reveal("open")
        }
    }
    NumberAnimation { id: run; target: root; property: "at"; from: 0; to: root.end; duration: root.end; onFinished: root.at = 1e9 }
    Design.Settling { when: run.running }

    // Any click ends it and still lands where it was aimed: a passive look at the press only.
    PointHandler { acceptedButtons: Qt.AllButtons; onActiveChanged: if (active) root.skip() }

    /** A number from 0 to 1 for `i`, always the same one. */
    function noise(i) { const s = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }
    function soft(t) { return 1 - Math.pow(1 - t, 3) }
    function sharp(t) { return t * t * t }

    /** The frame: the ground, or a film's black for Saturn's. */
    // not a token: a film's title card is black, whatever the flavour
    readonly property color frame: kind === "cut" ? "#000000" : Theme.hud.dim || Theme.hud.ground
    /** Over a dark frame a breath of the page shows through; Terra's bright sky and Luna's night are whole. */
    readonly property real frameAlpha: kind === "sweep" || kind === "moon" ? 1 : 0.97
    // Where the kanji stands: the middle, a little high.
    readonly property real cx: width / 2
    readonly property real cy: height * 0.44

    // ---- The frame, going the world's way --------------------------------------
    // Neptune's: slices, each torn away sideways in steps, a noise apart.
    Repeater {
        model: root.kind === "slice" ? 9 : 0
        delegate: Item {
            id: slice
            required property int index
            readonly property real n: root.noise(17 + index * 3)
            readonly property real t: Math.max(0, Math.min(1, (root.at - root.leaveAt - slice.n * root.leaveFor * 0.4) / (root.leaveFor * 0.6)))
            // In steps of a third, as a glitch moves.
            readonly property real stepped: Math.ceil(slice.t * 3) / 3
            readonly property int way: index % 2 ? 1 : -1
            y: root.height * index / 9
            width: root.width
            height: Math.ceil(root.height / 9) + 1
            x: slice.way * root.sharp(slice.stepped) * root.width * 1.05
            Rectangle { anchors.fill: parent; color: Theme.tint(root.frame, root.frameAlpha) }
            Rectangle { visible: slice.t > 0; x: slice.way > 0 ? -3 : parent.width; width: 3; height: parent.height; color: Theme.hudAccent }
            Rectangle { visible: slice.t > 0; x: slice.way > 0 ? -9 : parent.width + 6; width: 2; height: parent.height; color: Theme.tint(Theme.hudSecond, 0.8) }
        }
    }
    // Saturn's: a film's title card. The night between black letterbox bars, which slam in from
    // the window's edges with the name, an amber line along each; at `leaveAt` it cuts to black,
    // holds, and at `cutAt` cuts to the page, nothing easing.
    Item {
        id: film
        visible: root.kind === "cut" && root.at < root.cutAt
        anchors.fill: parent
        /** The bars' height at rest: the frame a wide film's (2.39:1), never under an eighth of the window. */
        readonly property real bar: Math.max(root.height / 8, (root.height - root.width / 2.39) / 2)
        /** 0 → 1 over the slam: the bars come in from beyond the edges. */
        readonly property real k: Math.max(0, Math.min(1, root.at / Math.max(1, Theme.hit)))
        readonly property real shown: Math.round(film.bar * root.soft(film.k))
        readonly property bool black: root.at >= root.leaveAt
        // The black under it all, and the night inside the frame until it cuts to black.
        Rectangle { anchors.fill: parent; color: root.frame }
        Rectangle {
            visible: !film.black
            y: film.shown; width: parent.width; height: parent.height - film.shown * 2
            color: Theme.tint(Theme.hud.ground, root.frameAlpha)
        }
        Repeater {
            model: 2
            delegate: Item {
                id: filmBar
                required property int index
                width: film.width
                height: film.shown
                y: filmBar.index === 0 ? 0 : film.height - film.shown
                Rectangle { anchors.fill: parent; color: root.frame }
                Rectangle {
                    visible: !film.black && film.k > 0
                    width: parent.width; height: 2
                    y: filmBar.index === 0 ? parent.height - height : 0
                    color: Theme.hudAccent
                }
            }
        }
    }
    // Mercury's: the ink clears from the kanji outwards, its edge the seal's vermilion.
    Shape {
        visible: root.kind === "ink"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real far: Math.hypot(root.width, root.height)
        readonly property real e: Math.min(0.97, root.soft(root.going))
        id: inkFrame
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.cx; centerY: root.cy; focalX: root.cx; focalY: root.cy
                centerRadius: inkFrame.far
                GradientStop { position: 0; color: Theme.tint(root.frame, inkFrame.e > 0 ? 0 : root.frameAlpha) }
                GradientStop { position: Math.max(0.001, inkFrame.e); color: Theme.tint(root.frame, inkFrame.e > 0 ? 0 : root.frameAlpha) }
                // The vermilion edge only once the ink is clearing: before, the frame is one even dark.
                GradientStop { position: Math.min(0.998, inkFrame.e + 0.004); color: inkFrame.e > 0 ? Theme.tint(Theme.hud.seal || Theme.hudAccent, 0.75) : Theme.tint(root.frame, root.frameAlpha) }
                GradientStop { position: Math.min(0.999, inkFrame.e + 0.016); color: Theme.tint(root.frame, root.frameAlpha) }
                GradientStop { position: 1; color: Theme.tint(root.frame, root.frameAlpha) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // Terra's: a bright summer sky, which a sweep of sunlight runs across and takes with it.
    Item {
        id: sunFrame
        visible: root.kind === "sweep"
        anchors.fill: parent
        // Where the light's edge is across the window, 0 to 1 (from a little before to a little past).
        readonly property real e: -0.15 + 1.3 * root.soft(root.going)
        readonly property real edgeX: Math.round(sunFrame.e * root.width)
        Item {
            x: Math.max(0, sunFrame.edgeX)
            width: Math.max(0, root.width - x); height: root.height
            clip: true
            Rectangle {
                x: -parent.x
                width: root.width; height: root.height
                opacity: root.frameAlpha
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.duskSky[0] }
                    GradientStop { position: 0.55; color: Theme.duskSky[1] }
                    GradientStop { position: 1; color: Theme.duskSky[2] }
                }
            }
            // The summer's haze, low over it.
            Rectangle {
                x: -parent.x; y: root.height * 0.6
                width: root.width; height: root.height * 0.4
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.tint(Theme.artBright, 0) }
                    GradientStop { position: 1; color: Theme.tint(Theme.artBright, 0.35) }
                }
            }
        }
        // The light's edge: sunlight just behind the line, the sunflower's warmth at its brightest.
        Rectangle {
            visible: root.going > 0
            x: sunFrame.edgeX - width
            width: Math.round(root.width * 0.12); height: root.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(Theme.artBright, 0) }
                GradientStop { position: 1; color: Qt.tint(Theme.tint(Theme.artBright, 0.75), Theme.tint(Theme.hudPrimary, 0.35)) }
            }
        }
    }
    // Luna's: an indigo night with a few stars, lifting quietly as the moonlight grows.
    Item {
        visible: root.kind === "moon"
        anchors.fill: parent
        opacity: 1 - root.soft(root.going)
        Rectangle {
            anchors.fill: parent
            opacity: root.frameAlpha
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.duskSky[0] }
                GradientStop { position: 0.5; color: Theme.duskSky[1] }
                GradientStop { position: 0.8; color: Theme.duskSky[2] }
                GradientStop { position: 1; color: Theme.duskSky[Theme.duskSky.length - 1] }
            }
        }
        Repeater {
            model: 36
            delegate: Rectangle {
                required property int index
                readonly property real n: root.noise(5 + index * 7)
                x: root.noise(11 + index * 5) * root.width
                y: root.noise(3 + index * 13) * root.height * 0.8
                width: n > 0.85 ? 2 : 1; height: width
                color: Theme.tint(Theme.artSecond, 0.25 + 0.5 * n)
            }
        }
        // The moonlight round the kanji, widening as the night lifts.
        Shape {
            readonly property real r: Math.min(root.width, root.height) * (0.34 + 0.2 * root.soft(root.going))
            x: root.cx - r; y: root.cy - r
            width: r * 2; height: r * 2
            opacity: Math.min(1, Math.max(0, root.at) / Math.max(1, Theme.hit + Theme.hold))
            preferredRendererType: Shape.CurveRenderer
            id: moonlight
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: moonlight.r; centerY: moonlight.r; focalX: moonlight.r; focalY: moonlight.r
                    centerRadius: moonlight.r
                    GradientStop { position: 0; color: Theme.tint(Theme.artSecond, 0.42) }
                    GradientStop { position: 0.4; color: Theme.tint(Theme.artSecond, 0.14) }
                    GradientStop { position: 1; color: Theme.tint(Theme.artSecond, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: moonlight.width; y: 0 }
                PathLine { x: moonlight.width; y: moonlight.height }
                PathLine { x: 0; y: moonlight.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // Terra's furin: a glass wind chime and its paper strip, hung from the top of the frame
    // beside the name and set swinging by a breath of wind as its sting chimes, dying away.
    component Furin: Item {
        id: furin
        /** The bell's width; the strip hangs about as long again under it. */
        property real size: 60
        /** The strip's swing past the bell's, in degrees: it lags and swings further. */
        property real strip: 0
        width: size
        height: size * 2
        Shape {
            width: furin.size; height: furin.size * 0.7
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: Math.max(1.5, furin.size * 0.04); strokeColor: Theme.artBright; fillColor: Theme.tint(Theme.artBright, 0.3)
                startX: furin.size * 0.08; startY: furin.size * 0.66
                PathArc { x: furin.size * 0.92; y: furin.size * 0.66; radiusX: furin.size * 0.46; radiusY: furin.size * 0.46; useLargeArc: true }
                PathLine { x: furin.size * 0.08; y: furin.size * 0.66 }
            }
        }
        // The light on the glass.
        Rectangle { x: furin.size * 0.26; y: furin.size * 0.2; width: furin.size * 0.08; height: furin.size * 0.24; radius: width / 2; rotation: 24; color: Theme.tint(Theme.artBright, 0.8); antialiasing: true }
        // The clapper's string, and the strip the wind catches.
        Item {
            x: furin.size / 2; y: furin.size * 0.62
            rotation: furin.strip
            transformOrigin: Item.TopLeft
            Rectangle { x: -0.75; width: 1.5; height: furin.size * 0.42; color: Theme.tint(Theme.artBright, 0.8); antialiasing: true }
            Rectangle { x: -furin.size * 0.15; y: furin.size * 0.42; width: furin.size * 0.3; height: furin.size * 0.9; color: Theme.hudPrimary; antialiasing: true }
        }
    }
    Item {
        id: hanger
        visible: root.kind === "sweep"
        readonly property real bell: Math.round(Math.max(40, glyph.size * 0.28))
        /** Since the slam: the swing, and the strip's, a little behind it and further. */
        readonly property real t: Math.max(0, root.at)
        readonly property real swing: 12 * Math.exp(-hanger.t / 520) * Math.sin(2 * Math.PI * hanger.t / 640)
        readonly property real stripSwing: 20 * Math.exp(-hanger.t / 600) * Math.sin(2 * Math.PI * (hanger.t - 90) / 640)
        readonly property real hangs: Math.max(Theme.s5, title.y + glyph.height * 0.06)
        x: title.x + title.width + Theme.s6
        width: 1; height: 1
        opacity: (1 - title.gone) * Math.min(1, hanger.t / Math.max(1, Theme.hit))
        rotation: hanger.swing
        transformOrigin: Item.TopLeft
        Rectangle { x: -1; width: 2; height: hanger.hangs; color: Theme.tint(Theme.artBright, 0.7); antialiasing: true }
        Furin { x: -width / 2; y: hanger.hangs; size: hanger.bell; strip: hanger.stripSwing - hanger.swing }
    }

    // ---- The kanji and the world's name ------------------------------------------
    /** What slams in: the flavour's kanji, or the world's whole name in Japanese (`openingName`: Neptune's 海王星, a sign's word). */
    readonly property bool wholeName: !!Theme.hud.openingName
    readonly property string word: wholeName ? Theme.jpOf(Theme.worldId) : Theme.hud.glyph || Theme.jpOf(Theme.worldId).charAt(0)
    /** Neptune's glitch: the slammed words torn sideways twice in the hold, a flicker each. */
    readonly property real tear: !wholeName || !Theme.hud.chroma ? 0
        : at >= Theme.hit + Theme.flicker && at < Theme.hit + Theme.flicker * 2 ? 7
        : at >= Theme.hit + Theme.hold && at < Theme.hit + Theme.hold + Theme.flicker ? -4 : 0
    Item {
        id: title
        readonly property real gone: root.kind === "ink" ? Math.min(1, root.soft(root.going) * 1.8) : root.kind === "cut" ? (root.at >= root.leaveAt ? 1 : 0) : root.kind === "moon" ? root.soft(root.going) : Math.min(1, root.going * 2.5)
        x: root.cx - width / 2
        y: root.cy - glyph.height / 2 - (root.kind === "sweep" ? root.soft(title.gone) * Theme.s3 : 0)
        width: Math.max(glyph.width, name.implicitWidth)
        height: glyph.height + Theme.s3 + name.height
        opacity: 1 - title.gone
        scale: 1 - 0.06 * root.sharp(title.gone)
        Design.SlamText {
            id: glyph
            visible: root.kind !== "ink"
            x: (title.width - width) / 2
            text: root.word
            // A kanji as large as the window allows; a word, each character a little smaller.
            size: Math.round(Math.max(96, Math.min(root.height * 0.36, root.width * (root.word.length > 1 ? 0.6 / root.word.length : 0.28), 300)))
            at: root.at
            tear: root.tear
            // Terra's drops in with a soft bounce; Luna's rises in the moon's yellow.
            way: root.kind === "sweep" ? "bounce" : root.kind === "moon" ? "rise" : "slam"
            color: root.kind === "moon" ? Theme.artAccent : Theme.artBright
        }
        // Mercury's: the name written in one stroke, its leading edge soft as wet ink; the ink blooms
        // round the strokes as it soaks in and settles, and the seal is pressed beside it as the brush lifts.
        Item {
            id: brush
            visible: root.kind === "ink"
            x: glyph.x
            width: glyph.width; height: glyph.height
            /** 0 → 1 along the stroke: quick from the press, slowing as the brush lifts. */
            readonly property real k: root.soft(Math.max(0, Math.min(1, root.at / Math.max(1, root.stroke))))
            /** The wet edge, and room round the words for the bloom. */
            readonly property real feather: Math.round(glyph.size * 0.5)
            readonly property real reach: Math.round(glyph.size * 0.2)
            /** The bloom: strong as the ink goes down, gone a hold after the stroke. */
            readonly property real wet: root.at < root.stroke ? 1 : Math.max(0, 1 - (root.at - root.stroke) / Math.max(1, Theme.hold * 2))
            readonly property color ink: Theme.hud.washi || Theme.artBright
            Item {
                x: -brush.reach; y: -brush.reach
                width: brush.k >= 1 ? brush.width + brush.reach * 2 : brush.k * (brush.width + brush.feather) + brush.reach
                height: brush.height + brush.reach * 2
                clip: true
                Text {
                    x: brush.reach; y: brush.reach
                    width: brush.width
                    text: root.word
                    font.family: Theme.titleFace(glyph.size); font.weight: Theme.titleWeight(glyph.size); font.pixelSize: glyph.size; font.features: Theme.titleFeatures
                    color: Theme.tint(brush.ink, 0.5)
                    opacity: brush.wet
                    scale: 1 + 0.04 * (1 - brush.wet)
                    layer.enabled: brush.wet > 0
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
                }
                Text {
                    x: brush.reach; y: brush.reach
                    width: brush.width
                    text: root.word
                    font.family: Theme.titleFace(glyph.size); font.weight: Theme.titleWeight(glyph.size); font.pixelSize: glyph.size; font.features: Theme.titleFeatures
                    color: brush.ink
                }
                // The wet edge: the frame's own dark over the last of what the brush has reached.
                Rectangle {
                    visible: brush.k < 1
                    x: parent.width - width
                    width: brush.feather; height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.tint(root.frame, 0) }
                        GradientStop { position: 1; color: root.frame }
                    }
                }
            }
            // The seal, pressed low beside the last character as the brush lifts.
            Design.HudSeal {
                readonly property real since: root.at - root.stroke
                visible: since >= 0
                size: Math.round(Math.max(28, glyph.size * 0.2))
                x: brush.width + Theme.s2
                y: brush.height * 0.62
                text: Theme.hud.glyph || ""
                tilt: -4
                scale: since < Theme.hit ? 1.25 - 0.25 * since / Math.max(1, Theme.hit) : 1
            }
        }
        Row {
            id: name
            x: (title.width - width) / 2
            y: glyph.height + Theme.s3
            spacing: Theme.s3
            // After the hit (Mercury's, after the stroke), as a title card's line comes.
            opacity: Math.max(0, Math.min(1, (root.at - (root.kind === "ink" ? root.stroke : Theme.hit + Theme.flicker)) / Math.max(1, Theme.hit)))
            readonly property var w: Worlds.get(Theme.worldId)
            Text {
                visible: !root.wholeName
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.jpOf(Theme.worldId)
                font.family: Theme.titleFace(Theme.textLede); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(Theme.textLede); font.pixelSize: Theme.textLede
                color: Theme.artBright
            }
            Rectangle { visible: !root.wholeName; anchors.verticalCenter: parent.verticalCenter; width: 1; height: Theme.textLede; color: Theme.tint(Theme.artBright, 0.4) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: name.w ? name.w.name : ""
                font.family: Theme.fontCaps; font.pixelSize: Theme.textS; font.weight: Font.DemiBold
                font.letterSpacing: Theme.track(Theme.trackHud, Theme.textS); font.capitalization: Font.AllUppercase
                // On Terra's bright sky the sun's pale yellow wouldn't read: white.
                color: root.kind === "sweep" ? Theme.artBright : Theme.artAccent
                style: root.kind === "sweep" ? Text.Raised : Text.Normal; styleColor: glyph.shadow
            }
        }
    }
}

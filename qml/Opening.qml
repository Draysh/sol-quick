pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    The world's opening, once a launch, a little over a second: over a
    dark frame the world's kanji (its flavour's `glyph`; Neptune's whole name,
    海王星, torn twice by a glitch in its hold) slams in in the
    title face (SlamText), with its name under it; a hold; then the frame
    goes the world's way as the rail draws in row by row, and the first
    page's title lands. Neptune's frame slices away in glitches, Saturn's
    opens like a film's bars, Mercury's ink clears from the kanji, Terra's
    is swept away by sunlight. Its sting plays with the slam.

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
    readonly property real leaveAt: Theme.hit + Theme.hold * 2
    readonly property real leaveFor: Math.round(Theme.turn * 0.8)
    readonly property real landAt: leaveAt + Theme.hold
    readonly property real end: leaveAt + leaveFor
    /** 0 → 1 as the frame goes. */
    readonly property real going: Math.max(0, Math.min(1, (at - leaveAt) / Math.max(1, leaveFor)))
    readonly property string kind: Theme.beat.turn

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
        railed = false
        landed = false
        run.restart()
        Sounds.opening()
    }
    /** Ends it at once: the frame gone, the rail's rows in their places; the page is there already. */
    function skip() {
        if (!run.running) return
        run.stop()
        at = 1e9
        if (rail && railed) rail.drawnIn()
    }

    property bool railed: false
    property bool landed: false
    onAtChanged: {
        if (!run.running) return
        if (!railed && at >= leaveAt) { railed = true; if (rail) rail.drawIn() }
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
    readonly property real frameAlpha: 0.97
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
    // Saturn's: the frame opens as a film's bars do, an amber line where they part.
    Repeater {
        model: root.kind === "cut" ? 2 : 0
        delegate: Rectangle {
            id: half
            required property int index
            width: root.width
            height: Math.ceil(root.height / 2) + 1
            y: (half.index === 0 ? -1 : 1) * root.soft(root.going) * root.height / 2 + (half.index === 0 ? 0 : root.height / 2)
            color: Theme.tint(root.frame, root.frameAlpha)
            Rectangle {
                width: parent.width; height: 2
                y: half.index === 0 ? parent.height - height : 0
                color: Theme.hudAccent
                opacity: root.going > 0 ? 1 - root.going : 0
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
                GradientStop { position: Math.min(0.998, inkFrame.e + 0.008); color: Theme.tint(Theme.hud.seal || Theme.hudAccent, inkFrame.e > 0 ? 0.9 : root.frameAlpha) }
                GradientStop { position: Math.min(0.999, inkFrame.e + 0.03); color: Theme.tint(root.frame, root.frameAlpha) }
                GradientStop { position: 1; color: Theme.tint(root.frame, root.frameAlpha) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // Terra's: a sweep of sunlight runs across and takes the frame with it.
    Shape {
        id: sunFrame
        visible: root.kind === "sweep"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Where the light's edge is across the window, 0 to 1 (from a little before to a little past).
        readonly property real e: -0.15 + 1.3 * root.soft(root.going)
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.width; y2: 0
                GradientStop { position: 0; color: Theme.tint(Theme.artBright, 0) }
                GradientStop { position: Math.max(0.001, Math.min(0.996, sunFrame.e - 0.12)); color: Theme.tint(Theme.artBright, 0) }
                GradientStop { position: Math.max(0.002, Math.min(0.997, sunFrame.e)); color: Qt.tint(Theme.tint(Theme.artBright, 0.75), Theme.tint(Theme.hudPrimary, 0.35)) }
                GradientStop { position: Math.max(0.003, Math.min(0.998, sunFrame.e + 0.01)); color: Theme.tint(root.frame, root.frameAlpha) }
                GradientStop { position: 1; color: Theme.tint(root.frame, root.frameAlpha) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
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
        readonly property real gone: root.kind === "ink" ? root.soft(root.going) : Math.min(1, root.going * 2.5)
        x: root.cx - width / 2
        y: root.cy - glyph.height / 2 - (root.kind === "sweep" ? root.soft(title.gone) * Theme.s3 : 0)
        width: Math.max(glyph.width, name.implicitWidth)
        height: glyph.height + Theme.s3 + name.height
        opacity: 1 - title.gone
        scale: 1 - 0.06 * root.sharp(title.gone)
        Design.SlamText {
            id: glyph
            x: (title.width - width) / 2
            text: root.word
            // A kanji as large as the window allows; a word, each character a little smaller.
            size: Math.round(Math.max(96, Math.min(root.height * 0.36, root.width * (root.word.length > 1 ? 0.6 / root.word.length : 0.28), 300)))
            at: root.at
            tear: root.tear
        }
        Row {
            id: name
            x: (title.width - width) / 2
            y: glyph.height + Theme.s3
            spacing: Theme.s3
            // After the hit, as a title card's line comes.
            opacity: Math.max(0, Math.min(1, (root.at - Theme.hit - Theme.flicker) / Math.max(1, Theme.hit)))
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
                color: Theme.artAccent
            }
        }
    }
}

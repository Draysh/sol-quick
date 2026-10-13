pragma Singleton
import QtQuick
import QtCore
// For SolBackend (a C++ type of this module, which the folder alone doesn't bring).
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    Sol · Yozora (夜空) tokens. Every Sol app uses these and nothing else:
    an anime film's sky under each world's grade, glass panels with one
    corner cut, a title serif, HUD capitals and figures, a sans for
    reading, and colour from the world's own flavour. `docs/yozora.md` in
    the workspace explains the look.
    At the end, the small rules every control shares: when a thing is on
    screen, a wheel's step, the page around an item, who has the keys.
*/
QtObject {
    id: theme

    // ---- The sky ---------------------------------------------------------------
    // In one file for every Sol app on the computer (~/.config/sol/device.conf).
    property Settings prefs: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/sol/device.conf"
        category: "appearance"
        property string motion: "full"
    }
    /**
        Less motion, on this device (Settings → On this device, for every Sol
        app here): moments are short and still, nothing drifts across them.
    */
    readonly property bool calm: SolBackend.calm || prefs.motion === "less"
    function setCalm(on) { prefs.motion = on ? "less" : "full" }
    /** The hour, kept by Worlds' clock. */
    readonly property int hour: Worlds.now.getHours()

    /** The sky: the flavour's ground, deep and never pure black, so what is raised off it shows. */
    readonly property color night: hud.ground
    /** The pane, where the work is. */
    readonly property color space: hud.ground
    /** The chrome (sidebar, the band and toolbars over a page): the ground, a little see-through over the still; a light flavour's frost. */
    readonly property color deep: light ? tint(hud.glass, 0.92) : tint(hud.ground, 0.86)
    /** A panel raised off the pane (a card): the flavour's glass. */
    readonly property color raised: hud.glass
    readonly property color raisedTop: tint(hud.glass, Math.min(1, hud.glass.a + 0.06))
    // Corners are square: a panel cuts one at 45° instead (hudCut). The names stay, so a
    // thing inside another still says which corner it would follow.
    /** Small marks: a checkbox, a skeleton's line, a chart's bar, the pairing code's box. */
    readonly property int radiusS: 0
    /** Controls and pictures in lists: a button, a chip, the way back, a menu row's light, a poster, a cover, a still. */
    readonly property int radiusM: 0
    /** A panel's corners: a card, and the glass under a menu, a list, a hint, a notice and the palette. */
    readonly property int radius: 0
    /** A big surface on its own: the dialog, the shortcuts sheet, the desktop widget. */
    readonly property int radiusL: 0
    /** The one round thing: the navigator's speech, a manga bubble. */
    readonly property int radiusSpeech: 14
    /** The colour marks are drawn in over glass (a hover, a skeleton, a field's line): light over dark glass, dark ink over a light flavour's. Overlays use it at a low alpha. */
    readonly property color ink: light ? hud.ground : "#ffffff"
    /** The hairlines' and surfaces' colour: the flavour's edge. */
    readonly property color edgeInk: hud.edge
    /** What dims the window under a dialog and tints glass: the ground. */
    readonly property color veil: hud.ground
    /** The tint glass blurred live lays over the page (a menu, the palette, a dialog): the ground, or a light flavour's frost. */
    readonly property color frost: light ? Qt.rgba(hud.glass.r, hud.glass.g, hud.glass.b, 1) : hud.ground

    readonly property color surface: tint(edgeInk, 0.06)
    readonly property color surfaceHover: tint(edgeInk, 0.12)
    readonly property color line: tint(edgeInk, 0.2)
    readonly property color lineMid: tint(edgeInk, 0.32)
    readonly property color lineStrong: tint(edgeInk, 0.55)
    readonly property color tick: tint(ink, 0.6)

    /** Words on glass. A light flavour's are dark ink; words on the still itself are the `art…` tokens. */
    readonly property color text: hud.text
    readonly property color textBright: light ? hud.bright : "#ffffff"
    readonly property color textValue: Qt.tint(hud.quiet, tint(hud.text, 0.5))
    readonly property color textQuiet: hud.quiet
    readonly property color textFaint: hud.faint
    /** What is drawn on something filled in the words' colour (a ticked box, selected text): the ground, or white on a light flavour's dark ink. */
    readonly property color textInverse: light ? "#ffffff" : space
    /** A heading in the world's light: a panel's title. */
    readonly property color textWorld: hud.accent

    /** What can't be taken back, and what went wrong; what went right. Deeper on a light flavour's glass, so they keep 4.5:1. */
    readonly property color danger: light ? "#c8361f" : "#ff6b5a"
    readonly property color dangerText: light ? "#b3301b" : "#ff8a7a"
    readonly property color ok: light ? "#1d7442" : "#8ee6b0"

    /** The current world's colour, set by Shell. Glow and icons only. */
    property color world: "#f2f2f2"
    /** The current world's light for small marks (a glyph, the current section's light, the chosen row). */
    readonly property color accent: world
    /** The window is up and the person is there: things that breathe or drift run only then. Set by AppWindow. */
    property bool alive: true
    /** How many things are still taking their place (arriving, loading): a picture for review waits until none is. Settling counts them. */
    property int settling: 0

    /** `color` at `alpha`. */
    function tint(c, alpha) { const k = typeof c === "string" ? Qt.color(c) : c; return Qt.rgba(k.r, k.g, k.b, alpha) }

    // ---- Type ---------------------------------------------------------------
    // The kit's fonts are made known to the app as it starts (`src/fonts.rs`), with the face that
    // draws what each lacks: Japanese in the sans, the HUD face or the mono is Zen Kaku Gothic New.
    /** Reading: words and sentences, in the sans (its Japanese in Zen Kaku Gothic New). */
    readonly property string font: "Outfit"
    /** Japanese words to read closely (a card's word, a kana, a reading): a quiet mincho. */
    readonly property string fontJp: "Shippori Mincho"
    /** Japanese set in a sans on its own, for a block of it (lyrics, a line said). */
    readonly property string fontJpSans: "Zen Kaku Gothic New"
    /** Titles, and every Japanese tag beside a HUD label: a heavy Japanese serif. Set its punctuation with `titleFeatures`. */
    readonly property string fontTitle: "Shippori Mincho B1"
    /** HUD capitals and figures: a squared sans, cut like a game's menus. */
    readonly property string fontHud: "Chakra Petch"
    /** The face for words set in capitals (labels, buttons, tabs, quiet facts): the HUD face. */
    readonly property string fontCaps: fontHud
    /** Tabular numbers only, where digits must stand in columns (a timer, a frequency): the mono face. */
    readonly property string fontMono: "JetBrains Mono"
    /** A title's OpenType features: proportional Japanese punctuation (、。「」 take half a square). */
    readonly property var titleFeatures: ({ "palt": 1 })
    /** Whether `s` has Japanese in it (kana or kanji): it is never set in capitals or tracked. */
    function hasJp(s) { return /[\u3040-\u30ff\u3400-\u9fff\uff66-\uff9f]/.test(String(s)) }
    /**
        Whether `s` is set in capitals: a label of one to three words with no
        Japanese, or a HUD line of such labels joined by " · " ("7 DUE · 0 NEW ·
        12 CARDS"). Anything longer is set as written, in the sans.
    */
    function capsFor(s) {
        const t = String(s)
        return !hasJp(t) && t.split(" · ").every(part => part.split(/\s+/).filter(w => /[A-Za-z]/.test(w)).length <= 3)
    }

    readonly property int weightDisplay: 200
    readonly property int weightValue: 300
    readonly property int weightName: 400
    readonly property int weightLabel: 600

    readonly property int textXs: 11
    readonly property int textS: 13
    readonly property int textM: 15
    readonly property int textL: 19
    readonly property int textXl: 34
    readonly property int text2xl: 56

    readonly property real trackRows: 0.05
    readonly property real trackName: 0.08
    readonly property real trackDisplay: 0.1
    readonly property real trackCaps: 0.12
    readonly property real trackLabel: 0.14

    /** Letter spacing in pixels for a tracking in em at a size. */
    function track(em, size) { return em * size }

    // ---- The worlds' flavours ---------------------------------------------------
    /** The window's world, by id: the app's own, set by the Shell (the gallery's changes as it shows each). */
    property string worldId: SolBackend.world
    /** The world whose flavour the window wears: the one `SOL_FLAVOUR` names (the gallery's pictures), else the window's (a moon's, its planet's). */
    readonly property string lookWorld: SolBackend.flavour !== "" ? SolBackend.flavour : worldId
    /**
        Each planet's flavour (its moons take their planet's), for the
        look: `ground` (the dark under everything, and words on a light),
        `glass` (a panel's tint) and `edge` (its hairline, used at a few
        alphas), `accent` and `second` (its two lights), `text`, `quiet`,
        `faint` (words on glass), `sky` (the drawn sky without a still, top
        to bottom), `hold` (how much of the ground lies over a whole still)
        and `grade` (laid over it, top to bottom, as [r, g, b, a]), `shade`
        (the left shade's strength), `pool` (how much deeper it lies round
        the title, top left, on a bright still), `stars`, `rain` (streaks of rain over
        the still, 0 to 1), `haze` (a neon glow low on the right), `jp`
        (its name in Japanese) and `glyph` (one kanji, the rail's diamond),
        `navigator` (the name of the character who says the page's line),
        `motif` (what its panels carry: "dusk", "shrine", "neon" or
        "summer"), `bubble` (the paper of the navigator's speech, written
        on in the `ground`), `blush` (the warm light over the navigator when
        it cheers), `face` (where the face is on its portrait, as fractions
        across and down, for a close crop: the head chip), `seal`
        (Mercury's vermilion), `paper` and `ink` (Terra's notebook) and
        `film` (whose stills), `frame` (how its stills are framed, `[zoom,
        across]`: a little closer, and the part shown from left 0 to right 1,
        so their subject stands clear of a first page's title; whole and
        centred without one) and `letterbox` (a film's black bars over and
        under a still shown as a frame: a PageHead's feature, a title's
        backdrop), `torii` (a band's foot a vermilion rule, a gate's beam
        and posts under its Japanese title) and `tategaki` (a sparse
        page's big title written down, as a hanging scroll), `signs` (the
        first page's line down the right as a lit `NeonSign`) and `chroma`
        (big titles with a red and a cyan edge, `ChromaText`). A day
        flavour (Terra's noon) has `light` glass: frosted white, its words
        (`text`, `quiet`, `faint`, and `bright` the strongest) dark ink, its
        `edge` dark enough for hairlines on white; words on the still itself
        stay white (the `art…` tokens: `artAccent` and `artSecond` are its
        lights there), `dim` is the colour its shade, pool and vignette are
        laid in (the deep of the sky rather than the ground), and `primary`
        fills the primary button when the accent is too deep for words on it.
        A moon may have a flavour of its own (Luna's evening): its pages
        wear it in its planet's window.
    */
    readonly property var yozoraLooks: ({
        saturn: {
            id: "saturn", navigator: "Suzume", motif: "dusk", film: "Suzume", jp: "土星", glyph: "土",
            ground: "#0b0e2a", glass: Qt.rgba(9 / 255, 11 / 255, 34 / 255, 0.62), edge: "#c8d0ff",
            accent: "#ffc07e", second: "#7fe3ff", seal: "#f07a6a", bubble: "#f4f2ff", blush: "#ffb08a", face: [0.42, 0.36],
            text: "#f2f4ff", quiet: "#c8d0ff", faint: "#8e98d8",
            sky: ["#0b0e2a", "#2b2468", "#8a3c7e", "#f07a6a", "#ffc07e"], stars: true, shade: 0.78,
            // Dusk: indigo overhead, the horizon left warm (amber over the still's own glow), night at the foot.
            hold: 0.2, frame: [1.22, 0], letterbox: true,
            grade: [[0.17, 0.14, 0.41, 0.34], [1, 0.66, 0.4, 0.16], [0.17, 0.14, 0.41, 0.46], [0.043, 0.055, 0.165, 0.86], [0.043, 0.055, 0.165, 0.96]]
        },
        mercury: {
            id: "mercury", navigator: "Mitsuha", hold: 0.3, motif: "shrine", film: "Your Name", jp: "水星", glyph: "水",
            ground: "#07081c", glass: Qt.rgba(7 / 255, 8 / 255, 28 / 255, 0.66), edge: "#ffe6d6",
            accent: "#ff8fa8", second: "#ffd58a", seal: "#e2412e", washi: "#fff4da", bubble: "#fff4da", blush: "#ff9fb4", face: [0.5, 0.42],
            text: "#fff8ee", quiet: "#e9dccf", faint: "#a99a9e",
            sky: ["#05061a", "#121848", "#2e1e4e", "#7a2a3c", "#c94a35"], stars: true, shade: 0.8,
            torii: true, tategaki: true,
            grade: [[0.89, 0.25, 0.18, 0.12], [0.03, 0.03, 0.11, 0.3], [0.03, 0.03, 0.11, 0.5], [0.027, 0.031, 0.11, 0.86], [0.027, 0.031, 0.11, 0.96]]
        },
        neptune: {
            id: "neptune", navigator: "Lucy", hold: 0.34, motif: "neon", film: "Weathering With You", jp: "海王星", glyph: "海",
            ground: "#0a1426", glass: Qt.rgba(4 / 255, 9 / 255, 22 / 255, 0.68), edge: "#8fe7ff",
            accent: "#ff4a5a", second: "#8fe7ff", seal: "#ff4a5a", bubble: "#eef6ff", blush: "#ff8aa8", face: [0.52, 0.52],
            text: "#eef6ff", quiet: "#b9cbe8", faint: "#7590b4",
            sky: ["#040814", "#0a1730", "#14284f", "#3a1c46", "#a32a48"], stars: false, shade: 0.8, rain: 1, haze: "#ff4a5a", signs: true, chroma: true,
            grade: [[0.56, 0.9, 1, 0.1], [0.04, 0.08, 0.15, 0.42], [0.04, 0.08, 0.15, 0.56], [0.039, 0.078, 0.149, 0.86], [0.039, 0.078, 0.149, 0.96]]
        },
        // Noon: frosted white glass with dark ink on it (ramune blue its light, sunflower its
        // primary), the sky lifted with a little summer haze, the shade the deep of the sky.
        terra: {
            id: "terra", navigator: "Hina", hold: 0, motif: "summer", film: "Weathering With You and 5 Centimeters per Second", jp: "地球", glyph: "地",
            light: true, ground: "#14233f", dim: "#0a3a85", glass: Qt.rgba(246 / 255, 250 / 255, 1, 0.8), edge: "#1b4a86",
            accent: "#1157ab", second: "#3b3f9e", primary: "#ffb81c", artAccent: "#ffe07a", artSecond: "#fff3a6",
            seal: "#9fc4f0", paper: "#fbf8ee", ink: "#14233f", bubble: "#fbf8ee", blush: "#ffc9a0", face: [0.52, 0.44],
            bright: "#0b1730", text: "#10203a", quiet: "#33476a", faint: "#3f5378",
            sky: ["#1f6fd6", "#4a90e2", "#8fbdf0", "#cfe4fa", "#eef6ff"], stars: false, shade: 0.2, pool: 0.4,
            grade: [[1, 1, 1, 0.16], [0.86, 0.93, 1, 0.1], [0.86, 0.93, 1, 0.04], [0.8, 0.9, 1, 0.1], [0.78, 0.88, 1, 0.18]]
        },
        // Luna: Terra after sunset, under the moon: indigo glass, the moon's yellow its light.
        luna: {
            id: "luna", navigator: "Hina", hold: 0.16, motif: "summer", film: "5 Centimeters per Second", jp: "月", glyph: "月",
            ground: "#0b0d2a", glass: Qt.rgba(12 / 255, 14 / 255, 46 / 255, 0.66), edge: "#dcd8ff",
            accent: "#ffe08a", second: "#b7c2ff", seal: "#ffe08a", bubble: "#fbf6e6", blush: "#ffc9a0", face: [0.52, 0.44],
            text: "#f7f5ff", quiet: "#d6d3f2", faint: "#a4a1cf",
            sky: ["#05061a", "#0d1238", "#1c2160", "#2b2f74", "#3d3a86"], stars: true, shade: 0.72,
            grade: [[0.05, 0.06, 0.2, 0.16], [0.05, 0.06, 0.2, 0.1], [0.05, 0.06, 0.2, 0.3], [0.043, 0.051, 0.165, 0.72], [0.043, 0.051, 0.165, 0.9]]
        }
    })
    /** A world's flavour: its own (a moon may have one), or its planet's for a moon; Saturn's for any other. */
    function yozoraOf(id) {
        if (yozoraLooks[id]) return yozoraLooks[id]
        const w = Worlds.get(id)
        const planet = w && w.parent ? w.parent : id
        return yozoraLooks[planet] || yozoraLooks.saturn
    }
    /** The planet a world belongs to: its own id for a planet. Moons share their planet's stills and navigator. */
    function planetOf(id) {
        const w = Worlds.get(id)
        return w && w.parent ? w.parent : id
    }
    /** Every world's name in Japanese, a moon's too: "タイタン". */
    readonly property var yozoraNames: ({ sol: "太陽", terra: "地球", luna: "月", saturn: "土星", titan: "タイタン", mercury: "水星", neptune: "海王星", triton: "トリトン" })
    function jpOf(id) { return yozoraNames[id] || yozoraOf(id).jp }
    /** The flavour this window wears (see `yozoraOf`). */
    readonly property var hud: yozoraOf(lookWorld)
    /** Its name: "saturn", "mercury", "neptune" or "terra". */
    readonly property string flavour: hud.id
    /** The ground under everything, and the drawn sky without a still, top to bottom. */
    readonly property color dusk: hud.ground
    readonly property var duskSky: hud.sky
    /** A glass panel's tint and its hairline. */
    readonly property color hudGlass: hud.glass
    readonly property color hudLine: tint(hud.edge, 0.2)
    /** The flavour's two lights: its accent (the rail's bar, a primary, a panel's brackets) and a second for what comes second. */
    readonly property color hudAccent: hud.accent
    readonly property color hudSecond: hud.second
    /** Saturn's two lights, by name: amber and cyan. */
    readonly property color hudAmber: "#ffc07e"
    readonly property color hudCyan: "#7fe3ff"
    /** HUD words on glass: bright, held back, and faint (white over dark glass; a light flavour's ink). */
    readonly property color hudText: light ? hud.bright : "#ffffff"
    readonly property color hudQuiet: light ? hud.quiet : Qt.rgba(1, 1, 1, 0.72)
    readonly property color hudFaint: light ? hud.faint : Qt.rgba(1, 1, 1, 0.45)
    /** Whether the flavour's glass is light (Terra's noon): words on it are dark, words on the still stay white. */
    readonly property bool light: !!hud.light
    /**
        Words and marks on the still itself, not on glass (a first page's
        title card, a sparse page's big title, the Sky's names, the moon
        links under a title): always light, so over a dark flavour the same
        as the words on glass, and over a light one white with the flavour's
        own lights for the art (`artAccent`, `artSecond`).
    */
    readonly property color artBright: "#ffffff"
    readonly property color artText: light ? "#ffffff" : text
    readonly property color artQuiet: light ? Qt.rgba(1, 1, 1, 0.86) : textQuiet
    readonly property color artFaint: light ? Qt.rgba(1, 1, 1, 0.66) : textFaint
    readonly property color artAccent: hud.artAccent || hud.accent
    readonly property color artSecond: hud.artSecond || hud.second
    readonly property color artLine: light ? Qt.rgba(1, 1, 1, 0.3) : line
    /** The primary button's fill: the flavour's light, or its `primary` where that light is too deep for words on it. */
    readonly property color hudPrimary: hud.primary || hud.accent
    /** The corner a panel has cut away (45°), and the arm of its brackets. */
    readonly property int hudCut: 18
    readonly property int hudBracket: 12
    /** A HUD label's tracking: wide, for capitals of a few words. */
    readonly property real trackHud: 0.14
    readonly property int textHero: 112
    readonly property int textLede: 26
    readonly property int textFigure: 38
    /**
        The look's pictures on this computer (`~/.local/share/sol-yozora/`,
        fetched by the app as it starts when they are missing): the stills a
        world's pages stand on (`<planet>-ground-<n>.jpg`) and its navigator's
        portrait (`<planet>-mascot.jpg` or `.png`). Empty lists and "" until
        they are there; the list follows when they come.
    */
    readonly property var yozoraArt: { try { return JSON.parse(SolBackend.lookArt || "[]") } catch (e) { return [] } }
    function groundsOf(id) {
        const pre = "/" + yozoraOf(planetOf(id)).id + "-ground-"
        return yozoraArt.filter(f => f.indexOf(pre) >= 0).sort().map(f => fileUrl(f))
    }
    /** A moon's own stills (`<moon>-ground-<n>.jpg`: Luna's evening), which its pages stand on instead of its planet's; [] when it has none. */
    function ownGroundsOf(id) {
        const pre = "/" + id + "-ground-"
        return yozoraArt.filter(f => f.indexOf(pre) >= 0).sort().map(f => fileUrl(f))
    }
    function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/") }
    function mascotOf(id) {
        const name = "/" + yozoraOf(planetOf(id)).id + "-mascot."
        const f = yozoraArt.find(p => p.indexOf(name) >= 0)
        return f ? fileUrl(f) : ""
    }

    // ---- Spacing steps -----------------------------------------------------
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 16
    readonly property int s4: 24
    readonly property int s5: 40
    readonly property int s6: 64
    readonly property int s7: 112

    /** The pane's side margin for a pane `width` wide: content sits close to its chrome. */
    function margin(width) { return Math.max(16, Math.min(40, width * 0.03)) }

    readonly property int target: 44
    readonly property int control: 36
    readonly property int sidebar: 228
    readonly property int rail: 60
    readonly property int navHeight: 56

    // ---- Motion ------------------------------------------------------------
    // Every animation takes its length and its curve from here; nothing else
    // in the kit or a world writes a number of milliseconds or an `Easing`
    // (the QML lint warns of one). Less motion (`calm`) is each component's
    // own choice: it shortens or skips what it plays.
    //
    // The arrivals: a snap for a press, a flicker for one step of a glitch
    // or a shake, a lock for ticks and switches, a fade for text and colour,
    // a settle for something taking its place, a turn for a page arriving,
    // a count for a figure counting up, a rise for a body appearing and a
    // wash for a colour coming over the whole window. Things that arrive
    // together arrive a stagger apart.
    // For pictures taken with SOL_SHOT_CALM, all of them nothing: everything is in its place at once.
    /** A press: a button or a row giving under the pointer, and a mark following something live (a level). */
    readonly property int snap: SolBackend.shotCalm ? 0 : 50
    /** One step of a glitch or a shake. */
    readonly property int flicker: SolBackend.shotCalm ? 0 : 50
    readonly property int lock: SolBackend.shotCalm ? 0 : 120
    readonly property int fade: SolBackend.shotCalm ? 0 : 240
    readonly property int settle: SolBackend.shotCalm ? 0 : 420
    /** A page turning: the page and its head coming in as the Shell opens it. */
    readonly property int turn: SolBackend.shotCalm ? 0 : 420
    /** A figure counting up to its value as it arrives (Display, a Sheet's numbers). */
    readonly property int count: SolBackend.shotCalm ? 0 : 720
    readonly property int rise: SolBackend.shotCalm ? 0 : 900
    /** A line said: the navigator's words typed into its speech, the Japanese, then the English. */
    readonly property int speak: SolBackend.shotCalm ? 0 : 900
    /** A colour coming over the whole window: the world's surface changing, Luna's veil deepening. */
    readonly property int wash: SolBackend.shotCalm ? 0 : 2400
    readonly property int stagger: SolBackend.shotCalm ? 0 : 28
    // What plays for as long as something lasts, so never nothing: each runs
    // only while it is needed and `alive`. A sweep for one pass of a busy
    // mark (a line's sweep, a spinner's turn); a drift for what drifts
    // (clouds, a slow glow, a breath); a crossing for the comet's way over
    // the band; a scene for a moment (half of it with less motion).
    readonly property int sweep: 1400
    readonly property int drift: 12000
    readonly property int crossing: 14000
    readonly property int scene: 5200
    /** How long the page glides for a wheel's notch, and for a touchpad's step (or the spring back past an end). */
    readonly property int notchGlide: 240
    readonly property int touchGlide: 80

    // The curves, for an animation's `easing` (`easing: Theme.easeOut`).
    /** A plain ease: cubic-bezier(0.2, 0.7, 0.2, 1). */
    readonly property easingCurve ease: ({ type: Easing.BezierSpline, bezierCurve: [0.2, 0.7, 0.2, 1, 1, 1] })
    /** Fast out, long soft landing: how things settle. cubic-bezier(0.16, 1, 0.3, 1). */
    readonly property easingCurve easeOut: ({ type: Easing.BezierSpline, bezierCurve: [0.16, 1, 0.3, 1, 1, 1] })
    /** Out a little past its place and back: a stamp landing, a tick swelling. cubic-bezier(0.34, 1.56, 0.64, 1), about a tenth over. */
    readonly property easingCurve spring: ({ type: Easing.BezierSpline, bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1] })
    /** Slow at both ends: there and back (a breath, a level's beat), a colour washing over, a sound fading. */
    readonly property easingCurve easeInOut: ({ type: Easing.InOutSine })

    /** How late the `i`th of a list may arrive: a stagger each, never past 400 ms. */
    function delay(i) { return Math.min(i * stagger, 400) }

    /**
        Runs `arrival` once `item` is on screen in the Flickable it scrolls
        in: at once when it already is (or nothing scrolls it), else when it
        is scrolled to, or the window grows, or what is above it shrinks.
        `arrival(waited)` says whether it had to wait. Returns a function
        that forgets it, for when the item goes first.
    */
    function whenSeen(item, arrival) {
        const f = flickableOf(item)
        const seen = () => f.height <= 0 || item.mapToItem(f.contentItem, 0, 0).y < f.contentY + f.height + 40
        if (!f || seen()) { arrival(false); return () => { } }
        const changes = [f.contentYChanged, f.heightChanged, f.contentHeightChanged, item.yChanged]
        let waiting = true
        let check = null
        const forget = () => { if (!waiting) return; waiting = false; for (const s of changes) s.disconnect(check) }
        check = () => { if (seen()) { forget(); arrival(true) } }
        for (const s of changes) s.connect(check)
        return forget
    }

    /** The nearest Flickable `item` scrolls in (the page's, in a Screen), or null. */
    function flickableOf(item) {
        let f = item ? item.parent : null
        while (f && !(f.hasOwnProperty("contentY") && f.hasOwnProperty("contentHeight") && f.hasOwnProperty("contentItem"))) f = f.parent
        return f
    }

    /**
        Keeps `view` (a ListView or GridView inside `item`, as tall as all
        its rows) showing the part of `item` that is in sight in the page's
        Flickable, so the page scrolls it and only what shows is made:
        `view` is one window tall, moved down `item` as the page scrolls
        (past its end once it has scrolled by), its own `contentY`
        following. Returns a function that lets go.
    */
    function scrollWith(item, view) {
        const f = flickableOf(item)
        // Where the window starts depends on the page's scroll and where `item` sits, never on
        // how tall `item` is: a list whose height is still being reckoned can't chase itself.
        const place = () => {
            if (!f || f.height <= 0) { view.y = 0; view.height = Math.max(item.height, 1); view.contentY = view.originY; return }
            const y = Math.max(0, f.contentY - item.mapToItem(f.contentItem, 0, 0).y)
            if (view.height !== f.height) view.height = f.height
            if (Math.abs(view.y - y) > 0.25) view.y = y
            if (Math.abs(view.contentY - (view.originY + y)) > 0.25) view.contentY = view.originY + y
        }
        const changes = f ? [f.contentYChanged, f.heightChanged, f.contentHeightChanged, item.yChanged, view.originYChanged, view.countChanged] : [item.heightChanged, view.countChanged]
        for (const s of changes) s.connect(place)
        place()
        return () => { for (const s of changes) s.disconnect(place) }
    }

    // ---- Rules the controls share ----------------------------------------------
    /** The page (a Screen) `item` is on, or null: for something inside a page that hands it a wheel event. */
    function screenOf(item) {
        for (let it = item ? item.parent : null; it; it = it.parent) {
            const s = it as Design.Screen
            if (s) return s
        }
        return null
    }

    /**
        What a wheel event moves: `{ notched, x, y }`. A mouse wheel has no
        scroll phase and turns in notches (`angleDelta`, 120 a notch, finer
        on a high-resolution wheel): `notched`, and `x`, `y` are `notch`
        pixels a notch. A touchpad has phases and moves by its own pixels
        (`pixelDelta`). Qt on Wayland fills `pixelDelta` for a wheel too, a
        few pixels a notch, so only the phase tells them apart. Positive is
        up and to the left, as Qt has it: subtract it from `contentY`/`contentX`.
    */
    function wheel(event, notch) {
        const notched = event.phase === Qt.NoScrollPhase || (event.pixelDelta.x === 0 && event.pixelDelta.y === 0)
        return notched
            ? { notched: true, x: event.angleDelta.x / 120 * notch, y: event.angleDelta.y / 120 * notch }
            : { notched: false, x: event.pixelDelta.x, y: event.pixelDelta.y }
    }

    /** Scrolls `flick` the least that shows the band from `top`, `height` tall (the row the keys are on). */
    function keepInView(flick, top, height) {
        if (top < flick.contentY) flick.contentY = top
        else if (top + height > flick.contentY + flick.height) flick.contentY = top + height - flick.height
    }

    /** Whether `item` (the one with the keys) is a field taking text: the keys are its, not the page's. A read-only one isn't. */
    function typing(item) {
        const input = item as TextInput, edit = item as TextEdit
        return (!!input && !input.readOnly) || (!!edit && !edit.readOnly)
    }

    /** Whether a child is a Repeater, which lays nothing out itself: the containers that place their children skip it. */
    function isRepeater(item) { return !!(item as Repeater) }
}

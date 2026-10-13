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
    /**
        Titles, and every Japanese tag beside a HUD label: the flavour's own
        face (its `title`: Corporate Logo for Saturn, Yuji Syuku's brush for
        Mercury, Makinas for Neptune, Keifont for Terra and Luna), each
        world's app carrying its own (`sol_quick::add_font`); where the app
        doesn't carry it, `fontDisplay`. Drawn in `weightTitle`, never
        thicker, and its punctuation set with `titleFeatures`.
    */
    readonly property string fontTitle: Qt.fontFamilies().indexOf(hud.title) >= 0 ? hud.title : fontDisplay
    /** The weight a title face is drawn in: its one weight (Corporate Logo's is bold, the others' regular), so it is never thickened. */
    readonly property int weightTitle: fontTitle === fontDisplay ? Font.Bold : Font.Normal
    /**
        The smallest size each title face stays clean at, by family: under it
        Yuji Syuku's brush clots (覚 at 18 px) and Makinas' hairlines run
        together (聴 under 18 px), so a smaller title, tag or line takes
        `fontDisplay` instead (`titleFace`). Corporate Logo and Keifont read
        well small and have none.
    */
    readonly property var titleFloors: ({ "Makinas": 18, "Yuji Syuku": 20 })
    /** The smallest size the flavour's title face is set at (0: any size). */
    readonly property int titleFloor: titleFloors[fontTitle] || 0
    /** The face for title words at `size` pixels: the flavour's title face from `titleFloor` up, else `fontDisplay`. */
    function titleFace(size) { return size >= titleFloor ? fontTitle : fontDisplay }
    /** The weight for `titleFace(size)`: that face's one weight. */
    function titleWeight(size) { return titleFace(size) === fontDisplay ? Font.Bold : Font.Normal }
    /** Subtitles (the English line under a big title, a PageHead's English title) and big figures, in every app: Corporate Logo Bold. */
    readonly property string fontDisplay: "Corporate Logo ver3"
    /** HUD capitals and figures: a squared sans, cut like a game's menus. */
    readonly property string fontHud: "Chakra Petch"
    /** The face for words set in capitals (labels, buttons, tabs, quiet facts): the HUD face. */
    readonly property string fontCaps: fontHud
    /** Tabular numbers only, where digits must stand in columns (a timer, a frequency): the mono face. */
    readonly property string fontMono: "JetBrains Mono"
    /** A title's OpenType features: proportional Japanese punctuation (、。「」 take half a square) in a face that has it; the title faces set them in a full square, or (Corporate Logo) are cut proportional. */
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
    /** The app's own world, whatever page is open ("" while `SOL_FLAVOUR` dresses it in another's). */
    readonly property string appWorld: SolBackend.flavour !== "" ? "" : SolBackend.world
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
        "summer"), `bubble` (the glass of the navigator's speech, nearly
        opaque, written on in `text` and `quiet` inside an `edge` outline), `blush` (the warm light over the navigator when
        it cheers), `face` (where the face is on its portrait, as fractions
        across and down, and how close the frame comes, 1 unless given: a
        whole figure, a cut-out, wants about 1.7; the head chip comes closer
        again), `seal`
        (Mercury's vermilion), `paper` and `ink` (Terra's notebook) and
        `film` (whose stills), `frame` (how its stills are framed, `[zoom,
        across]`: a little closer, and the part shown from left 0 to right 1,
        so their subject stands clear of a first page's title; whole and
        centred without one) and `letterbox` (a film's black bars over and
        under a still shown as a frame: a PageHead's feature, a title's
        backdrop) and `tategaki` (a sparse
        page's big title written down, as a hanging scroll), `signs` (the
        first page's line down the right as a lit `NeonSign`) and `chroma`
        (big titles with a red and a cyan edge, `ChromaText`), `title` (its
        title face, `fontTitle`), `openingName` (the opening slams in the
        world's whole name rather than its kanji), `opening` (its opening's
        own way, when not its page turn's: Luna's "moon") and `kanjiNumbers` (the sidebar's numbers
        in kanji in that face, 一, 二, 三, instead of 01, 02). A day
        flavour (Terra's noon) has `light` glass: frosted white, its words
        (`text`, `quiet`, `faint`, and `bright` the strongest) dark ink, its
        `edge` dark enough for hairlines on white; words on the still itself
        stay white (the `art…` tokens: `artAccent` and `artSecond` are its
        lights there), `dim` is the colour its shade, pool and vignette are
        laid in (the deep of the sky rather than the ground), and `primary`
        fills the primary button when the accent is too deep for words on it.
        A moon may have a flavour of its own (Luna's evening): its pages
        wear it in its planet's window.
        A flavour with an `impact` colour (Neptune's, Mercury's, Terra's, Luna's) lands its main acts as
        impact frames in it (`Sol.impact`), holds its page turns on an
        eyecatch, plays its moments as title cards on its darkest ink (`cardInk`)
        split on its `slant` (in degrees), and draws its hits on twos
        (`steps`); its title card slams in `slam` where that isn't the impact colour.
        The SSS keys, each on its own (every flavour has them all): `duotone` grades
        the stills black into the light, as one colour (a `light` flavour's, its light into paper, `PaperTone`,
        and then the words on the still are ink: `paperArt`); `surface: "panel"`
        makes panels near-opaque with a hairline in the light instead of
        frosted glass; `outline` sets big English titles as stroke-only
        capitals in the HUD face that draw themselves on (`OutlineText`), with
        a page's number large beside them; `captions` writes HUD lines as
        lowercase captions (`neptune_music / albums`); `scaffold` stands the
        world's emblem huge and cropped behind the pages; `grid` draws the
        content's columns as faint hairlines in the light; `drawer` slides the palette in from the right as a flat panel of
        the light; `turn` names the page turn's way (and `tear` the curtain's one torn frame:
        a glitch, "bars", a film's bars slamming shut, "brush", a stroke of ink across it, "flare", a flare of
        sunlight, or "moon", a rip lit by the moon); `tag` is the world's word at the head of a caption
        when its role is too long for one (Terra's "terra_days"); `mincho` is the face long
        Japanese is set in, light (lyrics, a navigator's longer line); and
        `signature` is the navigator's name as a hand signs it (an SVG path in
        a box 320 by 150, `signatureLength` long when not about 780, drawn with a broad nib
        `signatureNib` wide when it has one, as a brush), written under the
        first page's character once a launch.
    */
    readonly property var yozoraLooks: ({
        saturn: {
            id: "saturn", navigator: "Suzume", title: "Corporate Logo ver3", motif: "dusk", film: "Suzume", jp: "土星", glyph: "土",
            // One hot amber on black and white, as SSS by applibot sets its pages: Suzume's stills graded black
            // into the amber, panels near-opaque with an amber hairline, no second colour.
            ground: "#090807", glass: Qt.rgba(10 / 255, 9 / 255, 8 / 255, 0.93), edge: "#efebe4",
            accent: "#ffa21f", second: "#ece8e1", seal: "#ffa21f", bubble: Qt.rgba(10 / 255, 9 / 255, 8 / 255, 0.93), blush: "#ffc98a", face: [0.53, 0.44],
            text: "#f6f4f0", quiet: "#c2beb6", faint: "#8f8a82",
            sky: ["#070605", "#0c0a08", "#16110b", "#2c1a07", "#5c3409"], stars: false, shade: 0.78,
            hold: 0.2, frame: [1.22, 0], letterbox: true, openingName: true,
            // The page turn is the amber curtain; its one torn frame is a film's black bars slamming shut.
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain", tear: "bars",
            mincho: "Noto Serif CJK JP",
            // Suzume's name as she signs it, one stroke in a box 320 by 150, about 835 long.
            signature: "M 70 38 C 58 26, 30 34, 38 52 C 44 66, 70 70, 66 92 C 62 114, 30 116, 24 102 C 40 112, 64 104, 80 84 C 78 96, 78 108, 86 106 C 94 104, 100 92, 104 82 C 102 96, 102 106, 110 104 C 116 102, 120 84, 128 82 C 136 80, 140 84, 132 92 C 126 98, 120 104, 130 104 C 140 104, 138 120, 130 132 C 122 142, 112 136, 124 124 C 132 116, 140 108, 148 100 C 150 96, 150 86, 152 82 C 152 96, 152 106, 160 104 C 168 102, 172 90, 176 82 C 174 96, 174 106, 182 104 C 186 98, 188 90, 190 82 C 190 90, 190 98, 190 104 C 192 90, 196 80, 202 80 C 208 80, 206 94, 206 104 C 208 90, 212 80, 218 80 C 224 80, 222 94, 224 104 C 232 104, 244 96, 244 88 C 244 80, 232 82, 232 92 C 232 104, 244 108, 256 100 C 268 96, 282 96, 292 100",
            signatureLength: 835,
            grade: [[0, 0, 0, 0.12], [0.02, 0.02, 0.02, 0.4], [0.02, 0.02, 0.02, 0.55], [0.035, 0.031, 0.027, 0.86], [0.035, 0.031, 0.027, 0.96]]
        },
        // Titan: Saturn's look in its moon's darker gold (its stills, sounds and navigator stay Saturn's).
        titan: {
            id: "saturn", navigator: "Suzume", title: "Corporate Logo ver3", motif: "dusk", film: "Suzume", jp: "タイタン", glyph: "土",
            ground: "#090807", glass: Qt.rgba(10 / 255, 9 / 255, 8 / 255, 0.93), edge: "#efebe4",
            accent: "#d9ab3e", second: "#ece8e1", seal: "#d9ab3e", bubble: Qt.rgba(10 / 255, 9 / 255, 8 / 255, 0.93), blush: "#f0d08a", face: [0.53, 0.44],
            text: "#f6f4f0", quiet: "#c2beb6", faint: "#8f8a82",
            sky: ["#070605", "#0c0a08", "#15120b", "#2a2108", "#54420c"], stars: false, shade: 0.78,
            hold: 0.2, frame: [1.22, 0], letterbox: true, openingName: true,
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain", tear: "bars",
            mincho: "Noto Serif CJK JP",
            grade: [[0, 0, 0, 0.12], [0.02, 0.02, 0.02, 0.4], [0.02, 0.02, 0.02, 0.55], [0.035, 0.031, 0.027, 0.86], [0.035, 0.031, 0.027, 0.96]]
        },
        mercury: {
            id: "mercury", navigator: "Mitsuha", title: "Yuji Syuku", hold: 0.3, motif: "shrine", film: "Your Name", jp: "水星", glyph: "水",
            // One hot vermilion on black and white, as SSS by applibot sets its pages: Your Name's stills graded
            // black into the vermilion, panels near-opaque with a vermilion hairline. The washi, the slips
            // and the seals stay paper and a hanko's own vermilion.
            ground: "#0a0706", glass: Qt.rgba(11 / 255, 8 / 255, 7 / 255, 0.93), edge: "#f2ebe6",
            accent: "#ff4d23", second: "#ede7e2", seal: "#e2412e", washi: "#fff4da", bubble: Qt.rgba(11 / 255, 8 / 255, 7 / 255, 0.93), blush: "#ff9a7a", face: [0.5, 0.42],
            text: "#f7f2ee", quiet: "#c4bcb6", faint: "#918987",
            sky: ["#070505", "#0c0807", "#170d0a", "#2e0f08", "#5e1a0b"], stars: false, shade: 0.8,
            tategaki: true, kanjiNumbers: true, openingName: true,
            // Its acts land as a flash of washi (a seal pressed), its moments are title cards in the vermilion,
            // cut on a gentle diagonal, a brush's.
            slant: 8, impact: "#fff4da", slam: "#ff4d23", cardInk: "#060404",
            // The page turn is the vermilion curtain; its one torn frame is a stroke of the brush across it.
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain", tear: "brush",
            mincho: "Noto Serif CJK JP",
            // Mitsuha's name as she signs it, one stroke in a box 320 by 150, about 1280 long, written with a brush's nib.
            signature: "M 30 110 C 38 82, 46 46, 54 36 C 62 28, 64 62, 64 104 C 68 70, 76 44, 84 38 C 92 34, 92 70, 92 104 C 96 98, 101 86, 106 74 C 106 88, 105 100, 112 104 C 118 106, 124 96, 128 86 C 132 70, 136 46, 138 32 C 136 60, 134 90, 138 102 C 142 108, 150 100, 154 90 C 156 86, 158 82, 162 78 C 172 88, 172 102, 160 104 C 156 104, 166 100, 176 92 C 178 88, 179 84, 180 80 C 178 96, 180 106, 188 104 C 194 102, 196 90, 198 80 C 196 96, 198 106, 206 104 C 214 96, 222 60, 222 40 C 222 26, 212 30, 212 50 C 212 70, 212 90, 212 104 C 216 88, 222 80, 228 80 C 236 80, 232 96, 236 104 C 244 104, 254 92, 258 80 C 250 74, 236 82, 238 94 C 240 106, 254 102, 258 82 C 258 96, 258 104, 266 104 C 282 104, 300 96, 304 86 C 306 74, 250 62, 140 64 C 124 64, 112 60, 108 54",
            signatureLength: 1281, signatureNib: 3.2,
            grade: [[0, 0, 0, 0.12], [0.02, 0.016, 0.014, 0.4], [0.02, 0.016, 0.014, 0.55], [0.039, 0.027, 0.024, 0.86], [0.039, 0.027, 0.024, 0.96]]
        },
        neptune: {
            id: "neptune", navigator: "Lucy", title: "Makinas", hold: 0.34, motif: "neon", film: "Weathering With You", jp: "海王星", glyph: "海",
            // One hot red on black and white, as SSS by applibot sets its pages: the stills graded black
            // into the red, panels near-opaque with a red hairline, no second colour.
            ground: "#07070a", glass: Qt.rgba(8 / 255, 8 / 255, 11 / 255, 0.93), edge: "#ececf2",
            accent: "#ff3040", second: "#e9e9ee", seal: "#ff3040", bubble: Qt.rgba(8 / 255, 8 / 255, 11 / 255, 0.93), blush: "#ff8a96", face: [0.55, 0.33, 1.7],
            text: "#f4f4f6", quiet: "#bcbcc4", faint: "#8a8a94",
            sky: ["#050507", "#0b0b0f", "#141218", "#2a0c10", "#5a0f16"], stars: false, shade: 0.8, rain: 1, haze: "#ff3040", openingName: true,
            // Its acts land in white-hot yellow, drawn on twos (the flash only: a title card slams in the red);
            // its title cards are cut on a 13° diagonal.
            slant: 13, impact: "#fff35c", slam: "#ff3040", cardInk: "#04040a", steps: true,
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain",
            mincho: "Noto Serif CJK JP",
            // Lucy's name as she signs it, one stroke in a box 320 by 150.
            signature: "M 56 70 C 66 48, 80 20, 92 15 C 101 12, 100 25, 92 36 C 78 56, 56 92, 46 110 C 41 119, 29 123, 28 116 C 28 107, 46 110, 58 112 C 66 113, 72 104, 78 94 C 82 88, 86 86, 85 93 C 82 104, 85 111, 93 106 C 99 101, 104 92, 108 85 C 105 98, 105 110, 113 108 C 119 106, 125 98, 131 90 C 135 84, 141 82, 141 88 C 137 82, 125 90, 125 102 C 125 112, 137 110, 147 100 C 153 94, 157 88, 161 84 C 157 96, 157 106, 165 104 C 171 102, 177 94, 183 84 C 179 104, 173 124, 161 138 C 151 148, 139 144, 149 132 C 163 116, 201 108, 261 100 C 275 98, 285 98, 293 100",
            grade: [[0, 0, 0, 0.12], [0.02, 0.02, 0.03, 0.4], [0.02, 0.02, 0.03, 0.55], [0.027, 0.027, 0.039, 0.86], [0.027, 0.027, 0.039, 0.96]]
        },
        // Noon on paper, as SSS by applibot sets its pages but in daylight: the stills graded ramune
        // blue into paper white, near-opaque white panels with a blue hairline, ink for the words.
        // Sunflower stays the stamp of today and the furin's strip.
        terra: {
            id: "terra", navigator: "Hina", title: "Keifont", hold: 0, motif: "summer", film: "Weathering With You and 5 Centimeters per Second", jp: "地球", glyph: "地",
            light: true, ground: "#14233f", dim: "#f6f8fb", glass: Qt.rgba(250 / 255, 251 / 255, 253 / 255, 0.95), edge: "#1b4a86",
            // On the still, small words in the light take a deeper blue, so they keep 4.5:1 over its blue shadows.
            accent: "#1468d8", second: "#2b416a", primary: "#1468d8", artAccent: "#0a3f94", artSecond: "#2b416a",
            seal: "#9fc4f0", paper: "#fbf8ee", ink: "#14233f", bubble: Qt.rgba(250 / 255, 251 / 255, 253 / 255, 0.96), blush: "#ffc9a0", face: [0.52, 0.44],
            bright: "#0b1730", text: "#10203a", quiet: "#33476a", faint: "#3f5378",
            sky: ["#c9dcf5", "#dce8f8", "#e9f0fa", "#f2f6fb", "#f6f8fb"], stars: false, shade: 0.5, pool: 0.55, openingName: true,
            // A caption's tag: Terra's role is long for one ("terra_days / tue_13_oct").
            tag: "terra_days",
            // Its acts land as a flash of ink (a stamp pressed), its moments are title cards of paper and blue.
            slant: 10, impact: "#14233f", slam: "#1468d8", cardInk: "#f6f8fb",
            // The page turn is a blue curtain; its one torn frame is a flare of sunlight across it.
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain", tear: "flare",
            mincho: "Noto Serif CJK JP",
            // Hina's name as she signs it, one stroke and the i's dot in a box 320 by 150, about 720 long.
            signature: "M 62 30 C 60 58, 54 90, 44 116 C 54 92, 78 76, 112 72 C 104 60, 110 42, 116 28 C 112 58, 106 88, 102 112 C 108 100, 116 90, 124 80 C 122 92, 120 104, 128 106 C 134 106, 138 98, 142 86 C 144 84, 142 100, 140 108 C 144 94, 150 82, 158 82 C 166 82, 162 100, 168 106 C 174 108, 184 100, 192 88 C 184 78, 166 84, 166 98 C 166 110, 184 106, 192 88 C 190 100, 190 108, 198 106 C 220 104, 262 96, 300 88 M 127 64 C 128 63, 129 63, 130 64",
            signatureLength: 720,
            grade: [[1, 1, 1, 0.16], [1, 1, 1, 0.06], [1, 1, 1, 0], [0.96, 0.97, 0.98, 0.04], [0.96, 0.97, 0.98, 0.12]]
        },
        // Luna: Terra after sunset, under the moon, as SSS sets its pages: indigo-black, the stills graded
        // black into the moon's yellow, near-opaque panels with a yellow hairline.
        luna: {
            id: "luna", navigator: "Hina", title: "Keifont", hold: 0.2, motif: "summer", film: "5 Centimeters per Second", jp: "月", glyph: "月",
            ground: "#08091a", glass: Qt.rgba(9 / 255, 10 / 255, 27 / 255, 0.93), edge: "#ebe9f6",
            accent: "#ffe08a", second: "#e8e6f2", seal: "#ffe08a", bubble: Qt.rgba(9 / 255, 10 / 255, 27 / 255, 0.93), blush: "#ffc9a0", face: [0.52, 0.44],
            text: "#f6f5fb", quiet: "#c6c4d8", faint: "#9a98b2",
            sky: ["#05050e", "#09091a", "#121226", "#2a2614", "#5a4c18"], stars: false, shade: 0.8, openingName: true, opening: "moon",
            tag: "luna_nights",
            // Its moments are title cards of the night and the moon's yellow, cut on a gentle diagonal.
            slant: 8, impact: "#fff4d6", slam: "#ffe08a", cardInk: "#06061a",
            // The page turn is a yellow curtain; its one torn frame is a moonlit tear across it.
            duotone: true, surface: "panel", outline: true, captions: true, scaffold: true, grid: true, drawer: true, turn: "curtain", tear: "moon",
            mincho: "Noto Serif CJK JP",
            grade: [[0, 0, 0, 0.12], [0.02, 0.02, 0.06, 0.4], [0.02, 0.02, 0.06, 0.55], [0.031, 0.035, 0.1, 0.86], [0.031, 0.035, 0.1, 0.96]]
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
    readonly property color artBright: paperArt ? hud.bright : "#ffffff"
    readonly property color artText: paperArt ? hud.text : light ? "#ffffff" : text
    readonly property color artQuiet: paperArt ? hud.quiet : light ? Qt.rgba(1, 1, 1, 0.86) : textQuiet
    readonly property color artFaint: paperArt ? hud.faint : light ? Qt.rgba(1, 1, 1, 0.66) : textFaint
    readonly property color artAccent: hud.artAccent || hud.accent
    readonly property color artSecond: hud.artSecond || hud.second
    readonly property color artLine: paperArt ? line : light ? Qt.rgba(1, 1, 1, 0.3) : line
    /**
        A light flavour whose stills are graded into paper (Terra's, with `duotone`): the still is
        as light as its panels, so the words on it are ink too, and the `art…` tokens are the glass's.
    */
    readonly property bool paperArt: light && !!hud.duotone
    /** The paper a light flavour stands on (its `dim`, which its shade, pool and vignette are laid in); white otherwise. */
    readonly property color paper: light && hud.dim ? hud.dim : "#ffffff"
    /** The primary button's fill: the flavour's light, or its `primary` where that light is too deep for words on it. */
    readonly property color hudPrimary: hud.primary || hud.accent

    // ---- Impact (a flavour with an `impact` colour) ------------------------------
    /** The flavour's main acts land as impact frames, its turns hold on an eyecatch and its moments are title cards. */
    readonly property bool impacts: !!hud.impact
    /** The flash of a hit (and a title card's slam, without `slam`), and nothing else: white-hot yellow in Neptune's. The light without one. */
    readonly property color impact: hud.impact || hud.accent
    /** A title card's one-drawing invert: the flavour's `slam`, else the impact colour. */
    readonly property color slam: hud.slam || impact
    /**
        The darkest ink: what is drawn on the impact colour, and a title card's and an eyecatch's ground
        (a light flavour's is paper). Not `onImpact`, which never took its value beside the `impact` property.
    */
    readonly property color cardInk: hud.cardInk || hud.ground
    /** Words on a flat field of the light (a title card's light half): the darkest ink on a pale light (Luna's yellow) or a light flavour's, else white. */
    readonly property color lightInk: light || (0.2126 * hudAccent.r + 0.7152 * hudAccent.g + 0.0722 * hudAccent.b) > 0.5 ? cardInk : artBright
    /** The flavour's diagonal, in degrees from upright: a title card is split on it, an eyecatch slashed. 0 without one. */
    readonly property real slant: hud.slant || 0
    /** How far the diagonal moves across for each pixel down. */
    readonly property real slantK: Math.tan(slant * Math.PI / 180)
    // ---- The SSS keys (a flavour with `outline`, `surface: "panel"`, …: every flavour's) ----------
    /** Panels are near-opaque with a hairline in the light, not frosted glass (`surface: "panel"`). */
    readonly property bool panels: hud.surface === "panel"
    /** Big English titles are stroke-only capitals in the HUD face that draw themselves on (`OutlineText`). */
    readonly property bool outlines: !!hud.outline
    /** Whether `s` is set as an outline title: the flavour has them and it has no Japanese (the title face keeps that). */
    function outlined(s) { return outlines && String(s).trim() !== "" && !hasJp(s) }
    /** HUD lines are lowercase captions: "neptune_music / albums". */
    readonly property bool captions: !!hud.captions
    /** A world's tag at the head of a caption: its flavour's `tag`, else its id and the first part of its role, "neptune_music", "saturn_films", "titan_what_to_watch". */
    function tagOf(id) {
        const w = Worlds.get(id)
        const own = yozoraLooks[id]
        if (own && own.tag) return own.tag
        const word = w && w.role ? String(w.role).split(",")[0].trim().toLowerCase().replace(/\s+/g, "_") : ""
        return String(id) + (word ? "_" + word : "")
    }
    /**
        A HUD line as a caption: its parts (" · " apart) in lowercase, words
        joined by underscores, a count "03 / 14" as "03_of_14", the parts
        " / " apart, after the world's tag (`tag`, when given).
    */
    function caption(line, tag) {
        const parts = String(line).split(" · ").map(p => p.trim().toLowerCase().replace(/(\d+)\s*\/\s*(\d+)/g, "$1_of_$2").replace(/\s+/g, "_")).filter(Boolean)
        return (tag ? [tag] : []).concat(parts).join(" / ")
    }
    /** Faint hairlines down the content's columns, in the light (`grid`). */
    readonly property bool ruled: !!hud.grid
    readonly property color rule: tint(hud.accent, 0.12)
    /** Long Japanese to read (lyrics, a navigator's longer line): the flavour's light mincho, else the Japanese sans. */
    readonly property string fontLong: hud.mincho && Qt.fontFamilies().indexOf(hud.mincho) >= 0 ? hud.mincho : fontJpSans
    readonly property int weightLong: fontLong === fontJpSans ? Font.Normal : Font.Light
    /** Whether Japanese `s` is long enough to be set in `fontLong`: more than eight characters. */
    function longJp(s) { return hasJp(s) && String(s).length > 8 }
    /** The navigator's signature (an SVG path in a box 320 by 150) has been written this launch: it is written once. */
    property bool signed: false

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
        portrait (`<planet>-mascot.jpg` or `.png`), and a first page's hero where one was
        put there (`<planet>-hero.png`). Empty lists and "" until
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
    /** The navigator as a first page's hero, a whole cut-out (`<planet>-hero.png`, put there by hand, never fetched); "" without one. */
    function heroOf(id) {
        const name = "/" + yozoraOf(planetOf(id)).id + "-hero.png"
        const f = yozoraArt.find(p => p.endsWith(name))
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
    // together arrive a stagger apart, in the world's `beat`.
    // Big acts (the opening, a page turn, a moment) go in rhythm rather
    // than at one speed: anticipation, a `hit`, a `hold`, then the release
    // (`easeIn` for what leaves). Everything else is quiet.
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
    /** Things arriving together: the flavour's beat's stagger (`beat.stagger`). */
    readonly property int stagger: beat.stagger
    /** One hit: the instant something lands (a slam, a cut, a stamp) before it settles. */
    readonly property int hit: SolBackend.shotCalm ? 0 : 80
    /** One drawing at 24 frames a second: an impact's flash, a title's invert. */
    readonly property int frame: SolBackend.shotCalm ? 0 : 42
    /** One drawing on twos, 12 a second: how a hit steps when the beat has `steps`. */
    readonly property int step: SolBackend.shotCalm ? 0 : 83
    /** A hold: the beat a hit is left to be seen before what follows it. */
    readonly property int hold: SolBackend.shotCalm ? 0 : 160
    /**
        A page turn's own beats, inside `turn`: the old page is covered by
        `turnCover` (after a `hit` of anticipation, the wipe), the solid
        frame is held until `turnReveal`, and the new page and its words
        `land` over what is left. Nothing of a turn runs past `turn`.
    */
    readonly property int turnCover: Math.round(turn * 0.43)
    readonly property int turnReveal: Math.round(turn * 0.67)
    readonly property int land: turn - turnReveal
    /**
        The world's beat: how things arrive on its pages, each flavour in its
        own rhythm. `stagger` (ms between things arriving together), `arrive`
        (ms one takes), `curve` (its easing), `rise` and `slide` (pixels it
        comes up from, and in from the right), `grow` (the scale it grows
        from), `flick` (it flickers once as it comes) and `turn` (the page
        turn's way: "slice", "cut", "ink", "sweep", or the flavour's own `turn`:
        "curtain"). Neptune is staccato
        and glitchy, Saturn a film's cut, Mercury slow ink, Terra a light
        bounce. A page's first card (the lead) lights its brackets as it lands.
        `steps`: its hits are drawn on twos (`Theme.step`), a smear frame
        first; titles slam and stay; arrivals stay smooth.
        With SOL_SHOT_CALM every length is nothing.
    */
    readonly property var beat: {
        const none = SolBackend.shotCalm
        const ms = n => none ? 0 : n
        const m = hud.motif
        if (m === "neon") return { stagger: ms(40), arrive: ms(160), curve: easeOut, rise: 0, slide: 12, grow: 1, flick: true, turn: hud.turn || "slice", steps: !!hud.steps }
        if (m === "shrine") return { stagger: ms(70), arrive: ms(360), curve: easeOut, rise: 0, slide: 0, grow: 1, flick: false, turn: hud.turn || "ink" }
        if (m === "summer") return { stagger: ms(40), arrive: ms(300), curve: spring, rise: 14, slide: 0, grow: 0.97, flick: false, turn: hud.turn || "sweep" }
        return { stagger: ms(30), arrive: ms(120), curve: easeOut, rise: 4, slide: 0, grow: 1, flick: false, turn: hud.turn || "cut" }
    }
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
    /** Slow to start, then gone: an exit, sharp. cubic-bezier(0.7, 0, 0.84, 0). */
    readonly property easingCurve easeIn: ({ type: Easing.BezierSpline, bezierCurve: [0.7, 0, 0.84, 0, 1, 1] })

    /** How late the `i`th of a list may arrive: the beat's stagger each, never past 400 ms. */
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

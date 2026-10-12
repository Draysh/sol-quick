pragma Singleton
import QtQuick
import QtCore
// For SolBackend (a C++ type of this module, which the folder alone doesn't bring).
import Sol.Design
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    Sol · Observatory tokens. Every Sol app uses these and nothing else:
    a sky in three depths (the chrome deepest, the pane, then the panels
    raised off it), at night or by day, one type family, hairlines, and
    colour that only comes from the worlds themselves: each app's sky is
    tinted a little by its own world. DESIGN.md explains each rule.
    At the end, the small rules every control shares: when a thing is on
    screen, a wheel's step, the page around an item, who has the keys.
*/
QtObject {
    id: theme

    // ---- Night and day --------------------------------------------------------
    /**
        How the apps look on this device: "night", "day", "sun" (day from 07:00
        to 19:00) or "system" (whatever the desktop asks for, the default).
        Settings → On this device changes it; every Sol app on the computer follows.
    */
    property string mode: SolBackend.light !== "" ? SolBackend.light : prefs.mode
    // In one file for every Sol app on the computer (~/.config/sol/device.conf).
    property Settings prefs: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/sol/device.conf"
        category: "appearance"
        property string mode: "system"
        property string motion: "full"
    }
    function setMode(m) { prefs.mode = m }
    /**
        Less motion, on this device (Settings → On this device, for every Sol
        app here): moments are short and still, nothing drifts across them.
    */
    readonly property bool calm: SolBackend.calm || prefs.motion === "less"
    function setCalm(on) { prefs.motion = on ? "less" : "full" }
    /** The hour, for "sun"; kept by Worlds' clock. */
    readonly property int hour: Worlds.now.getHours()
    // The Yozora look has no day: each world's grade is its own light.
    readonly property bool day: !yozora && (mode === "day"
        || (mode === "sun" && hour >= 7 && hour < 19)
        || (mode === "system" && Qt.styleHints.colorScheme === Qt.ColorScheme.Light))

    /** The sky: a deep blue-black at night, never pure black, so what is raised off it shows; a pale cool sky by day. */
    readonly property color night: yozora ? hud.ground : day ? "#eef1f5" : "#0c0e13"
    /** The pane, where the work is: the sky with a touch of the world's own colour. */
    readonly property color space: yozora ? hud.ground : Qt.tint(night, tint(world, day ? 0.07 : 0.05))
    /** The chrome (sidebar, the band and toolbars over a page): a step deeper than the pane. */
    readonly property color deep: yozora ? tint(hud.ground, 0.86) : day ? Qt.darker(space, 1.05) : Qt.darker(space, 1.45)
    /** A panel raised off the pane (a card): a step lighter, lit a little from above. */
    readonly property color raised: yozora ? hud.glass : Qt.tint(space, day ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.035))
    readonly property color raisedTop: yozora ? tint(hud.glass, Math.min(1, hud.glass.a + 0.06)) : Qt.tint(space, day ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.06))
    // Corners, on one scale, so a thing inside another rounds with it (an
    // inner corner is about the outer one less the room between them).
    // Pills (a round button, a switch, a count) stay pills; hairlines stay square.
    /** Small marks: a checkbox, a skeleton's line, a chart's bar, the pairing code's box. */
    // The Yozora look has square corners: its panels cut one at 45° instead.
    readonly property int radiusS: yozora ? 0 : 4
    /** Controls and pictures in lists: a button, a chip, the way back, a menu row's light, a poster, a cover, a still. */
    readonly property int radiusM: yozora ? 0 : 6
    /** A panel's corners: a card, and the glass under a menu, a list, a hint, a notice and the palette. */
    readonly property int radius: yozora ? 0 : 10
    /** A big surface on its own: the dialog, the shortcuts sheet, the desktop widget. */
    readonly property int radiusL: yozora ? 0 : 14
    /** The colour light things are drawn in over the sky: white at night, black by day. Overlays use it at a low alpha. */
    readonly property color ink: day ? "#000000" : "#ffffff"
    /** The hairlines' and surfaces' colour: the ink, or in the look its flavour's edge. */
    readonly property color edgeInk: yozora ? hud.edge : ink
    /** What dims the window under a dialog and tints glass: black at night, the sky by day. */
    readonly property color veil: yozora ? hud.ground : day ? night : "#000000"

    readonly property color surface: yozora ? tint(edgeInk, 0.06) : tint(ink, day ? 0.045 : 0.04)
    readonly property color surfaceHover: yozora ? tint(edgeInk, 0.12) : tint(ink, day ? 0.08 : 0.07)
    readonly property color line: yozora ? tint(edgeInk, 0.2) : tint(ink, day ? 0.09 : 0.07)
    readonly property color lineMid: yozora ? tint(edgeInk, 0.32) : tint(ink, day ? 0.15 : 0.12)
    readonly property color lineStrong: yozora ? tint(edgeInk, 0.55) : tint(ink, day ? 0.36 : 0.36)
    readonly property color tick: tint(ink, 0.6)

    readonly property color text: yozora ? hud.text : day ? "#1b1f27" : "#e6e8ed"
    readonly property color textBright: day ? "#07080b" : "#ffffff"
    readonly property color textValue: yozora ? Qt.tint(hud.quiet, tint(hud.text, 0.5)) : day ? "#3b414d" : "#c3c7cf"
    readonly property color textQuiet: yozora ? hud.quiet : day ? "#666d7b" : "#8b919d"
    readonly property color textFaint: yozora ? hud.faint : day ? "#a6abb5" : "#4f5561"
    /** A heading in the world's light: a panel's title (by day, the world's colour deepened to read on paper). */
    readonly property color textWorld: yozora ? hud.accent : day ? Qt.tint(text, tint(Qt.darker(world, 2.2), 0.75)) : Qt.tint(text, tint(world, 0.55))

    readonly property color danger: day ? "#d9493a" : "#ff6b5a"
    readonly property color dangerText: day ? "#b8352a" : "#ff8a7a"
    readonly property color ok: day ? "#1f9a57" : "#8ee6b0"

    /** The current world's colour, set by Shell. Glow and icons only. */
    property color world: "#f2f2f2"
    /**
        The accent chosen on this device (Settings → On this device), as a
        colour, or "" for the world's own: kept per world, in `sol.<world>`.
        The Shell reads it into `world`.
    */
    property alias chosenAccent: devicePrefs.accent
    property Settings devicePrefs: Settings { id: devicePrefs; category: "sol." + SolBackend.world; property string accent: "" }
    /**
        A world's colour as a small mark on the sky (a glyph, the current
        section's light, the chosen row): as it is at night; by day no
        lighter than a mid-tone, so a white moon still shows on the pale sky.
    */
    function mark(c) {
        if (!day) return c
        const k = Qt.color(c)
        return Qt.hsla(k.hslHue < 0 ? 0 : k.hslHue, k.hslSaturation, Math.min(k.hslLightness, 0.46), 1)
    }
    /** The current world's light for small marks: `world`, deepened by day (see `mark`). */
    readonly property color accent: mark(world)
    /** The window is up and the person is there: things that breathe or drift run only then. Set by AppWindow. */
    property bool alive: true
    /** How many things are still taking their place (arriving, loading): a picture for review waits until none is. Settling counts them. */
    property int settling: 0
    /** Colours from the world's photograph, for choosing an accent. Set by Shell. */
    property var picks: []

    /** `color` at `alpha`. */
    function tint(c, alpha) { const k = typeof c === "string" ? Qt.color(c) : c; return Qt.rgba(k.r, k.g, k.b, alpha) }

    // ---- Type: one family, weight does the work ----------------------------
    readonly property FontLoader outfit: FontLoader { source: "../assets/fonts/Outfit-Variable.ttf" }
    readonly property FontLoader shippori: FontLoader { source: "../assets/fonts/ShipporiMincho-Regular.ttf" }
    readonly property string font: outfit.status === FontLoader.Ready ? outfit.name : "Outfit"
    readonly property string fontJp: shippori.status === FontLoader.Ready ? shippori.name : "Noto Serif CJK JP"

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

    // ---- Yozora (夜空): a look to try ------------------------------------------
    /**
        A look tried for this run only (`SOL_LOOK`), "" for the apps' own.
        "yozora" is an anime film's night: every page over a still from a
        Makoto Shinkai film (`~/.local/share/sol-yozora/`, never shipped)
        under the world's grade, its panels glass with one corner cut, HUD
        labels in a mono face, a navigator who says the page's line. The
        tokens below take the look's values while it is on, so every
        component follows; `SOL_LOOK=yozora:mercury` tries one world's
        flavour in another app (the gallery).
    */
    readonly property string look: SolBackend.look
    readonly property bool yozora: look === "yozora" || look.indexOf("yozora:") === 0
    /** The window's world, by id: the app's own, set by the Shell (the gallery's changes as it shows each). */
    property string worldId: SolBackend.world
    /** The world whose flavour the look takes: the one named after `yozora:`, else the window's (a moon's, its planet's). */
    readonly property string lookWorld: look.indexOf("yozora:") === 0 ? look.slice(7) : worldId
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
        "summer"), `seal` (Mercury's vermilion), `paper` and `ink` (Terra's
        notebook) and `film` (whose stills).
    */
    readonly property var yozoraLooks: ({
        saturn: {
            id: "saturn", navigator: "Suzume", hold: 0.28, motif: "dusk", film: "Suzume", jp: "土星", glyph: "土",
            ground: "#0b0e2a", glass: Qt.rgba(9 / 255, 11 / 255, 34 / 255, 0.66), edge: "#c8d0ff",
            accent: "#ffc07e", second: "#7fe3ff", seal: "#f07a6a",
            text: "#f2f4ff", quiet: "#c8d0ff", faint: "#8e98d8",
            sky: ["#0b0e2a", "#2b2468", "#8a3c7e", "#f07a6a", "#ffc07e"], stars: true, shade: 0.78,
            grade: [[1, 0.75, 0.49, 0.16], [0.36, 0.24, 0.55, 0.22], [0.17, 0.14, 0.41, 0.5], [0.043, 0.055, 0.165, 0.86], [0.043, 0.055, 0.165, 0.96]]
        },
        mercury: {
            id: "mercury", navigator: "Mitsuha", hold: 0.3, motif: "shrine", film: "Your Name", jp: "水星", glyph: "水",
            ground: "#07081c", glass: Qt.rgba(7 / 255, 8 / 255, 28 / 255, 0.7), edge: "#ffe6d6",
            accent: "#ff8fa8", second: "#ffd58a", seal: "#e2412e", washi: "#fff4da",
            text: "#fff8ee", quiet: "#e9dccf", faint: "#a99a9e",
            sky: ["#05061a", "#121848", "#2e1e4e", "#7a2a3c", "#c94a35"], stars: true, shade: 0.8,
            grade: [[0.89, 0.25, 0.18, 0.12], [0.03, 0.03, 0.11, 0.3], [0.03, 0.03, 0.11, 0.5], [0.027, 0.031, 0.11, 0.86], [0.027, 0.031, 0.11, 0.96]]
        },
        neptune: {
            id: "neptune", navigator: "Lucy", hold: 0.34, motif: "neon", film: "Weathering With You", jp: "海王星", glyph: "海",
            ground: "#0a1426", glass: Qt.rgba(4 / 255, 9 / 255, 22 / 255, 0.72), edge: "#8fe7ff",
            accent: "#ff4a5a", second: "#8fe7ff", seal: "#ff4a5a",
            text: "#eef6ff", quiet: "#b9cbe8", faint: "#7590b4",
            sky: ["#040814", "#0a1730", "#14284f", "#3a1c46", "#a32a48"], stars: false, shade: 0.8, rain: 1, haze: "#ff4a5a",
            grade: [[0.56, 0.9, 1, 0.1], [0.04, 0.08, 0.15, 0.42], [0.04, 0.08, 0.15, 0.56], [0.039, 0.078, 0.149, 0.86], [0.039, 0.078, 0.149, 0.96]]
        },
        terra: {
            id: "terra", navigator: "Hina", hold: 0.04, motif: "summer", film: "Weathering With You and 5 Centimeters per Second", jp: "地球", glyph: "地",
            ground: "#14233f", glass: Qt.rgba(14 / 255, 40 / 255, 86 / 255, 0.62), edge: "#e9f4ff",
            accent: "#9be07a", second: "#fff3a6", seal: "#9fc4f0", paper: "#fbf8ee", ink: "#14233f",
            text: "#ffffff", quiet: "#e2edff", faint: "#a9c3e6",
            sky: ["#1f6fd6", "#4a90e2", "#8fbdf0", "#cfe4fa", "#eef6ff"], stars: false, shade: 0.72, pool: 0.42,
            grade: [[0.62, 0.77, 0.94, 0.1], [0.08, 0.14, 0.25, 0.08], [0.08, 0.14, 0.25, 0.22], [0.078, 0.137, 0.247, 0.5], [0.078, 0.137, 0.247, 0.74]]
        }
    })
    /** A world's flavour in the look: its own, or its planet's for a moon; Saturn's for any other. */
    function yozoraOf(id) {
        const w = Worlds.get(id)
        const planet = w && w.parent ? w.parent : id
        return yozoraLooks[planet] || yozoraLooks.saturn
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
    /** Words on the art and on glass: bright, held back, and faint. */
    readonly property color hudText: "#ffffff"
    readonly property color hudQuiet: Qt.rgba(1, 1, 1, 0.72)
    readonly property color hudFaint: Qt.rgba(1, 1, 1, 0.45)
    /** The corner a panel has cut away (45°), and the arm of its brackets. */
    readonly property int hudCut: 18
    readonly property int hudBracket: 12
    /** Titles: a heavy Japanese serif. HUD labels and figures: a mono face, upper case, tracked wide. */
    readonly property string fontTitle: "Noto Serif CJK JP"
    readonly property string fontMono: "JetBrains Mono"
    /** The face for words set in capitals (labels, buttons, tabs, quiet facts): the mono face in the look, else the sans. */
    readonly property string fontCaps: yozora ? fontMono : font
    readonly property real trackHud: 0.22
    readonly property int textHero: 112
    readonly property int textLede: 26
    readonly property int textFigure: 38
    /**
        The look's pictures on this computer (`~/.local/share/sol-yozora/`,
        fetched by `scripts/yozora-art.sh`): the stills a world's pages stand
        on (`<planet>-ground-<n>.jpg`) and its navigator's portrait
        (`<planet>-mascot.jpg`). Empty lists and "" when they aren't there.
    */
    readonly property var yozoraArt: { try { return JSON.parse(SolBackend.lookArt || "[]") } catch (e) { return [] } }
    function groundsOf(id) {
        const pre = "/" + yozoraOf(id).id + "-ground-"
        return yozoraArt.filter(f => f.indexOf(pre) >= 0).sort().map(f => fileUrl(f))
    }
    /** A moon's own stills (`<moon>-ground-<n>.jpg`: Luna's evening), which its pages stand on instead of its planet's; [] when it has none. */
    function ownGroundsOf(id) {
        const pre = "/" + id + "-ground-"
        return yozoraArt.filter(f => f.indexOf(pre) >= 0).sort().map(f => fileUrl(f))
    }
    function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/") }
    function mascotOf(id) {
        const name = "/" + yozoraOf(id).id + "-mascot."
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
    // The durations: a fade for text and colour, a lock for ticks and
    // switches, a settle for something taking its place, and a rise for a
    // body appearing. Things that arrive together arrive a stagger apart;
    // what drifts (clouds, a slow glow) takes a drift.
    // For pictures taken with SOL_SHOT_CALM, all of them nothing: everything is in its place at once.
    readonly property int fade: SolBackend.shotCalm ? 0 : 240
    readonly property int lock: SolBackend.shotCalm ? 0 : 120
    readonly property int settle: SolBackend.shotCalm ? 0 : 420
    readonly property int rise: SolBackend.shotCalm ? 0 : 900
    readonly property int stagger: SolBackend.shotCalm ? 0 : 28
    readonly property int drift: 12000

    /** A plain ease: cubic-bezier(0.2, 0.7, 0.2, 1). */
    readonly property var ease: [0.2, 0.7, 0.2, 1, 1, 1]
    /** Fast out, long soft landing: how things settle. cubic-bezier(0.16, 1, 0.3, 1). */
    readonly property var easeOut: [0.16, 1, 0.3, 1, 1, 1]

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

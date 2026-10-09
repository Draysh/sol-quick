pragma Singleton
import QtQuick
import QtCore
// For SolBackend (a C++ type of this module, which the folder alone doesn't bring).
import Sol.Design

/*
    Sol · Observatory tokens. Every Sol app uses these and nothing else:
    a sky in three depths (the chrome deepest, the pane, then the panels
    raised off it), at night or by day, one type family, hairlines, and
    colour that only comes from the worlds themselves: each app's sky is
    tinted a little by its own world. DESIGN.md explains each rule.
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
    }
    function setMode(m) { prefs.mode = m }
    /** The hour, for "sun"; kept by Worlds' clock. */
    readonly property int hour: Worlds.now.getHours()
    readonly property bool day: mode === "day"
        || (mode === "sun" && hour >= 7 && hour < 19)
        || (mode === "system" && Qt.styleHints.colorScheme === Qt.ColorScheme.Light)

    /** The sky: a deep blue-black at night, never pure black, so what is raised off it shows; a pale cool sky by day. */
    readonly property color night: day ? "#eef1f5" : "#0c0e13"
    /** The pane, where the work is: the sky with a touch of the world's own colour. */
    readonly property color space: Qt.tint(night, tint(world, day ? 0.07 : 0.05))
    /** The chrome (sidebar, the band and toolbars over a page): a step deeper than the pane. */
    readonly property color deep: day ? Qt.darker(space, 1.05) : Qt.darker(space, 1.45)
    /** A panel raised off the pane (a card): a step lighter, lit a little from above. */
    readonly property color raised: Qt.tint(space, day ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.035))
    readonly property color raisedTop: Qt.tint(space, day ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.06))
    /** A panel's corners. */
    readonly property int radius: 10
    /** The colour light things are drawn in over the sky: white at night, black by day. Overlays use it at a low alpha. */
    readonly property color ink: day ? "#000000" : "#ffffff"
    /** What dims the window under a dialog and tints glass: black at night, the sky by day. */
    readonly property color veil: day ? night : "#000000"

    readonly property color surface: tint(ink, day ? 0.045 : 0.04)
    readonly property color surfaceHover: tint(ink, day ? 0.08 : 0.07)
    readonly property color line: tint(ink, day ? 0.09 : 0.07)
    readonly property color lineMid: tint(ink, day ? 0.15 : 0.12)
    readonly property color lineStrong: tint(ink, day ? 0.36 : 0.36)
    readonly property color tick: tint(ink, 0.6)

    readonly property color text: day ? "#1b1f27" : "#e6e8ed"
    readonly property color textBright: day ? "#07080b" : "#ffffff"
    readonly property color textValue: day ? "#3b414d" : "#c3c7cf"
    readonly property color textQuiet: day ? "#666d7b" : "#8b919d"
    readonly property color textFaint: day ? "#a6abb5" : "#4f5561"
    /** A heading in the world's light: a panel's title (by day, the world's colour deepened to read on paper). */
    readonly property color textWorld: day ? Qt.tint(text, tint(Qt.darker(world, 2.2), 0.75)) : Qt.tint(text, tint(world, 0.55))

    readonly property color danger: day ? "#d9493a" : "#ff6b5a"
    readonly property color dangerText: day ? "#b8352a" : "#ff8a7a"
    readonly property color ok: day ? "#1f9a57" : "#8ee6b0"

    /** The current world's colour, set by Shell. Glow and icons only. */
    property color world: "#f2f2f2"
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
    /** Colours from the world's photograph, for choosing an accent. Set by Shell. */
    property var picks: []

    /** `color` at `alpha`. */
    function tint(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }

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
    // Four durations: a fade for text and colour, a lock for ticks and
    // switches, a settle for something taking its place, and a rise for a
    // body appearing. Things that arrive together arrive a stagger apart.
    readonly property int fade: 240
    readonly property int lock: 120
    readonly property int settle: 420
    readonly property int rise: 900
    readonly property int stagger: 28
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
        let f = item.parent
        while (f && !(f.hasOwnProperty("contentY") && f.hasOwnProperty("contentHeight") && f.hasOwnProperty("contentItem"))) f = f.parent
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
}

pragma Singleton
import QtQuick

/*
    Sol · Observatory tokens. Every Sol app uses these and nothing else:
    a night sky in three depths (the chrome deepest, the pane, then the
    panels raised off it), one type family, hairlines, and colour that only
    comes from the worlds themselves: each app's night is tinted a little by
    its own world. DESIGN.md explains each rule.
*/
QtObject {
    id: theme

    // ---- Night and light ---------------------------------------------------
    /** The night sky: deep blue-black, never pure black, so what is raised off it shows. */
    readonly property color night: "#0c0e13"
    /** The pane, where the work is: the night with a touch of the world's own colour. */
    readonly property color space: Qt.tint(night, tint(world, 0.05))
    /** The chrome (sidebar, the band and toolbars over a page): a step deeper than the pane. */
    readonly property color deep: Qt.darker(space, 1.45)
    /** A panel raised off the pane (a card): a step lighter, lit a little from above. */
    readonly property color raised: Qt.tint(space, Qt.rgba(1, 1, 1, 0.035))
    readonly property color raisedTop: Qt.tint(space, Qt.rgba(1, 1, 1, 0.06))
    /** A panel's corners. */
    readonly property int radius: 10

    readonly property color surface: Qt.rgba(1, 1, 1, 0.04)
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.07)
    readonly property color line: Qt.rgba(1, 1, 1, 0.07)
    readonly property color lineMid: Qt.rgba(1, 1, 1, 0.12)
    readonly property color lineStrong: Qt.rgba(1, 1, 1, 0.36)
    readonly property color tick: Qt.rgba(1, 1, 1, 0.6)

    readonly property color text: "#e6e8ed"
    readonly property color textBright: "#ffffff"
    readonly property color textValue: "#c3c7cf"
    readonly property color textQuiet: "#8b919d"
    readonly property color textFaint: "#4f5561"
    /** A heading in the world's light: a panel's title. */
    readonly property color textWorld: Qt.tint(text, tint(world, 0.55))

    readonly property color danger: "#ff6b5a"
    readonly property color dangerText: "#ff8a7a"
    readonly property color ok: "#8ee6b0"

    /** The current world's colour, set by Shell. Glow and icons only. */
    property color world: "#f2f2f2"
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
        const forget = () => { if (!waiting) return; waiting = false; for (const s of changes) s.disconnect(check) }
        const check = () => { if (seen()) { forget(); arrival(true) } }
        for (const s of changes) s.connect(check)
        return forget
    }
}

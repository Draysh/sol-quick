pragma Singleton
import QtQuick

/*
    The worlds, as the design knows them: name, role (what the app is
    for, in a word or three, shown beside the name wherever it appears),
    tagline, kind, colour
    sampled from the photograph, real axial tilt, where the body sits on
    a sheet (landscape positions are in a 1600 × 900 frame, portrait ones
    in a 390-wide frame) and where the callout starts.

    A sheet's band shows the middle of the frame: in landscape about
    y 215..685 at any width (the bodies stop growing when the band stops),
    in portrait about y 120..460. So a body there is either whole (r about
    170, beside the name's reticle in the middle, which takes x 800 ± 145)
    or a horizon rising from the band's bottom edge, its arc well inside.

    `fit` is where the disc is in the photograph (centre and radius, as
    fractions of its width), measured by fitting a circle (least squares)
    to the limb: the first and last pixels brighter than about 20 % of
    white on each row and column of the photograph; a photograph with a
    soft, vignetted edge is sampled a little inside it so the limb stays
    clean. `fit.lit` is where the photograph's own light comes from, for one
    that shows a terminator (Mercury): the body turns it to face its light.
    `air` is how much atmosphere it has (0 none, 1 Titan's haze): the
    terminator's softness and the rim of light around the limb. `icon` is
    the light where the body is small (the sidebar, the sheet's bar).

    The web kit (`kit/design`, Sol's web app) reads `rising`, `lit` and
    `table` from this file (`scripts/worlds-from-qml.mjs` there): keep them
    plain object literals.
*/
QtObject {
    id: worlds

    function image(name) { return Qt.resolvedUrl("../assets/worlds/" + name + ".png") }

    /** Rising from the bottom of a phone screen, lit from above: a thin bright arc under the name. */
    readonly property var rising: ({ cx: 195, cy: 930, r: 520, light: 0, phase: 0.1 })
    /** A small body's light: gibbous, lit from the upper left. */
    readonly property var lit: ({ light: 300, phase: 0.72 })

    readonly property var table: ({
        sol: {
            id: "sol", live: "corona", name: "Sol", role: "Hub", tagline: "The hub: sign-in, worlds and events", kind: "star",
            color: "#ff7a2e", tilt: 7.25, image: image("disc-sun"), render: "star",
            hero: { cx: 1400, cy: 450, r: 540, light: 90, phase: 0.5 },
            portrait: { cx: 195, cy: 720, r: 520, light: 0, phase: 1 },
            icon: { light: 90, phase: 1 },
            callout: { x: 380, y: 250 }
        },
        terra: {
            id: "terra", live: "clouds", name: "Terra", role: "Habits and diary", tagline: "Habits, diary and wellbeing", kind: "planet",
            color: "#8ec5ff", tilt: 23.44, image: image("disc-terra"), render: "disc", air: 0.5,
            // The disc spans x 32..1166 of 1200, on black.
            fit: { x: 0.500, y: 0.506, r: 0.466 },
            hero: { cx: 1130, cy: 450, r: 170, light: 90, phase: 0.55 },
            portrait: rising, icon: lit,
            callout: { x: 620, y: 320, flip: true },
            companions: [{ world: "luna", cx: 1395, cy: 300, r: 30, light: 90, phase: 0.5 }]
        },
        luna: {
            id: "luna", name: "Luna", role: "Sleep and evenings", tagline: "Terra’s quieter twin", kind: "moon", parent: "terra",
            color: "#ffffff", tilt: 6.68, image: image("disc-luna"), render: "disc",
            // Nearly the whole square, a little left of centre.
            fit: { x: 0.493, y: 0.506, r: 0.494 },
            hero: { cx: 480, cy: 450, r: 175, light: 270, phase: 0.28 },
            portrait: rising, icon: lit,
            callout: { x: 1060, y: 320 }
        },
        saturn: {
            id: "saturn", name: "Saturn", role: "Films, series, anime", tagline: "Movies, series and anime", kind: "planet",
            color: "#e6cf9e", tilt: 26.73, image: image("saturn"), render: "photo",
            // A photograph used whole: `r` is half the rings' span (x 120..1475 of 1600), the
            // globe's radius is 0.4 of it.
            fit: { x: 0.498, y: 0.517, r: 0.43 },
            hero: { cx: 1250, cy: 450, r: 320, light: 90, phase: 1 },
            portrait: { cx: 300, cy: 175, r: 82, light: 0, phase: 1 },
            icon: { light: 90, phase: 1 },
            callout: { x: 620, y: 320, flip: true }
        },
        titan: {
            id: "titan", live: "clouds", name: "Titan", role: "What to watch", tagline: "What to watch next, chosen at home", kind: "moon", parent: "saturn",
            color: "#ffb06a", tilt: 0.3, image: image("disc-titan"), render: "disc", effect: "haze", air: 1,
            // The limb is soft and dark from r 0.42 to 0.52: sampled inside it.
            fit: { x: 0.503, y: 0.507, r: 0.445 },
            hero: { cx: 340, cy: 450, r: 165, light: 60, phase: 0.38 },
            portrait: rising, icon: lit,
            callout: { x: 1060, y: 320 }
        },
        mercury: {
            id: "mercury", name: "Mercury", role: "Japanese", tagline: "Japanese, every day", kind: "planet",
            color: "#f2f2f2", tilt: 0.03, image: image("disc-mercury"), render: "disc",
            // The disc fills the square (fitted to its lit limb); the photograph is gibbous
            // (lit fraction 0.75), lit from the right.
            fit: { x: 0.4985, y: 0.4994, r: 0.497, lit: 90 },
            hero: { cx: 820, cy: 1010, r: 700, light: 20, phase: 0.12 },
            portrait: rising, icon: lit,
            callout: { x: 1220, y: 280 }
        },
        neptune: {
            id: "neptune", live: "clouds", name: "Neptune", role: "Music", tagline: "Your music, through Navidrome", kind: "planet",
            color: "#6f9bff", tilt: 28.32, image: image("disc-neptune"), render: "disc", air: 0.6,
            // The disc touches the edges of the square: sampled just inside them.
            fit: { x: 0.494, y: 0.494, r: 0.485 },
            hero: { cx: 560, cy: 1240, r: 880, light: 330, phase: 0.14 },
            portrait: rising, icon: lit,
            callout: { x: 560, y: 240, flip: true },
            companions: [{ world: "triton", cx: 1250, cy: 380, r: 50, light: 300, phase: 0.45 }]
        },
        triton: {
            id: "triton", name: "Triton", role: "Radio", tagline: "Radio and discovery", kind: "moon", parent: "neptune",
            color: "#e4d1dd", tilt: 157, image: image("disc-triton"), render: "disc", air: 0.12,
            // Blurred, and larger than the square (centre 0.53, 0.49, radius 0.55): sampled inside.
            fit: { x: 0.53, y: 0.49, r: 0.455 },
            hero: { cx: 1130, cy: 450, r: 170, light: 300, phase: 0.62 },
            portrait: rising, icon: lit,
            callout: { x: 620, y: 320, flip: true }
        }
    })

    /** A world by id; one that isn't in the table still gets a sensible look. */
    function get(id) {
        return table[id] || {
            // This app's own, before the design knows it: its manifest says what it is for.
            id: id, name: id.charAt(0).toUpperCase() + id.slice(1), role: id === Sol.world ? Sol.manifest.role || "" : "", tagline: "", kind: "planet",
            color: "#f2f2f2", tilt: 0, image: "", render: "disc",
            hero: { cx: 1130, cy: 450, r: 170, light: 315, phase: 0.5 },
            portrait: rising, icon: lit,
            callout: { x: 620, y: 320, flip: true }
        }
    }

    // ---- The real sky ----------------------------------------------------------
    /** The time the sky is drawn for: a minute's precision is plenty. */
    property date now: new Date()
    // Only while the window is in front, and at once when it comes back, so nothing redraws for a sky no one sees.
    property Timer minute: Timer { interval: 60000; running: Theme.alive; repeat: true; triggeredOnStart: true; onTriggered: worlds.now = new Date() }

    /**
        The moon at `date`: its age in days since new, the lit fraction, whether
        it is waxing, and its name. From a known new moon and the mean synodic
        month; within a few hours of the almanac, which a disc can't show.
    */
    function moonAt(date) {
        const synodic = 29.530588853
        const knownNew = Date.UTC(2000, 0, 6, 18, 14)
        const days = (date.getTime() - knownNew) / 86400000
        const age = ((days % synodic) + synodic) % synodic
        const fraction = (1 - Math.cos(2 * Math.PI * age / synodic)) / 2
        const names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        return { age: age, fraction: fraction, waxing: age < synodic / 2, name: names[Math.floor(age / synodic * 8 + 0.5) % 8] }
    }

    /**
        Where the light falls on a world now, for the ones that follow the real
        sky; null for the rest. Luna shows tonight's phase, lit on the right
        while it waxes (as seen from the north). Terra is seen from above where
        you are: lit from the east in the morning, full at noon, from the west
        in the evening, a thin crescent at midnight.
    */
    function skyOf(id) {
        if (id === "luna") {
            const m = moonAt(now)
            return { phase: Math.max(0.05, m.fraction), light: m.waxing ? 90 : 270 }
        }
        if (id === "terra") {
            const h = now.getHours() + now.getMinutes() / 60
            return { phase: Math.max(0.08, (1 - Math.cos(2 * Math.PI * h / 24)) / 2), light: h < 12 ? 90 : 270 }
        }
        return null
    }

    /**
        What a world's surface looks like now, by id: `{ green, cloudy }`, each
        0 … 1 with 0.5 the photograph as it is. A world sets its own
        (Terra's habits and today's weather); every Body of it follows.

            Worlds.setSurface("terra", { green: 0.7, cloudy: 0.4 })
    */
    property var surfaces: ({})
    function setSurface(id, s) {
        const was = surfaces[id]
        if (was && Math.abs(was.green - s.green) < 0.005 && Math.abs(was.cloudy - s.cloudy) < 0.005) return
        const next = Object.assign({}, surfaces)
        next[id] = { green: s.green, cloudy: s.cloudy }
        surfaces = next
    }

    /** The moons that open from a world's screens. */
    function moonsOf(id) {
        return Object.values(table).filter(w => w.parent === id)
    }

    /** The worlds this one works with: a moon's planet, a planet's moons. */
    function kin(id) {
        const w = get(id)
        return w.kind === "moon" && w.parent ? [get(w.parent)] : moonsOf(id)
    }
}

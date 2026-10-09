pragma Singleton
import QtQuick

/*
    The worlds, as the design knows them: name, role (what the app is
    for, in a word or three, shown beside the name wherever it appears),
    tagline, kind, colour
    sampled from the photograph, real axial tilt, where the body sits on
    a sheet (landscape positions are in a 1600 × 900 frame, portrait ones
    in a 390-wide frame) and where the callout starts.
*/
QtObject {
    id: worlds

    function image(name) { return Qt.resolvedUrl("../assets/worlds/" + name + ".png") }

    /** Rising from the bottom of a phone screen, lit from above. */
    readonly property var rising: ({ cx: 195, cy: 600, r: 470, light: 0, phase: 0.08 })

    readonly property var table: ({
        sol: {
            id: "sol", live: "corona", name: "Sol", role: "Hub", tagline: "The hub: sign-in, worlds and events", kind: "star",
            color: "#ff7a2e", tilt: 7.25, image: image("disc-sun"), render: "star",
            hero: { cx: 1400, cy: 450, r: 540, light: 90, phase: 0.5 },
            portrait: { cx: 195, cy: 720, r: 520, light: 0, phase: 1 },
            callout: { x: 380, y: 250 }
        },
        terra: {
            id: "terra", live: "clouds", name: "Terra", role: "Habits and diary", tagline: "Habits, diary and wellbeing", kind: "planet",
            color: "#8ec5ff", tilt: 23.44, image: image("disc-terra"), render: "disc",
            hero: { cx: 1080, cy: 420, r: 300, light: 90, phase: 0.55 },
            portrait: rising,
            callout: { x: 620, y: 250, flip: true },
            companions: [{ world: "luna", cx: 360, cy: 170, r: 40, light: 90, phase: 0.5 }]
        },
        luna: {
            id: "luna", name: "Luna", role: "Sleep and evenings", tagline: "Terra’s quieter twin", kind: "moon", parent: "terra",
            color: "#ffffff", tilt: 6.68, image: image("disc-luna"), render: "disc",
            hero: { cx: 560, cy: 450, r: 320, light: 270, phase: 0.28 },
            portrait: rising,
            callout: { x: 1040, y: 290 }
        },
        saturn: {
            id: "saturn", name: "Saturn", role: "Films, series, anime", tagline: "Movies, series and anime", kind: "planet",
            color: "#e6cf9e", tilt: 26.73, image: image("saturn"), render: "photo",
            hero: { cx: 800, cy: 450, r: 760, light: 90, phase: 1 },
            portrait: { cx: 195, cy: 560, r: 300, light: 0, phase: 1 },
            callout: { x: 60, y: 235 }
        },
        titan: {
            id: "titan", live: "clouds", name: "Titan", role: "What to watch", tagline: "What to watch next, chosen at home", kind: "moon", parent: "saturn",
            color: "#ffb06a", tilt: 0.3, image: image("disc-titan"), render: "disc", effect: "haze",
            hero: { cx: 560, cy: 450, r: 280, light: 45, phase: 0.42 },
            portrait: rising,
            callout: { x: 1000, y: 290 }
        },
        mercury: {
            id: "mercury", name: "Mercury", role: "Japanese", tagline: "Japanese, every day", kind: "planet",
            color: "#f2f2f2", tilt: 0.03, image: image("disc-mercury"), render: "disc", effect: "split-rim",
            hero: { cx: 820, cy: 860, r: 640, light: 0, phase: 0.22 },
            portrait: rising,
            callout: { x: 1200, y: 310 }
        },
        neptune: {
            id: "neptune", live: "clouds", name: "Neptune", role: "Music", tagline: "Your music, through Navidrome", kind: "planet",
            color: "#6f9bff", tilt: 28.32, image: image("disc-neptune"), render: "disc",
            hero: { cx: 520, cy: 1010, r: 790, light: 315, phase: 0.15 },
            portrait: rising,
            callout: { x: 1000, y: 236 },
            companions: [{ world: "triton", cx: 1080, cy: 610, r: 86, light: 330, phase: 0.3 }]
        },
        triton: {
            id: "triton", name: "Triton", role: "Radio", tagline: "Radio and discovery", kind: "moon", parent: "neptune",
            color: "#e4d1dd", tilt: 157, image: image("disc-triton"), render: "disc",
            hero: { cx: 1080, cy: 560, r: 300, light: 330, phase: 0.5 },
            portrait: rising,
            callout: { x: 640, y: 230, flip: true }
        }
    })

    /** A world by id; one that isn't in the table still gets a sensible look. */
    function get(id) {
        return table[id] || {
            // This app's own, before the design knows it: its manifest says what it is for.
            id: id, name: id.charAt(0).toUpperCase() + id.slice(1), role: id === Sol.world ? Sol.manifest.role || "" : "", tagline: "", kind: "planet",
            color: "#f2f2f2", tilt: 0, image: "", render: "disc",
            hero: { cx: 1100, cy: 560, r: 320, light: 315, phase: 0.4 },
            portrait: rising,
            callout: { x: 620, y: 240, flip: true }
        }
    }

    // ---- The real sky ----------------------------------------------------------
    /** The time the sky is drawn for: a minute's precision is plenty. */
    property date now: new Date()
    property Timer minute: Timer { interval: 60000; running: true; repeat: true; onTriggered: worlds.now = new Date() }

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
            return { phase: Math.max(0.03, m.fraction), light: m.waxing ? 90 : 270 }
        }
        if (id === "terra") {
            const h = now.getHours() + now.getMinutes() / 60
            return { phase: Math.max(0.08, (1 - Math.cos(2 * Math.PI * h / 24)) / 2), light: h < 12 ? 90 : 270 }
        }
        return null
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

pragma Singleton
import QtQuick

/*
    The worlds, as the design knows them: name, tagline, kind, colour
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
            id: "sol", live: "corona", name: "Sol", tagline: "The hub: sign-in, worlds and events", kind: "star",
            color: "#ff7a2e", tilt: 7.25, image: image("disc-sun"), render: "star",
            hero: { cx: 1400, cy: 450, r: 540, light: 90, phase: 0.5 },
            portrait: { cx: 195, cy: 720, r: 520, light: 0, phase: 1 },
            callout: { x: 380, y: 250 }
        },
        terra: {
            id: "terra", live: "clouds", name: "Terra", tagline: "Habits, diary and wellbeing", kind: "planet",
            color: "#8ec5ff", tilt: 23.44, image: image("disc-terra"), render: "disc",
            hero: { cx: 1080, cy: 420, r: 300, light: 90, phase: 0.55 },
            portrait: rising,
            callout: { x: 620, y: 250, flip: true },
            companions: [{ world: "luna", cx: 360, cy: 170, r: 40, light: 90, phase: 0.5 }]
        },
        luna: {
            id: "luna", name: "Luna", tagline: "Terra’s quieter twin", kind: "moon", parent: "terra",
            color: "#ffffff", tilt: 6.68, image: image("disc-luna"), render: "disc",
            hero: { cx: 560, cy: 450, r: 320, light: 270, phase: 0.28 },
            portrait: rising,
            callout: { x: 1040, y: 290 }
        },
        saturn: {
            id: "saturn", name: "Saturn", tagline: "Movies, series and anime", kind: "planet",
            color: "#e6cf9e", tilt: 26.73, image: image("saturn"), render: "photo",
            hero: { cx: 800, cy: 450, r: 760, light: 90, phase: 1 },
            portrait: { cx: 195, cy: 560, r: 300, light: 0, phase: 1 },
            callout: { x: 60, y: 235 }
        },
        titan: {
            id: "titan", live: "clouds", name: "Titan", tagline: "What to watch next, chosen at home", kind: "moon", parent: "saturn",
            color: "#ffb06a", tilt: 0.3, image: image("disc-titan"), render: "disc", effect: "haze",
            hero: { cx: 560, cy: 450, r: 280, light: 45, phase: 0.42 },
            portrait: rising,
            callout: { x: 1000, y: 290 }
        },
        mercury: {
            id: "mercury", name: "Mercury", tagline: "Japanese, every day", kind: "planet",
            color: "#f2f2f2", tilt: 0.03, image: image("disc-mercury"), render: "disc", effect: "split-rim",
            hero: { cx: 820, cy: 860, r: 640, light: 0, phase: 0.22 },
            portrait: rising,
            callout: { x: 1200, y: 310 }
        },
        neptune: {
            id: "neptune", live: "clouds", name: "Neptune", tagline: "Your music, through Navidrome", kind: "planet",
            color: "#6f9bff", tilt: 28.32, image: image("disc-neptune"), render: "disc",
            hero: { cx: 520, cy: 1010, r: 790, light: 315, phase: 0.15 },
            portrait: rising,
            callout: { x: 1000, y: 236 },
            companions: [{ world: "triton", cx: 1080, cy: 610, r: 86, light: 330, phase: 0.3 }]
        },
        triton: {
            id: "triton", name: "Triton", tagline: "Radio and discovery", kind: "moon", parent: "neptune",
            color: "#e4d1dd", tilt: 157, image: image("disc-triton"), render: "disc",
            hero: { cx: 1080, cy: 560, r: 300, light: 330, phase: 0.5 },
            portrait: rising,
            callout: { x: 640, y: 230, flip: true }
        }
    })

    /** A world by id; one that isn't in the table still gets a sensible look. */
    function get(id) {
        return table[id] || {
            id: id, name: id.charAt(0).toUpperCase() + id.slice(1), tagline: "", kind: "planet",
            color: "#f2f2f2", tilt: 0, image: "", render: "disc",
            hero: { cx: 1100, cy: 560, r: 320, light: 315, phase: 0.4 },
            portrait: rising,
            callout: { x: 620, y: 240, flip: true }
        }
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

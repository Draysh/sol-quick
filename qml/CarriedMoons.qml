pragma ComponentBehavior: Bound
import QtQuick

/*
    The moons a window carries, merged into what it shows: their sections
    as a group after the world's own (each path under `/<moon>`, the group
    named after the moon), their pages, their palette rows, the moments a
    picture can stage and what they draw over the window, beside the
    world's. `AppWindow` keeps one and reads it; a world lists its moons in
    `AppWindow { moons }`.

        CarriedMoons { moons: win.moons; sections: win.sections; pages: win.pages; aliases: win.aliases }
*/
QtObject {
    id: carried

    /** The moons (`Moon`s), and the world's own sections and pages they join. */
    property list<Moon> moons
    property var sections: []
    property var pages: ({})

    /** Each moon's world id, in order. */
    readonly property var ids: Array.from(moons, m => m.world)
    /** A moon's page path in the window: `/` is `/<moon>`, `/sky` is `/<moon>/sky` (a query stays after it). */
    function pathOf(m, path) {
        const [p, query] = path.split("?")
        return "/" + m.world + (p === "/" ? "" : p) + (query ? "?" + query : "")
    }
    /** Every section the Shell shows: the world's, then each moon's. */
    readonly property var allSections: {
        let out = sections.slice()
        for (const m of moons) out = out.concat(m.sections.map(s => Object.assign({}, s, { path: carried.pathOf(m, s.path), world: m.world, group: Worlds.get(m.world).name },
            s.children ? { children: s.children.map(c => Object.assign({}, c, { path: carried.pathOf(m, c.path) })) } : {})))
        return out
    }
    /** Every page the Shell opens, by path: the world's, then each moon's. */
    readonly property var allPages: {
        const out = Object.assign({}, pages)
        for (const m of moons) for (const path in m.pages) out[carried.pathOf(m, path)] = m.pages[path]
        return out
    }
    /** The world's own aliases (`AppWindow.aliases`), which the moons' join. */
    property var aliases: ({})
    /** Every alias the Shell follows: the world's, each moon's under `/<moon>`, and a moon's Sky and Settings
        on the planet's pages when it has none of its own (`/titan/sky` → `/sky?tab=titan`, `/titan/settings` →
        `/settings?part=titan`). */
    readonly property var allAliases: {
        const out = Object.assign({}, aliases)
        for (const m of moons) {
            for (const path in m.aliases) out[carried.pathOf(m, path)] = carried.pathOf(m, m.aliases[path])
            if (!m.pages["/sky"] && pages["/sky"]) out[carried.pathOf(m, "/sky")] = "/sky?tab=" + m.world
            if (m.settings && !m.pages["/settings"] && pages["/settings"]) out[carried.pathOf(m, "/settings")] = "/settings?part=" + m.world
        }
        return out
    }
    /** The moons' parts of the planet's Settings page, in order: `{ world, settings }` (a Component each). */
    readonly property var settings: Array.from(moons).filter(m => !!m.settings).map(m => ({ world: m.world, settings: m.settings }))
    /** The moons' palette rows, one after another. */
    readonly property var commands: {
        let out = []
        for (const m of moons) out = out.concat(m.commands)
        return out
    }
    /** What the moons draw over the window (Luna's veil): Components. */
    readonly property var overlays: Array.from(moons, m => Array.from(m.overlays)).reduce((a, b) => a.concat(b), [])
    /** A moment a moon names for pictures (`_moment=<name>`), or null. */
    function moment(name) {
        let found = null
        for (const m of moons) if (m.moments[name]) found = m.moments[name]
        return found
    }
}

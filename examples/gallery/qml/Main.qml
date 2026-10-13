import QtQuick
import Sol.Design

/*
    The gallery's window: the kit's own AppWindow and Shell, with a page
    for each part of the kit. Read from this checkout when the gallery
    starts (not compiled into anything), so a change here needs no build.

    Besides the kit's own staging keys (`_palette`, `_notice`, `_ask`,
    `_notify`, `_scroll`), the shot path takes the gallery's: `_world=saturn`
    (the window as that world, its Sheet on the first page), `_focus=field`
    (`button`, `field`, `textarea`, `slider`, `select`: which control on
    Controls has the keys, `select` with its list open; a picture without
    it shows the button's) and `_menu=1` (the right-click menu open on
    Overlays; `_nested=1` on Menus: the card's menu with its nested list out). The kit's `_comet=1` and `_sky=full-moon` show on the Sheet. The keys show only while the window is in front.
*/
AppWindow {
    id: app

    world: staged("_world") || "sol"
    sections: [
        { path: "/", label: "Worlds", icon: "orbit", hint: "Every world’s Sheet, its body at four sizes, and every glyph" },
        { path: "/controls", label: "Controls", icon: "settings", hint: "Buttons, chips, checks, switches, fields, lists and keys" },
        { path: "/panels", label: "Panels", icon: "grid", hint: "Cards, grids, figures, charts, skeletons, strips and pictures",
          // A section with children: one row, opening out to them while one of them is open.
          children: [{ path: "/tabs", label: "Tabs", hint: "A page with tabs, each part of its path",
                       tabs: [{ id: "overview", label: "Overview" }, { id: "calendar", label: "Calendar" }, { id: "timeline", label: "Timeline" }] },
                     { path: "/menus", label: "Menus", hint: "Things with a right-click and a More button, and a nested entry" }] },
        { path: "/overlays", label: "Overlays", icon: "layers", hint: "The menu, the palette, the dialog, notices and hints" },
        { path: "/sky", label: "Sky", icon: "sparkles", hint: "A world’s milestones as constellations, some lit; the moon’s on its own tab" },
        { path: "/settings", label: "Settings", icon: "settings", hint: "The window’s Sol and device cards, and the moon’s part under its name" }
    ]
    pages: ({ "/": worlds, "/controls": controls, "/panels": panels, "/tabs": tabsPage, "/menus": menusPage, "/overlays": overlays, "/sky": sky, "/settings": settings })
    // The gallery's moon, carried as Luna is in Terra: its group, its pages, its colour. Its sky is a tab of
    // the gallery's Sky and its settings a part of the gallery's Settings (`/moon/sky`, `/moon/settings` lead there).
    moons: [
        Moon {
            world: "moon"
            sections: [{ path: "/", label: "Tonight", icon: "moon", hint: "The moon’s first page, on its own link" }]
            pages: ({ "/": moonHome })
            settings: Component {
                Grid {
                    masonry: true
                    min: 380
                    SolCard { world: "moon" }
                    SettingsCard { world: "moon" }
                    ExportCard { world: "moon" }
                }
            }
            commands: [{ label: "Ask the moon", icon: "moon", hint: "Its own command, on its own link", run: () => Sol.of("moon").call("hello").then(t => Notices.show({ world: "moon", title: "The moon says", body: t })) }]
        }
    ]
    shortcuts: [{ keys: "← / →", does: "The world before or after, on Worlds" }]
    // The first-run tour (`_tour=1`, or `_tour=2` for its second card): the kit's own, as a world has one.
    tour: [
        { title: "Every part of the kit, on six pages", body: "Worlds, Controls, Panels, Overlays, Sky and Settings: each component as a world uses it, with sample data only." },
        { icon: "search", title: "Its best key", body: "Ctrl+K finds any page, does any command, and finds a world by name.", keys: "Ctrl+K" },
        { icon: "layers", title: "Where to start", body: "Overlays has the menu, the palette, the dialog, a moment, and this tour.", go: "/overlays", start: "Open Overlays" }
    ]

    /** A `_key` from the shot path, or "". */
    function staged(key) {
        const query = SolBackend.shotPath.split("?")[1] || ""
        for (const pair of query.split("&")) {
            const [k, v] = pair.split("=")
            if (k === key) return v ? decodeURIComponent(v) : "1"
        }
        return ""
    }

    // The palette's own entries, and what it finds as you type: the worlds by name.
    commands: [
        { label: "Show a notice", icon: "info", hint: "A notice drops in over the page", run: () => Notices.show({ world: app.world, title: "Saved", body: "A notice, on glass, over the page." }) },
        { label: "Ask for a name", icon: "edit", hint: "The dialog, with a field", run: () => app.ask.name("New list", "Name", "", "Create") },
        // A nested entry: one row that opens its own list ("rate 8" finds the number inside too).
        { label: "Rate…", icon: "star", hint: "A nested entry, its numbers inside", items: Array.from({ length: 10 }, (_, n) => ({ label: String(n + 1), run: () => Notices.show({ world: app.world, title: "Rated " + (n + 1), body: "From the palette’s nested list." }) })) }
    ]
    find: q => Promise.resolve(Object.values(Worlds.table)
        .filter(w => w.name.toLowerCase().includes(q) || w.role.toLowerCase().includes(q))
        .map(w => ({ label: w.name, hint: w.role, run: () => { app.world = w.id; if (app.shell) app.shell.go("/") } })))

    Component { id: worlds; WorldsPage { } }
    Component { id: controls; ControlsPage { focusOn: app.staged("_focus") || (SolBackend.shot !== "" ? "button" : "") } }
    Component { id: panels; PanelsPage { } }
    Component { id: tabsPage; TabsPage { } }
    Component { id: menusPage; MenusPage { menuOpen: app.staged("_nested") !== "" } }
    Component { id: sky; SkyPage { } }
    Component { id: moonHome; MoonPage { } }
    Component { id: settings; SettingsPage { } }
    Component { id: overlays; OverlaysPage { menuOpen: app.staged("_menu") !== ""; momentNow: app.staged("_moment") !== "" } }
}

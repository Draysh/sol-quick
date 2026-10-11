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
    Overlays). The keys show only while the window is in front.
*/
AppWindow {
    id: app

    world: staged("_world") || "sol"
    sections: [
        { path: "/", label: "Worlds", icon: "orbit", hint: "Every world’s Sheet, its body at four sizes, and every glyph" },
        { path: "/controls", label: "Controls", icon: "settings", hint: "Buttons, chips, checks, switches, fields, lists and keys" },
        { path: "/panels", label: "Panels", icon: "grid", hint: "Cards, grids, figures, charts, skeletons, strips and pictures" },
        { path: "/overlays", label: "Overlays", icon: "layers", hint: "The menu, the palette, the dialog, notices and hints" }
    ]
    pages: ({ "/": worlds, "/controls": controls, "/panels": panels, "/overlays": overlays })
    shortcuts: [{ keys: "← / →", does: "The world before or after, on Worlds" }]
    // The first-run tour (`_tour=1`, or `_tour=2` for its second card): the kit's own, as a world has one.
    tour: [
        { title: "Every part of the kit, on four pages", body: "Worlds, Controls, Panels and Overlays: each component as a world uses it, with sample data only." },
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
        { label: "Night or day", icon: "moon", hint: "Turns the light over for this run", run: () => Theme.mode = Theme.day ? "night" : "day" }
    ]
    find: q => Promise.resolve(Object.values(Worlds.table)
        .filter(w => w.name.toLowerCase().includes(q) || w.role.toLowerCase().includes(q))
        .map(w => ({ label: w.name, hint: w.role, run: () => { app.world = w.id; if (app.shell) app.shell.go("/") } })))

    Component { id: worlds; WorldsPage { } }
    Component { id: controls; ControlsPage { focusOn: app.staged("_focus") || (SolBackend.shot !== "" ? "button" : "") } }
    Component { id: panels; PanelsPage { } }
    Component { id: overlays; OverlaysPage { menuOpen: app.staged("_menu") !== ""; momentNow: app.staged("_moment") !== "" } }
}

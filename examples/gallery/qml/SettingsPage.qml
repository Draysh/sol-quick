import QtQuick
import Sol.Design

/*
    The gallery's Settings (`/settings`): the window's own cards in a
    masonry grid, then the moon's part under its name (MoonSettings, from
    the moon's `settings`); `/moon/settings` opens it scrolled there.
*/
Screen {
    id: page

    title: "Settings"
    header: PageHead { title: "Settings"; lead: "The window’s own cards, and the moon’s under its name." }
    Grid {
        masonry: true
        min: 380
        SolCard { }
        DeviceCard { }
    }
    MoonSettings { }
}

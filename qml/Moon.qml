import QtQuick

/*
    A moon carried in its planet's app: its sections, pages and palette
    rows, given relative to the moon (`/` is its first page, `/nights`
    another). The window puts them under `/<moon>` (`/luna`,
    `/luna/nights`) as a group of the sidebar under the moon's name, after
    the planet's own; each of its pages is drawn in the moon's colour and
    talks to the moon's world (`Screen.world`, `Sol.of`). `overlays` are
    drawn over the whole window, as the moon's own window had them (Luna's
    veil at bedtime). The moon's QML module makes one (`LunaMoon.qml`); the
    planet lists it: `AppWindow { moons: [LunaMoon { }] }`.

        Moon { world: "luna"; sections: [{ path: "/", label: "Tonight", icon: "moon" }]; pages: ({ "/": tonight }); settings: lunaSettings }

    A moon without a `/sky` page of its own shows its sky as a tab of the
    planet's (SkyPage), and `/<moon>/sky` opens it there.
*/
QtObject {
    /** The moon's world id: `luna`. */
    property string world: ""
    /** `{ path, label, hint, icon }`, paths relative to the moon. */
    property var sections: []
    /** Relative path → Component. */
    property var pages: ({})
    /** The palette's rows for the moon, as `AppWindow.commands`. */
    property var commands: []
    /** Its moments a picture can stage, as `AppWindow.moments`. */
    property var moments: ({})
    /** Paths of the moon's that moved, still reachable: `{ "/galaxy": "/taste?tab=galaxy" }`, both relative to the moon
        (as `Shell.aliases`). Its Sky and Settings, when it has no page of its own for them, lead to the planet's. */
    property var aliases: ({})
    /**
        Its part of the planet's Settings page: the moon's cards (its
        `SolCard`, `SettingsCard`, `ExportCard` with `world`, and its own),
        shown under the moon's name below the planet's by `MoonSettings`.
        `/<moon>/settings` opens that page there.

            settings: Component { Grid { masonry: true; SolCard { world: "luna" } … } }
    */
    property Component settings: null
    /** Components drawn over the window, for as long as it is open. */
    property list<Component> overlays
    /** What the moon declares inside it: its pages' Components. */
    default property list<QtObject> parts
}

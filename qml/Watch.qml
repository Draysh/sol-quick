import QtQuick

/*
    Reads a page again when documents change in the collections it shows,
    here or on another device, and not when others change (a song played,
    a moment shown). `changed()` comes once for every burst of changes;
    also when the app fell behind and every collection may have changed,
    and, with `settings`, when the world's settings change in Sol.

    On a page the Shell keeps while another shows, it waits: a change while
    the page is hidden is kept, and `changed()` comes once when the page
    shows again, so one write doesn't read every page visited again. Outside
    a page (a world's singleton) it never waits.

        Watch { collections: ["titles", "watched"]; onChanged: page.load() }

    A moon's page in its planet's app names the moon: `Watch { world: "luna"; … }`.
    `enabled: false` (a page that waits while you edit): nothing comes, and
    nothing is kept for later.
*/
Item {
    id: watch

    /** The collections the page reads (their ids in `sol-world.json`). */
    property var collections: []
    /** Also when the world's settings change in Sol. */
    property bool settings: false
    /** The world whose documents these are: a moon the app carries, or "" for its own. */
    property string world: ""

    signal changed()

    // Drawn nowhere and placed by nothing (Column and Grid skip what isn't visible).
    visible: false
    width: 0
    height: 0

    /** The page it is on, if any. */
    readonly property Item page: Theme.screenOf(watch)
    /** Whether that page shows (or there is none): a change then reads it at once. */
    readonly property bool showing: !page || page.visible
    /** A change came while the page was hidden. */
    property bool stale: false
    onShowingChanged: if (showing && stale) { stale = false; Qt.callLater(watch.fire) }

    function fire() { if (watch.enabled) watch.changed() }
    function come() {
        if (!watch.enabled) return
        if (watch.showing) Qt.callLater(watch.fire)
        else watch.stale = true
    }
    property Connections link: Connections {
        target: Sol.of(watch.world)
        function onChangedIn(names) {
            if (names.length === 0 || names.some(n => watch.collections.indexOf(n) >= 0)) watch.come()
        }
        function onSettingsVersionChanged() { if (watch.settings) watch.come() }
    }
}

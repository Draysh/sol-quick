import QtQuick

/*
    Reads a page again when documents change in the collections it shows,
    here or on another device, and not when others change (a song played,
    a moment shown). `changed()` comes once for every burst of changes;
    also when the app fell behind and every collection may have changed,
    and, with `settings`, when the world's settings change in Sol.

        Watch { collections: ["titles", "watched"]; onChanged: page.load() }
*/
QtObject {
    id: watch

    /** The collections the page reads (their ids in `sol-world.json`). */
    property var collections: []
    /** Also when the world's settings change in Sol. */
    property bool settings: false
    /** Off: nothing comes (a page that waits while you edit). */
    property bool enabled: true

    signal changed()

    function fire() { if (watch.enabled) watch.changed() }
    property Connections link: Connections {
        target: Sol
        function onChangedIn(names) {
            if (names.length === 0 || names.some(n => watch.collections.indexOf(n) >= 0)) Qt.callLater(watch.fire)
        }
        function onSettingsVersionChanged() { if (watch.settings) Qt.callLater(watch.fire) }
    }
}

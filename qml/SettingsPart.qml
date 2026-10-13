import QtQuick

/*
    One section of the Settings menu (SettingsScreen): its name in the
    list on the left, its cards in the panel on the right while it is
    chosen. `/settings?part=<key>` opens it. The kit's own parts are `sol`
    (the connection and the world's settings as set in Sol), `export`,
    `device` and `updates`; a world's part with one of those keys takes
    that part's place (Terra's Export, with the diary as Markdown), and a
    world adds its own in `order` (the kit's are 0, 80, 85 and 90; a
    world's come after Sol unless it says).

        SettingsPart { key: "services"; label: "Services"; jp: "連携"; Card { title: "TMDB"; … } Card { title: "AniList"; … } }
*/
Column {
    id: part

    /** Its name in the path: `/settings?part=services`. */
    property string key: ""
    /** Its name in the list: one to three words. */
    property string label: ""
    /** Its name in Japanese, before the label. */
    property string jp: ""
    /** Where it comes in the list: lower first. */
    property real order: 50
    /** Whether it is offered at all (a part with nothing to show for this world says false). */
    property bool available: true

    width: parent ? parent.width : 0
    spacing: Theme.s4
    // Each card fills the panel's width.
    onChildrenChanged: { for (const c of children) if (!Theme.isRepeater(c)) c.width = Qt.binding(() => part.width) }
}

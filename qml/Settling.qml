import QtQuick
import Sol.Design

/*
    Says that something is still taking its place (an arrival running, a
    picture loading) for as long as `when` holds, so a picture for review
    waits until it is done (`Theme.settling` counts them). Forgets itself
    when its item goes, mid-way too. A `flourish` is something played over
    a page that has already taken its place (a name signing itself): a
    picture still waits for it, but the page counts as settled without it
    (`Theme.flourishing` counts those).

        Settling { when: arrive.running }
        Settling { when: pen.running; flourish: true }
*/
QtObject {
    /** Still on its way. */
    property bool when: false
    /** Played over a page already in its place: it doesn't hold the page from settling. */
    property bool flourish: false
    property bool counted: false
    function sync() {
        if (when === counted) return
        counted = when
        if (flourish) Theme.flourishing += when ? 1 : -1
        else Theme.settling += when ? 1 : -1
    }
    onWhenChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) { if (flourish) Theme.flourishing -= 1; else Theme.settling -= 1 }
}

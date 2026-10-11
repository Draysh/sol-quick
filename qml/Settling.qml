import QtQuick
import Sol.Design

/*
    Says that something is still taking its place (an arrival running, a
    picture loading) for as long as `when` holds, so a picture for review
    waits until it is done (`Theme.settling` counts them). Forgets itself
    when its item goes, mid-way too.

        Settling { when: arrive.running }
*/
QtObject {
    /** Still on its way. */
    property bool when: false
    property bool counted: false
    function sync() {
        if (when === counted) return
        counted = when
        Theme.settling += when ? 1 : -1
    }
    onWhenChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Theme.settling -= 1
}

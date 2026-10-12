import QtQuick

/*
    A thing's right-click: lay it over a row or a tile (`anchors.fill`) and
    give it the thing's menu; it takes only the right button, so clicks and
    hovers go on to what is under it. With a MoreButton at the row's end,
    the same entries open from the pointer and from the keys.

        Item { MenuArea { anchors.fill: parent; menu: () => page.stationMenu(station) } MoreButton { menu: … } }
*/
MouseArea {
    id: area

    /** ContextMenu's entries: a list, or a function returning one (called as it opens). */
    property var menu: null

    enabled: !!menu
    acceptedButtons: Qt.RightButton
    onClicked: mouse => {
        const win = area.Window.window as AppWindow
        if (win) win.menu.openAt(area, mouse, area.menu)
    }
}

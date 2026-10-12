import QtQuick

/*
    The ⋯ beside a thing (a title, a deck, a station, a habit): opens its
    menu under itself, the same entries its right-click shows (see
    ContextMenu). Card shows one in its head when it has a `menu`; a row
    puts one at its end, beside a MenuArea.

        MoreButton { menu: () => Neptune.albumMenu(album) }
*/
Button {
    id: more

    /** ContextMenu's entries: a list, or a function returning one (called as it opens). */
    property var menu: null

    variant: "quiet"
    icon: "more"
    hint: "More"
    enabled: !!menu
    onClicked: {
        const win = more.Window.window as AppWindow
        if (win) win.menu.openAt(more, null, more.menu)
    }
}

import QtQuick

/*
    A key for one page: a Shortcut that only works while `on` (its page)
    shows, while nobody is typing in a field, and while no menu, dialog or
    palette is open over the window. For the whole window, `on` is the
    window's `contentItem`.

        Key { on: page; sequence: "Space"; when: !!page.card; onActivated: page.showAnswer() }
*/
Shortcut {
    id: key

    /** The page (or any item) the key belongs to. */
    required property Item on
    /** When it applies, besides the page showing; use it instead of `enabled`. */
    property bool when: true

    readonly property AppWindow window: on ? (on.Window.window as AppWindow) : null
    readonly property Item focused: on ? on.Window.activeFocusItem : null
    /** Keys go to a field that takes text, not to the page. */
    readonly property bool typing: Theme.typing(focused)
    readonly property bool covered: !!window && (!!window.ask.current || window.commandPalette.open || window.menu.open)

    enabled: when && !!on && on.visible && !typing && !covered
}

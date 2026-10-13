pragma ComponentBehavior: Bound
import QtQuick

/*
    A panel of glass over the pages: under a menu, a list, a hint, a
    notice or the palette. It is HudGlass blurring the pages live under it,
    its top-right corner cut; what it holds goes inside, over the glass. It
    must sit on the window, outside the pages (see Glass).

        GlassPanel { width: 220; height: list.implicitHeight; edge: Theme.lineStrong; Column { id: list … } }
*/
Rectangle {
    id: panel

    /** How much the glass is darkened: the ground's alpha over it (at least 0.72). */
    property real shade: 0.82
    /** The hairline's colour. */
    property color edge: Theme.lineMid

    color: "transparent"
    radius: Theme.radius
    border.width: 0

    HudGlass {
        anchors.fill: parent
        z: -1
        readonly property AppWindow win: panel.Window.window as AppWindow
        from: win ? win.backdrop : null
        cuts: [0, Math.min(Theme.hudCut, panel.height / 3), 0, 0]
        tint: Theme.tint(Theme.frost, Math.max(Theme.light ? 0.88 : 0.72, panel.shade))
        line: Theme.tint(Theme.hud.edge, 0.32)
    }
}

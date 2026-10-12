pragma ComponentBehavior: Bound
import QtQuick

/*
    A panel of glass with a hairline round it, `Theme.radius` corners: under
    a menu, a list, a hint, a notice or the palette. What it holds goes
    inside, over the glass, kept clear of the corners; it must sit on the
    window, outside the pages (see Glass). In the Yozora look it is the
    look's glass (HudGlass, blurring the pages live under it) with its
    top-right corner cut.

        GlassPanel { width: 220; height: list.implicitHeight; edge: Theme.lineStrong; Column { id: list … } }
*/
Rectangle {
    id: panel

    /** How much the glass is darkened (or, by day, paled): the veil's alpha. */
    property real shade: 0.82
    /** The hairline's colour. */
    property color edge: Theme.lineMid

    color: "transparent"
    radius: Theme.radius
    border.width: Theme.yozora ? 0 : 1
    border.color: edge

    Glass { visible: !Theme.yozora; anchors.fill: parent; anchors.margins: 1; radius: Math.max(0, panel.radius - 1); tint: Theme.tint(Theme.veil, panel.shade) }
    Loader {
        active: Theme.yozora
        anchors.fill: parent
        z: -1
        sourceComponent: HudGlass {
            readonly property AppWindow win: panel.Window.window as AppWindow
            from: win ? win.backdrop : null
            cuts: [0, Math.min(Theme.hudCut, panel.height / 3), 0, 0]
            tint: Theme.tint(Theme.hud.ground, Math.max(0.72, panel.shade))
            line: Theme.tint(Theme.hud.edge, 0.32)
        }
    }
}

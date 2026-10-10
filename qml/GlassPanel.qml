import QtQuick

/*
    A panel of glass with a hairline round it, `Theme.radius` corners: under
    a menu, a list, a hint, a notice or the palette. What it holds goes
    inside, over the glass, kept clear of the corners; it must sit on the
    window, outside the pages (see Glass).

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
    border.width: 1
    border.color: edge

    Glass { anchors.fill: parent; anchors.margins: 1; radius: Math.max(0, panel.radius - 1); tint: Theme.tint(Theme.veil, panel.shade) }
}

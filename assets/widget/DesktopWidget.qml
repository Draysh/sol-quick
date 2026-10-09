import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Sol.Design

/*
    A world's widget on the desktop: a small panel over the wallpaper and
    under the windows, in a corner, for as long as the app runs (in the
    tray too). The app gives it its content; a click opens the app.
    Wayland desktops with layer-shell only, so it sits here, outside the
    compiled module, and AppWindow loads it by address: on a desktop
    without it, nothing happens.
*/
Window {
    id: widget

    /** The app's window: what it shows (`widget`), and in which corner (`widgetPrefs.corner`). */
    property var host: null
    readonly property Component content: host ? host.widget : null
    /** "top-right", "top-left", "bottom-right" or "bottom-left". */
    readonly property string corner: host ? host.widgetPrefs.corner : "top-right"
    /** Brings the app's window up. */
    function open() { if (host) { host.show(); host.raise(); host.requestActivate() } }
    readonly property var w: Worlds.get(Sol.world)
    /** The empty edge around the panel, in place of margins. */
    readonly property int gap: 20

    color: "transparent"
    width: panel.width + gap * 2
    height: panel.height + gap * 2
    visible: true

    LayerShell.Window.scope: "sol-" + Sol.world
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: (corner.startsWith("bottom") ? LayerShell.Window.AnchorBottom : LayerShell.Window.AnchorTop)
                             | (corner.endsWith("left") ? LayerShell.Window.AnchorLeft : LayerShell.Window.AnchorRight)
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    // Beside the bar and docks, never under them; it reserves nothing itself.
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.activateOnShow: false

    Rectangle {
        id: panel
        x: widget.gap; y: widget.gap
        width: 300
        height: body.y + body.height + 16
        radius: Theme.radius
        // A little see-through: the compositor may frost what is behind it.
        color: Theme.tint(Theme.raised, 0.88)
        border.width: 1
        border.color: mouse.containsMouse ? Theme.lineMid : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }

        Row {
            id: head
            x: 16; y: 14
            spacing: 10
            WorldGlyph { world: Sol.world; size: 10; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: nameText
                anchors.verticalCenter: parent.verticalCenter
                text: widget.w.name
                font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase
                color: Theme.textWorld
            }
            Text {
                visible: widget.w.role !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: widget.w.role
                width: Math.max(0, Math.min(implicitWidth, panel.width - 32 - 20 - nameText.width - 20))
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.textXs
                color: Theme.textQuiet
            }
        }
        Rectangle { x: 1; y: head.y + head.height + 10; width: parent.width - 2; height: 1; color: Theme.line }
        Loader {
            id: body
            x: 16; y: head.y + head.height + 22
            width: parent.width - 32
            sourceComponent: widget.content
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: widget.open()
        }
    }
}

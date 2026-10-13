import QtQuick
import QtQuick.Shapes

/*
    A big chevron in the world's light, for stepping through things one by
    one (an album to the next album, the queue's next song), as SSS by
    applibot steps through its members: ‹ for the one before, › for the one
    after. It slides a little the way it goes under the pointer and gives
    under a press; with nothing that way (`enabled` false) it is faint and
    does nothing. What it steps to is in its hint.

        Chevron { way: 1; hint: "Next album: Neon Rain"; onClicked: page.step(1) }
*/
Item {
    id: root

    /** 1 for the next one (›), -1 for the one before (‹). */
    property int way: 1
    /** What it steps to, said under the pointer and to a screen reader. */
    property string hint: way > 0 ? "Next" : "Previous"
    /** The chevron's height; it is as wide as half of that. */
    property real size: 48
    property color color: Theme.hudAccent
    signal clicked()

    readonly property bool lit: enabled && (mouse.containsMouse || activeFocus)

    implicitWidth: Math.max(Theme.target, size * 0.5 + Theme.s3)
    implicitHeight: Math.max(Theme.target, size)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: hint
    Accessible.onPressAction: if (root.enabled) root.clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            if (!event.isAutoRepeat && root.enabled) root.clicked()
        }
    }

    Shape {
        id: mark
        anchors.centerIn: parent
        width: root.size * 0.5
        height: root.size
        opacity: root.enabled ? 1 : 0.28
        preferredRendererType: Shape.CurveRenderer
        transform: Translate {
            x: root.lit ? root.way * 4 : 0
            y: mouse.pressed ? 1 : 0
            Behavior on x { NumberAnimation { duration: Theme.settle; easing: Theme.spring } }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: Math.max(2, root.size / 16)
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            startX: root.way > 0 ? 2 : mark.width - 2; startY: 1
            PathLine { x: root.way > 0 ? mark.width - 2 : 2; y: mark.height / 2 }
            PathLine { x: root.way > 0 ? 2 : mark.width - 2; y: mark.height - 1 }
        }
    }
    Ticks { on: root.activeFocus; out: 2; radius: Theme.radiusM }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Hint { text: root.hint; when: mouse.containsMouse }
}

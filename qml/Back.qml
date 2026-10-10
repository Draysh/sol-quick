import QtQuick
import QtQuick.Effects

/*
    The way back to the page this one was opened from, by name. The Shell
    places it: at the start of the PageHead, or floating over the pane's
    corner, where it needs its own ground.
*/
Item {
    id: root

    property string label: "Back"
    property bool floating: false
    signal go()

    implicitWidth: Math.min(row.implicitWidth + 22, 280)
    implicitHeight: 32
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Back to " + label
    Accessible.onPressAction: root.go()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            if (!event.isAutoRepeat) root.go()
        }
    }

    RectangularShadow {
        visible: root.floating
        anchors.fill: face
        radius: face.radius
        anchors.topMargin: 6
        blur: 24
        color: Theme.tint(Theme.veil, 0.5)
    }
    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.radiusM
        color: Theme.space
        border.width: 1
        border.color: mouse.containsMouse ? Theme.lineStrong : root.floating ? Theme.lineStrong : Theme.lineMid
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Icon {
            name: "arrow-left"; size: 13
            color: words.color
            anchors.verticalCenter: parent.verticalCenter
            transform: Translate { x: mouse.containsMouse ? -2 : 0; Behavior on x { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
        }
        Text {
            id: words
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            width: Math.min(implicitWidth, 240)
            elide: Text.ElideRight
            font.family: Theme.font
            font.weight: Theme.weightLabel
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(0.16, Theme.textXs)
            font.capitalization: Font.AllUppercase
            color: mouse.containsMouse ? Theme.textBright : Theme.textQuiet
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }
    Ticks { on: root.activeFocus; out: 5; radius: face.radius }
    transform: Translate { y: mouse.pressed ? 1 : 0 }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go() }
    Hint { text: "Back to " + root.label + " (Alt+←)"; when: mouse.containsMouse }

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: Theme.fade } }
}

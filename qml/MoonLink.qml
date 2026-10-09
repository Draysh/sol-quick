import QtQuick
import QtQuick.Shapes

/* ( • ) and a name. Moons are doors to their own apps. */
Item {
    id: root

    property string text: ""
    property string hint: ""
    signal clicked()

    // From the words' own width, not the width they are given (which follows this).
    implicitWidth: 22 + row.spacing + words.implicitWidth + 8
    implicitHeight: Theme.target
    activeFocusOnTab: true
    Accessible.role: Accessible.Link
    Accessible.name: text
    Accessible.description: hint
    Accessible.onPressAction: clicked()
    Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { event.accepted = true; if (!event.isAutoRepeat) root.clicked() } }
    readonly property bool lit: mouse.containsMouse || activeFocus

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Shape {
            width: 22; height: 10
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                strokeColor: Theme.tint(words.color, 0.7); strokeWidth: 1; fillColor: "transparent"
                PathAngleArc { centerX: 10; centerY: 5; radiusX: 6; radiusY: 6; startAngle: 120; sweepAngle: 120 }
            }
            ShapePath {
                strokeColor: Theme.tint(words.color, 0.7); strokeWidth: 1; fillColor: "transparent"
                PathAngleArc { centerX: 12; centerY: 5; radiusX: 6; radiusY: 6; startAngle: -60; sweepAngle: 120 }
            }
            ShapePath {
                strokeColor: "transparent"; fillColor: words.color
                PathAngleArc { centerX: 11; centerY: 5; radiusX: 1.6; radiusY: 1.6; startAngle: 0; sweepAngle: 360 }
            }
        }
        Text {
            id: words
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            // Held to less than it wants (a narrow sheet), the name elides.
            width: Math.max(0, Math.min(implicitWidth, root.width - 8 - 22 - row.spacing))
            elide: Text.ElideRight
            font.family: Theme.font
            font.weight: Theme.weightValue
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs)
            font.capitalization: Font.AllUppercase
            font.underline: root.lit
            color: root.lit ? Theme.textBright : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }
    Item { anchors.centerIn: parent; width: row.width + 12; height: row.height + 12; Ticks { on: root.activeFocus; out: 2 } }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Hint { text: root.hint; when: mouse.containsMouse }
}

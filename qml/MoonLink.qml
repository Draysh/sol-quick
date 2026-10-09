import QtQuick
import QtQuick.Shapes

/* ( • ) and a name. Moons are doors to their own apps. */
Item {
    id: root

    property string text: ""
    property string hint: ""
    signal clicked()

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.target

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
            font.family: Theme.font
            font.weight: Theme.weightValue
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs)
            font.capitalization: Font.AllUppercase
            font.underline: mouse.containsMouse
            color: mouse.containsMouse ? Theme.textBright : "#e6e6e6"
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Hint { text: root.hint; when: mouse.containsMouse }
}

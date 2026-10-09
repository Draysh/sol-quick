import QtQuick
import QtQuick.Effects

/* An on/off switch: a hairline track, a disc that moves into the light. */
Item {
    id: root

    property string label: ""
    property bool checked: false
    property string hint: ""
    signal toggled(bool checked)

    implicitWidth: parent ? parent.width : 240
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: Theme.target

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Item {
                    id: track
                    width: 36; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: "transparent"
                        border.width: 1
                        border.color: !root.enabled ? Theme.lineMid : root.checked ? Theme.text : mouse.containsMouse ? Theme.text : Theme.lineStrong
                        Behavior on border.color { ColorAnimation { duration: Theme.lock } }
                    }
                    RectangularShadow {
                        anchors.fill: disc
                        radius: disc.radius
                        blur: 10
                        color: Theme.tint(Theme.world, root.checked ? 0.7 : 0)
                        Behavior on color { ColorAnimation { duration: Theme.settle } }
                    }
                    Rectangle {
                        id: disc
                        x: root.checked ? 21 : 3
                        y: 3
                        width: 10; height: 10; radius: 5
                        color: !root.enabled ? Theme.textFaint : root.checked ? Theme.textBright : Theme.textQuiet
                        // The disc stretches towards where it is going while pressed.
                        transform: Scale { origin.x: root.checked ? disc.width : 0; xScale: mouse.pressed && root.enabled ? 1.3 : 1; Behavior on xScale { NumberAnimation { duration: Theme.lock } } }
                        Behavior on x { SpringAnimation { spring: 4; damping: 0.32; mass: 0.8 } }
                        Behavior on color { ColorAnimation { duration: Theme.lock } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    font.family: Theme.font
                    font.pixelSize: Theme.textM
                    font.weight: Theme.weightValue
                    color: root.enabled ? Theme.text : Theme.textFaint
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.enabled) { root.checked = !root.checked; root.toggled(root.checked) }
            }
        }
        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width - 50; x: 50 }
    }
}

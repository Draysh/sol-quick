import QtQuick

/*
    A label and a choice from a short list, underlined like a field. The
    list drops out of the line; focus lights the line from the left.

        Select { label: "Sort"; options: [{ value: "added", label: "Added" }]; value: "added"; onChosen: v => sort = v }
*/
FocusScope {
    id: root

    property string label: ""
    property var options: []
    property string value: ""
    property string placeholder: "Choose…"
    property string hint: ""
    signal chosen(string value)

    readonly property var current: options.find(o => o.value === value)
    property bool open: false

    implicitWidth: 240
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Down) { open = !open; event.accepted = true }
        else if (event.key === Qt.Key_Escape && open) { open = false; event.accepted = true }
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Label { text: root.label; width: parent.width }

        Item {
            id: line
            width: parent.width
            height: Theme.control

            Text {
                anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: root.current ? root.current.label : root.placeholder
                font.family: Theme.font
                font.pixelSize: Theme.textM
                font.weight: Theme.weightValue
                color: root.current ? Theme.text : Theme.textFaint
                elide: Text.ElideRight
            }
            Icon {
                name: "chevron-down"; size: 10
                color: Theme.textQuiet
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                transform: Translate { y: mouse.containsMouse ? 1 : 0; Behavior on y { NumberAnimation { duration: Theme.settle } } }
                rotation: root.open ? 180 : 0
                Behavior on rotation { SpringAnimation { spring: 3; damping: 0.25 } }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.7) : Theme.lineStrong
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: Theme.textBright
                transform: Scale { origin.x: 0; xScale: root.activeFocus || root.open ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            }
            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(); root.open = !root.open } }
        }

        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width }
    }

    // The list, over whatever is under it.
    Item {
        id: drop
        parent: root.Window.window ? root.Window.window.contentItem : root
        visible: root.open
        z: 900
        property point at: line.mapToItem(parent, 0, line.height)
        x: at.x; y: at.y + 2
        width: line.width
        height: list.implicitHeight + 2

        MouseArea { parent: drop.parent; anchors.fill: parent; z: -1; enabled: root.open; onClicked: root.open = false; onWheel: root.open = false }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1; border.color: Theme.lineMid
            opacity: root.open ? 1 : 0
            transformOrigin: Item.Top
            scale: root.open ? 1 : 0.97
            transform: Translate { y: root.open ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
            Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0, 0, 0, 0.8) }
            Column {
                id: list
                x: 1; y: 1
                width: parent.width - 2
                Repeater {
                    model: root.options
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: Theme.control
                        Rectangle { anchors.fill: parent; color: hover.containsMouse ? Theme.surfaceHover : modelData.value === root.value ? Theme.surface : "transparent" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; x: 12
                            width: parent.width - 24
                            text: modelData.label
                            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                            color: modelData.value === root.value ? Theme.textBright : Theme.text
                            elide: Text.ElideRight
                        }
                        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.value = modelData.value; root.open = false; root.chosen(modelData.value) } }
                    }
                }
            }
        }
    }
}

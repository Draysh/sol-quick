import QtQuick

/*
    One line on hover, a moment after the pointer rests: what a control is
    for. Sits under its parent, in the window's space so nothing clips it.

        Hint { text: "Ctrl+1"; when: mouse.containsMouse }
*/
Item {
    id: root
    property string text: ""
    property bool when: false
    property bool above: false

    visible: false

    Timer {
        id: rest
        interval: 600
        running: root.when && root.text !== ""
        onTriggered: tip.show()
    }
    onWhenChanged: if (!when) tip.hide()

    Loader {
        id: tip
        active: false
        function show() {
            const win = root.Window.window
            if (!win) return
            const p = root.parent.mapToItem(null, 0, root.above ? 0 : root.parent.height)
            sourceComponent = bubble
            active = true
            if (item) {
                item.x = Math.max(8, Math.min(win.width - item.width - 8, p.x))
                item.y = root.above ? p.y - item.height - 6 : p.y + 6
            }
        }
        function hide() { active = false }
    }

    Component {
        id: bubble
        Rectangle {
            parent: root.Window.window ? root.Window.window.contentItem : null
            z: 1000
            width: words.implicitWidth + 20
            height: words.implicitHeight + 12
            color: "transparent"
            border.width: 1
            border.color: Theme.lineMid
            opacity: 0
            transform: Translate { id: lift; y: root.above ? 3 : -3; Behavior on y { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            Component.onCompleted: { opacity = 1; lift.y = 0 }
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0.02, 0.02, 0.02, 0.86) }
            Text {
                id: words
                anchors.centerIn: parent
                text: root.text
                font.family: Theme.font
                font.pixelSize: Theme.textS
                font.weight: Theme.weightValue
                color: Theme.textValue
            }
        }
    }
}

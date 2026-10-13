pragma ComponentBehavior: Bound
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
            const top = root.parent.mapToItem(null, 0, 0)
            const bottom = top.y + root.parent.height
            sourceComponent = bubble
            active = true
            const b = item as Item
            if (b) {
                b.x = Math.max(8, Math.min(win.width - b.width - 8, top.x))
                // Where it was asked for, unless the window ends there: then the other side.
                const under = bottom + 6, over = top.y - b.height - 6
                const fitsUnder = under + b.height <= win.height - 8, fitsOver = over >= 8
                b.y = (root.above ? !fitsOver && fitsUnder : fitsUnder || !fitsOver) ? Math.min(under, win.height - b.height - 8) : Math.max(8, over)
            }
        }
        function hide() { active = false }
    }

    Component {
        id: bubble
        GlassPanel {
            id: tipBox
            parent: root.Window.window ? root.Window.window.contentItem : null
            z: 1000
            width: words.width + 20
            height: words.implicitHeight + 12
            shade: 0.86
            opacity: 0
            transform: Translate { id: lift; y: root.above ? 3 : -3; Behavior on y { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } } }
            Component.onCompleted: { opacity = 1; lift.y = 0 }
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            // A long line wraps inside the window.
            TextMetrics { id: natural; font: words.font; text: root.text }
            Text {
                id: words
                anchors.centerIn: parent
                width: Math.min(Math.ceil(natural.advanceWidth) + 1, (tipBox.parent ? tipBox.parent.width : 400) - 36, 420)
                wrapMode: Text.Wrap
                text: root.text
                font.family: Theme.font
                font.pixelSize: Theme.textS
                font.weight: Theme.weightValue
                color: Theme.textValue
            }
        }
    }
}

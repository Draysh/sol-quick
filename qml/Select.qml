pragma ComponentBehavior: Bound
import QtQuick

/*
    A label and a choice from a short list, underlined like a field. The
    list drops out of the line; focus lights the line from the left. Space,
    Enter or Down opens it, Up and Down choose, Enter takes the choice,
    Escape, Tab or a click elsewhere closes it. `value` is the caller's:
    `chosen` says what was picked, and the caller sets it.

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
    /** The row the keys are on while the list is open. */
    property int at: 0

    implicitWidth: 240
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: label
    Accessible.description: current ? current.label : placeholder

    function show() {
        if (!enabled || options.length === 0) return
        at = Math.max(0, options.findIndex(o => o.value === value))
        // Placed once as it opens; a wheel or a click elsewhere closes it.
        const p = line.mapToItem(drop.parent, 0, line.height)
        drop.x = p.x
        drop.y = p.y + 2
        open = true
    }
    function pick(i) {
        const o = options[i]
        open = false
        if (o && o.value !== value) chosen(o.value)
    }
    onActiveFocusChanged: if (!activeFocus) open = false
    Keys.onPressed: event => {
        const k = event.key
        if (!open) {
            if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Down) { show(); event.accepted = true }
            return
        }
        event.accepted = true
        if (k === Qt.Key_Escape) open = false
        else if (k === Qt.Key_Up) at = Math.max(0, at - 1)
        else if (k === Qt.Key_Down) at = Math.min(options.length - 1, at + 1)
        else if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) pick(at)
        else event.accepted = false
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
                color: root.current && root.enabled ? Theme.text : Theme.textFaint
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
            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(); if (root.open) root.open = false; else root.show() } }
        }

        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width }
    }

    // The list, over whatever is under it, on the window so nothing clips it.
    Item {
        id: drop
        parent: root.Window.window ? root.Window.window.contentItem : root
        visible: root.open || panel.opacity > 0
        z: 900
        width: line.width
        height: list.implicitHeight + 2

        // Over the page (not under it), so the click or wheel closes the list
        // instead of reaching the page.
        MouseArea { parent: drop.parent; anchors.fill: parent; z: 899; enabled: root.open; onClicked: root.open = false; onWheel: root.open = false }

        Rectangle {
            id: panel
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
                        id: option
                        required property var modelData
                        required property int index
                        readonly property bool chosen: modelData.value === root.value
                        width: list.width
                        height: Theme.control
                        Rectangle { anchors.fill: parent; color: hover.containsMouse || option.index === root.at ? Theme.surfaceHover : option.chosen ? Theme.surface : "transparent" }
                        Rectangle { visible: option.index === root.at; width: 2; height: parent.height - 16; y: 8; color: Theme.world }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; x: 12
                            width: parent.width - 24
                            text: option.modelData.label
                            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                            color: option.chosen ? Theme.textBright : Theme.text
                            elide: Text.ElideRight
                        }
                        MouseArea { id: hover; anchors.fill: parent; enabled: root.open; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.at = option.index; onClicked: root.pick(option.index) }
                    }
                }
            }
        }
    }
}

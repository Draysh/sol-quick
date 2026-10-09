import QtQuick

/*
    One right-click menu for the whole app: a hairline panel at the
    pointer, kept inside the window; an entry with `items` (a function
    returning entries, or a promise of them) opens its list beside it.
    Escape, a click elsewhere or a wheel closes it.

    Entries: `{ label, run }`, `{ label, run, danger: true }`,
    `{ label, items: () => [...] }`, `{ separator: true }`.

        ContextMenu { id: menu }   // once, in the window
        menu.show(mouse.x, mouse.y, entries)   // window coordinates
        menu.showUnder(button, entries)
*/
Item {
    id: menu

    property var entries: []
    property bool open: false
    property real atX: 0
    property real atY: 0
    property int subIndex: -1
    property var subEntries: null

    anchors.fill: parent
    visible: open
    z: 900

    function show(x, y, list) {
        entries = list
        subIndex = -1
        subEntries = null
        atX = x
        atY = y
        open = true
        panel.forceActiveFocus()
    }
    /** Under a control, e.g. a ⋯ button. */
    function showUnder(item, list) {
        const p = item.mapToItem(menu, item.width, item.height)
        show(p.x, p.y, list)
    }
    function close() { open = false }

    function choose(entry, index) {
        if (entry.separator) return
        if (entry.items) {
            subIndex = index
            subEntries = null
            Promise.resolve(entry.items()).then(list => { if (menu.subIndex === index) menu.subEntries = list })
            return
        }
        close()
        entry.run()
    }

    Keys.onEscapePressed: close()
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: menu.close(); onWheel: menu.close() }

    component Entry: Item {
        id: row
        property var entry
        property int index: 0
        property bool sub: false
        width: parent.width
        height: entry.separator ? Theme.s2 + 1 : 34
        Rectangle { visible: !!row.entry.separator; y: Theme.s1; width: parent.width; height: 1; color: Theme.line }
        Rectangle { visible: !row.entry.separator; anchors.fill: parent; color: rowMouse.containsMouse || (!row.sub && menu.subIndex === row.index) ? Theme.surfaceHover : "transparent"; Behavior on color { ColorAnimation { duration: Theme.lock } } }
        Text {
            visible: !row.entry.separator
            x: Theme.s3; width: parent.width - Theme.s3 * 2 - (row.entry.items ? 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.label || ""
            elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
            color: row.entry.danger ? Theme.dangerText : rowMouse.containsMouse ? Theme.textBright : Theme.textValue
        }
        Text { visible: !row.entry.separator && !!row.entry.items; anchors.right: parent.right; anchors.rightMargin: Theme.s3; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: !row.entry.separator
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.choose(row.entry, row.index)
            onEntered: if (!row.sub && row.entry.items) menu.choose(row.entry, row.index)
        }
    }

    Rectangle {
        id: panel
        x: Math.max(8, Math.min(menu.atX, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.atY, menu.height - height - 8))
        width: 220
        height: list.implicitHeight + Theme.s1 * 2
        color: "transparent"
        border.width: 1; border.color: Theme.lineStrong
        focus: true
        Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0, 0, 0, 0.82) }
        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.96
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.lock; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: mouse => mouse.accepted = true }
        Column {
            id: list
            x: 0; y: Theme.s1
            width: parent.width
            Repeater { model: menu.entries; delegate: Entry { required property var modelData; required property int index; entry: modelData; index: index } }
        }

        // The list beside an entry with items.
        Rectangle {
            id: subPanel
            visible: menu.subIndex >= 0
            x: parent.x + parent.width + subPanel.width + 16 > menu.width ? -width : parent.width
            y: Math.max(-panel.y + 8, Math.min(menu.subIndex * 34, menu.height - panel.y - height - 8))
            width: 220
            height: Math.min(menu.height * 0.6, subList.implicitHeight + Theme.s1 * 2)
            color: "transparent"
            border.width: 1; border.color: Theme.lineStrong
            clip: true
            Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0, 0, 0, 0.82) }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: mouse => mouse.accepted = true }
            Flickable {
                anchors.fill: parent; anchors.margins: 1
                contentHeight: subList.implicitHeight
                clip: true
                Column {
                    id: subList
                    y: Theme.s1
                    width: parent.width
                    Text { visible: menu.subEntries === null; x: Theme.s3; height: 34; verticalAlignment: Text.AlignVCenter; text: "…"; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet }
                    Repeater { model: menu.subEntries || []; delegate: Entry { required property var modelData; required property int index; entry: modelData; index: index; sub: true } }
                }
            }
        }
    }
}

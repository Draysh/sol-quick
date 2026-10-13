pragma ComponentBehavior: Bound
import QtQuick

/*
    One right-click menu for the whole app: a hairline panel at the
    pointer, kept inside the window; an entry with `items` (its entries, a
    function returning them, or a promise of them) opens its list beside
    it, or over it where the window has no room beside: ten "Rate N" rows
    become one "Rate…" with its numbers inside. The palette shows the same
    entries (a page's `actions`), a nested one as a row that opens its list. Up and Down choose, Enter
    runs, Right opens a list and Left closes it; Escape, a click elsewhere
    or a wheel closes the menu.

    Entries: `{ label, run }`, `{ label, run, danger: true }`,
    `{ label, items: [...] }` (or `items: () => [...]`), `{ separator: true }`; any of them may
    lead with an `icon` (an `Icon` name), for the common actions, and the
    other labels in that list line up after it.

        ContextMenu { id: menu }   // once, in the window
        menu.show(mouse.x, mouse.y, entries)   // window coordinates
        menu.showUnder(button, entries)
        menu.openAt(item, mouse, entries)   // at a mouse event in `item`, or under `item` without one

    A thing's menu is one function of the thing, given to its Card (`menu`),
    its row (MenuArea) and its ⋯ (MoreButton), so the right-click and the
    button always agree.
*/
Item {
    id: menu

    property var entries: []
    property bool open: false
    property real atX: 0
    property real atY: 0
    property int subIndex: -1
    /** Where the entry with the open list sits in the panel. */
    property real subAt: 0
    property var subEntries: null
    /** What had the keys before; it gets them back on close. */
    property Item before: null
    /** The entry the keys are on (-1: none yet), in the menu and in the open list. */
    property int at: -1
    property int subKey: -1
    /** The keys are in the open list. */
    property bool inSub: false

    readonly property int rowHeight: 34

    anchors.fill: parent
    // Stays until it has faded out.
    visible: open || panel.opacity > 0
    z: 900

    function show(x, y, list) {
        entries = list
        subIndex = -1
        subEntries = null
        at = -1
        subKey = -1
        inSub = false
        atX = x
        atY = y
        if (!open) before = Window.window ? Window.window.activeFocusItem : null
        open = true
        panel.forceActiveFocus()
    }
    /** Under a control, e.g. a ⋯ button. */
    function showUnder(item, list) {
        const p = item.mapToItem(menu, item.width, item.height)
        show(p.x, p.y, list)
    }
    /** At a mouse event in `item` (a right-click), or under `item` when `mouse` is null (a ⋯ button).
        `entries` may be a function returning them, called now. */
    function openAt(item, mouse, entries) {
        const list = typeof entries === "function" ? entries() : entries
        if (!list || !list.length) return
        if (mouse) { const p = item.mapToItem(menu, mouse.x, mouse.y); show(p.x, p.y, list) }
        else showUnder(item, list)
    }
    function close() {
        if (!open) return
        open = false
        panel.focus = false
        if (before) before.forceActiveFocus()
        before = null
    }

    function choose(entry, index, at) {
        if (!open || entry.separator) return
        if (entry.items) {
            if (subIndex === index) return
            subIndex = index
            subAt = at
            subEntries = null
            subKey = -1
            Promise.resolve(typeof entry.items === "function" ? entry.items() : entry.items).then(list => { if (menu.subIndex === index) menu.subEntries = list })
            return
        }
        close()
        entry.run()
    }

    /** The next entry from `from` that can be chosen, `by` +1 or -1, wrapping round. */
    function step(list, from, by) {
        const n = list.length
        for (let k = 1; k <= n; k++) {
            const i = ((from < 0 && by < 0 ? n : from) + by * k + n * 2) % n
            if (!list[i].separator) return i
        }
        return -1
    }
    /** Where entry `i` sits in its list, for the list beside it. */
    function rowY(list, i) {
        let y = Theme.s1
        for (let k = 0; k < i; k++) y += list[k].separator ? Theme.s2 + 1 : rowHeight
        return y
    }
    Keys.onPressed: event => {
        if (!open) return
        const k = event.key
        const list = inSub ? (subEntries || []) : entries
        event.accepted = true
        if (k === Qt.Key_Escape) { if (inSub) { inSub = false; subKey = -1 } else close() }
        else if (k === Qt.Key_Down || k === Qt.Key_Up) {
            const i = step(list, inSub ? subKey : at, k === Qt.Key_Down ? 1 : -1)
            if (inSub) subKey = i; else at = i
        }
        else if (k === Qt.Key_Right && !inSub) {
            const e = entries[at]
            if (e && e.items) { choose(e, at, rowY(entries, at)); inSub = true; subKey = -1 }
        }
        else if (k === Qt.Key_Left && inSub) { inSub = false; subKey = -1 }
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            const i = inSub ? subKey : at
            const e = list[i]
            if (!e) return
            if (!inSub && e.items) { choose(e, i, rowY(entries, i)); inSub = true; subKey = -1 }
            else choose(e, i, 0)
        }
        else event.accepted = false
    }
    MouseArea { anchors.fill: parent; enabled: menu.open; acceptedButtons: Qt.AllButtons; onPressed: menu.close(); onWheel: menu.close() }

    component Entry: Item {
        id: row
        required property var modelData
        required property int index
        readonly property var entry: modelData
        property bool sub: false
        readonly property bool keyed: sub ? menu.inSub && menu.subKey === row.index : !menu.inSub && menu.at === row.index
        // Some entry in this list has an icon: every label starts after the icons' column.
        readonly property bool indent: (row.sub ? (menu.subEntries || []) : menu.entries).some(e => e && !!e.icon)
        readonly property real textX: Theme.s3 + (row.indent ? 16 + Theme.s2 : 0)
        readonly property bool lit: rowMouse.containsMouse || row.keyed || (!row.sub && menu.subIndex === row.index)
        width: parent.width
        height: entry.separator ? Theme.s2 + 1 : menu.rowHeight
        Rectangle { visible: !!row.entry.separator; y: Theme.s1; width: parent.width; height: 1; color: Theme.line }
        // The light on a row, inset from the panel's edges and rounded with it.
        Rectangle { visible: !row.entry.separator; anchors.fill: parent; anchors.leftMargin: Theme.s1; anchors.rightMargin: Theme.s1; radius: Theme.radiusM; color: row.lit ? Theme.surfaceHover : "transparent"; Behavior on color { ColorAnimation { duration: Theme.lock } } }
        // The keys' row, marked as the palette and the lists mark theirs.
        Rectangle { visible: row.keyed; x: Theme.s1; width: 2; height: parent.height - 14; y: 7; radius: 1; color: Theme.accent }
        Icon {
            visible: !row.entry.separator && !!row.entry.icon
            x: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            name: row.entry.icon || "close"
            size: 16
            color: row.entry.danger ? Theme.dangerText : row.lit ? Theme.textBright : Theme.textQuiet
        }
        Text {
            visible: !row.entry.separator
            x: row.textX; width: parent.width - row.textX - Theme.s3 - (row.entry.items ? 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.label || ""
            elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
            color: row.entry.danger ? Theme.dangerText : row.lit ? Theme.textBright : Theme.textValue
        }
        Text { visible: !row.entry.separator && !!row.entry.items; anchors.right: parent.right; anchors.rightMargin: Theme.s3; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: !row.entry.separator
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.choose(row.entry, row.index, row.y)
            onEntered: {
                if (row.sub) { menu.inSub = true; menu.subKey = row.index; return }
                menu.inSub = false
                menu.at = row.index
                if (row.entry.items) menu.choose(row.entry, row.index, row.y)
            }
        }
    }

    GlassPanel {
        id: panel
        x: Math.max(8, Math.min(menu.atX, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.atY, menu.height - height - 8))
        width: Math.min(220, menu.width - 16)
        height: list.implicitHeight + Theme.s1 * 2
        edge: Theme.lineStrong
        focus: true
        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.96
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.lock; easing: Theme.easeOut } }
        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: mouse => mouse.accepted = true }
        Column {
            id: list
            x: 0; y: Theme.s1
            width: parent.width
            Repeater { model: menu.entries; delegate: Entry { } }
        }

        // The list beside an entry with items: to the right, else to the left,
        // else (a narrow window) over the menu, a row down, so its entry still shows.
        GlassPanel {
            id: subPanel
            readonly property bool toRight: panel.x + panel.width + width + 8 <= menu.width
            readonly property bool toLeft: panel.x - width - 8 >= 0
            readonly property bool over: !toRight && !toLeft
            visible: menu.subIndex >= 0
            x: toRight ? panel.width + 2 : toLeft ? -width - 2 : menu.width - 8 - width - panel.x
            // Level with its entry, kept inside the window.
            y: Math.max(-panel.y + 8, Math.min(menu.subAt + (over ? menu.rowHeight : 0), menu.height - panel.y - height - 8))
            width: Math.min(220, menu.width - 16)
            height: Math.min(menu.height * 0.6, subList.implicitHeight + Theme.s1 * 2)
            edge: Theme.lineStrong
            shade: subPanel.over ? 0.9 : 0.82
            clip: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.lock } }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: mouse => mouse.accepted = true }
            Flickable {
                id: subFlick
                anchors.fill: parent; anchors.margins: 1
                contentHeight: subList.implicitHeight + Theme.s1 * 2
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Column {
                    id: subList
                    y: Theme.s1
                    width: parent.width
                    Text { visible: menu.subEntries === null; x: Theme.s3; height: menu.rowHeight; verticalAlignment: Text.AlignVCenter; text: "…"; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet }
                    Repeater { model: menu.subEntries || []; delegate: Entry { sub: true } }
                }
            }
        }
    }
    // The keys' row in the open list stays in sight.
    onSubKeyChanged: if (subKey >= 0) Theme.keepInView(subFlick, rowY(subEntries || [], subKey), rowHeight)
}

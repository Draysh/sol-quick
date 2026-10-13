pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Sol.Design

/*
    The command palette: Ctrl+K opens a glass panel over the window with
    one field. It finds the app's sections (a moon's and a section's
    children named with their group: "Titan · History"; a section's tabs
    too), the actions the app offers, and, as you type, whatever the app's
    `find` turns up (titles, albums, words). Empty, it shows the sections
    and every action. An action with `items` (a menu's nested entry: one
    "Rate…" with its numbers inside) is one row that opens its own list;
    typing finds the entries inside it too. Up and down choose, Enter runs
    (or opens), Escape or Left goes back out of a list, then closes.

        CommandPalette { id: palette; sections: shell.sections; commands: [{ label: "Pick one for me", hint: "…", run: () => … }]; find: q => Sol.call("search", { query: q }).then(…) }
*/
Item {
    id: root

    property var sections: []
    /** `{ label, hint, keys, icon, run }`; `icon` (an `Icon` name) leads the row, for a common action.
        `{ label, items }` opens its own list (ContextMenu's entries: a list, or a function or promise of one). */
    property var commands: []
    /** `function(query) → Promise<[{ label, hint, icon, run }]>`, or null. */
    property var find: null
    property var go: null
    property bool open: false
    /** Closed again, so whatever had the keys before can have them back. */
    signal closed()

    property var found: []
    property int at: 0
    property bool busy: false

    anchors.fill: parent
    // Stays until it has faded out.
    visible: open || box.opacity > 0
    z: 940

    /** Opens it, empty, or with `typed` already in the field (a staged picture: `_palette=rate`). */
    function show(typed) { trail = []; field.text = typed || ""; found = []; at = 0; rows.contentY = 0; open = true; Qt.callLater(() => field.input.forceActiveFocus()) }
    function close() {
        if (!open) return
        open = false
        // A hidden field would keep the keys.
        field.input.focus = false
        closed()
    }
    function move(by) { at = Math.max(0, Math.min(entries.length - 1, at + by)) }

    readonly property string q: field.text.trim().toLowerCase()
    /** The lists opened from a row with `items`, outermost first: `{ label, entries }`; empty at the top. */
    property var trail: []
    /** Opens `e`'s own list in place of the rows. */
    function enter(e) {
        const label = e.label
        Promise.resolve(typeof e.items === "function" ? e.items() : e.items).then(list => {
            if (!root.open) return
            root.trail = root.trail.concat([{ label: label, entries: (list || []).filter(x => x && !x.separator) }])
            field.text = ""
            root.at = 0
            rows.contentY = 0
        })
    }
    /** Back out of the open list; false at the top. */
    function leave() {
        if (!trail.length) return false
        trail = trail.slice(0, -1)
        field.text = ""
        at = 0
        return true
    }
    /** A label without its "…", for the entries found inside it ("Rate…" and "8": "Rate 8"). */
    function stem(label) { return label.replace(/(…|\.\.\.)$/, "") }
    /** Everything the palette knows, scored against the words typed. */
    readonly property var entries: {
        if (trail.length) {
            const inside = trail[trail.length - 1].entries
            if (q === "") return inside
            return ranked(inside)
        }
        const top = [], deeper = [], inner = []
        for (const s of sections) {
            const group = s.group ? s.group + " · " : ""
            top.push({ label: "Go to " + group + s.label, hint: s.hint || "", keys: "", icon: s.icon || "", kind: "section", run: () => root.go && root.go(s.path) })
            const tabsOf = (p, name, icon) => { for (const t of p.tabs || []) deeper.push({ label: "Go to " + name + " · " + t.label, hint: t.hint || "", keys: "", icon: icon, kind: "section", run: () => root.go && root.go(p.path + "?tab=" + encodeURIComponent(t.id)) }) }
            tabsOf(s, group + s.label, s.icon || "")
            for (const c of s.children || []) {
                deeper.push({ label: "Go to " + group + s.label + " · " + c.label, hint: c.hint || "", keys: "", icon: c.icon || s.icon || "", kind: "section", run: () => root.go && root.go(c.path) })
                tabsOf(c, group + c.label, c.icon || s.icon || "")
            }
        }
        const commands = root.commands.filter(c => c && !c.separator).map(c => Object.assign({ kind: "command" }, c))
        // With nothing typed: the sections, then every action.
        if (q === "") return top.concat(commands)
        // Typed: the entries inside a list too, named with it.
        for (const c of commands) if (Array.isArray(c.items)) for (const e of c.items) if (e && !e.separator && !e.items) inner.push(Object.assign({ kind: "command" }, e, { label: stem(c.label) + " " + e.label, icon: e.icon || c.icon || "" }))
        const all = top.concat(deeper, commands, inner, found.map(f => Object.assign({ kind: "found" }, f)))
        return ranked(all).slice(0, 12)
    }
    /** `list` scored against the words typed, best first; level ones keep their order (a list's own entries stay 1 to 10). */
    function ranked(list) {
        return list.map((e, i) => ({ e, i, score: score(e.label, q) + score(e.hint || "", q) * 0.3 })).filter(x => x.score > 0 || x.e.kind === "found")
            .sort((a, b) => b.score - a.score || a.i - b.i).map(x => x.e)
    }
    onEntriesChanged: at = Math.min(at, Math.max(0, entries.length - 1))
    // The keys' row stays in sight.
    onAtChanged: Qt.callLater(() => { const it = rowRepeater.itemAt(root.at); if (it) Theme.keepInView(rows, it.y, it.height) })
    /** The groups the rows come under, by kind: their HUD capitals and Japanese. */
    readonly property var groups: ({ section: { label: "Go to", jp: "移動" }, command: { label: "Actions", jp: "操作" }, found: { label: "Found", jp: "検索" } })
    /** The whole text, then its start, then a word's start, then anywhere, then the
        letters in order; the earlier in the text, the better ("sett" finds
        "Go to Settings" before a long title with "Settei" in its middle). */
    function score(text, q) {
        const t = text.toLowerCase()
        if (t === q) return 10
        if (t.startsWith(q)) return 6
        const word = t.search(new RegExp("\\b" + q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")))
        if (word >= 0) return 5 - Math.min(word, 100) * 0.01
        const at = t.indexOf(q)
        if (at >= 0) return 4 - Math.min(at, 100) * 0.01
        let i = 0
        for (const ch of t) if (ch === q[i]) i++
        return i === q.length ? 1 : 0
    }
    onQChanged: look.restart()
    Timer {
        id: look
        interval: 180
        onTriggered: {
            const q = root.q
            if (!root.find || q.length < 2 || root.trail.length) { root.found = []; return }
            root.busy = true
            Promise.resolve(root.find(q)).then(list => { if (q === root.q) root.found = list || [] }).catch(() => { }).finally(() => root.busy = false)
        }
    }
    function run() {
        const e = entries[at]
        if (!open || !e) return
        if (e.items) { enter(e); return }
        close()
        if (e.run) e.run()
    }


    Item { anchors.fill: parent; opacity: root.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.45; tint: Theme.tint(Theme.frost, Theme.light ? 0.86 : 0.5) }
        MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.close() } }

    Item {
        id: box
        x: (parent.width - width) / 2
        y: Math.min(parent.height * 0.18, 120)
        width: Math.min(560, parent.width - 32)
        height: column.implicitHeight + 2
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
        MouseArea { anchors.fill: parent }
        GlassPanel { anchors.fill: parent; edge: Theme.lineStrong; shade: 0.86 }

        Column {
            id: column
            x: 1; y: 1
            width: parent.width - 2
            // The HUD line along its top.
            Item {
                width: parent.width
                height: 30
                Row {
                    x: Theme.s4
                    anchors.bottom: parent.bottom
                    spacing: Theme.s2
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; rotation: 45; antialiasing: true; color: Theme.hudAccent }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "コマンド"; font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 2; font.weight: Theme.weightTitle; color: Theme.hudAccent }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Command · Ctrl+K"; font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold; font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase; color: Theme.hudAccent }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: Theme.s4; anchors.bottom: parent.bottom; text: root.busy ? "Looking…" : root.trail.length ? "Esc · back" : "Esc"; font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold; font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase; color: Theme.hudFaint }
            }
            Item {
                width: parent.width
                height: 52
                // In a list opened from a row: its name before the field.
                Text {
                    id: crumb
                    visible: root.trail.length > 0
                    x: Theme.s4
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.4)
                    elide: Text.ElideRight
                    text: root.trail.map(t => root.stem(t.label)).join(" › ") + " ›"
                    font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: Theme.weightValue
                    color: Theme.textWorld
                }
                Field { id: field; bare: true; x: crumb.visible ? crumb.x + crumb.width + Theme.s2 : Theme.s4; width: parent.width - x - Theme.s4; anchors.verticalCenter: parent.verticalCenter; label: ""
                    placeholder: root.trail.length ? "Choose one" : root.find ? "Go somewhere, do something, find anything" : "Go somewhere, do something"
                    Keys.onUpPressed: event => { root.move(-1); event.accepted = true }
                    Keys.onDownPressed: event => { root.move(1); event.accepted = true }
                    Keys.onEscapePressed: { if (!root.leave()) root.close() }
                    // Right opens the chosen row's list; Left with nothing typed goes back out.
                    Keys.onRightPressed: event => { const e = root.entries[root.at]; if (e && e.items && field.input.cursorPosition === field.text.length) { root.enter(e); event.accepted = true } else event.accepted = false }
                    Keys.onLeftPressed: event => { if (field.text === "" && root.leave()) event.accepted = true; else event.accepted = false }
                    onAccepted: root.run() }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
            // As many rows as the window has room for; the rest scroll, the keys' row in sight.
            Flickable {
                id: rows
                width: parent.width
                height: Math.min(contentHeight, Math.max(44, root.height - box.y - 84 - Theme.s1 - Theme.s4))
                contentHeight: rowColumn.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Column {
                    id: rowColumn
                    width: rows.width
                    Repeater {
                        id: rowRepeater
                        model: root.entries
                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool on: index === root.at
                            /** The first of its kind among the rows (at the top only): its group's name over it. */
                            readonly property var group: root.trail.length ? null : (index === 0 || root.entries[index - 1].kind !== modelData.kind) ? root.groups[modelData.kind] || null : null
                            readonly property real head: group ? 30 : 0
                            // What the label, the hint and the keys share: the label first.
                            readonly property real room: width - Theme.s4 * 2 - (keysText.visible ? keysText.implicitWidth + Theme.s3 : 0)
                            width: rowColumn.width
                            height: 44 + head
                            Row {
                                visible: !!row.group
                                x: Theme.s4
                                y: Theme.s3 - 2
                                spacing: Theme.s2
                                Text { anchors.verticalCenter: parent.verticalCenter; text: row.group ? row.group.jp : ""; font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 2; font.weight: Theme.weightTitle; color: Theme.hudQuiet }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: row.group ? row.group.label : ""; font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold; font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase; color: Theme.hudQuiet }
                            }
                            // The light on the chosen row: a slanted bar in the world's light.
                            Shape {
                                y: row.head
                                width: parent.width; height: 44
                                visible: row.on
                                preferredRendererType: Shape.CurveRenderer
                                readonly property real lean: 14
                                ShapePath {
                                    strokeWidth: 0; strokeColor: "transparent"
                                    fillGradient: LinearGradient {
                                        x1: 0; y1: 0; x2: rowColumn.width; y2: 0
                                        GradientStop { position: 0; color: Theme.tint(Theme.hudAccent, 0.26) }
                                        GradientStop { position: 1; color: Theme.tint(Theme.hudAccent, 0.02) }
                                    }
                                    startX: Theme.s2 + 14; startY: 4
                                    PathLine { x: rowColumn.width - Theme.s2; y: 4 }
                                    PathLine { x: rowColumn.width - Theme.s2 - 14; y: 40 }
                                    PathLine { x: Theme.s2; y: 40 }
                                    PathLine { x: Theme.s2 + 14; y: 4 }
                                }
                            }
                            Row {
                                x: Theme.s4 + Theme.s1
                                y: row.head + (44 - height) / 2
                                spacing: Theme.s3
                                Text { id: labelText; text: row.modelData.label; width: Math.max(0, Math.min(implicitWidth, row.room)); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: row.on ? Theme.weightName : Theme.weightValue; color: row.modelData.danger ? Theme.dangerText : row.on ? Theme.textBright : Theme.text }
                                Text { readonly property real spare: row.room - labelText.width - Theme.s3; visible: !!row.modelData.hint && spare >= 60; text: row.modelData.hint || ""; width: Math.max(0, Math.min(implicitWidth, spare)); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet; anchors.verticalCenter: parent.verticalCenter }
                            }
                            // Its keys, or for a row with a list of its own, the way in.
                            Quiet { id: keysText; visible: !!row.modelData.keys || !!row.modelData.items; anchors.right: parent.right; anchors.rightMargin: Theme.s4; y: row.head + (44 - height) / 2; text: row.modelData.items ? "›" : row.modelData.keys || "" }
                            MouseArea { y: row.head; width: parent.width; height: 44; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.at = row.index; onClicked: root.run() }
                        }
                    }
                }
            }
            Item { visible: root.entries.length === 0; width: parent.width; height: 44
                Quiet { x: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Looking…" : "Nothing for that"; caps: false } }
            // Room under the last row, so its light clears the panel's corners.
            Item { width: parent.width; height: Theme.s1 }
        }
    }
}

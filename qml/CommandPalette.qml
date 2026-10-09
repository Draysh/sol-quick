pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The command palette: Ctrl+K opens a glass panel over the window with
    one field. It finds the app's sections, the actions the app offers,
    and, as you type, whatever the app's `find` turns up (titles, albums,
    words). Up and down choose, Enter runs, Escape closes.

        CommandPalette { id: palette; sections: shell.sections; commands: [{ label: "Pick one for me", hint: "…", run: () => … }]; find: q => Sol.call("search", { query: q }).then(…) }
*/
Item {
    id: root

    property var sections: []
    /** `{ label, hint, keys, run }` */
    property var commands: []
    /** `function(query) → Promise<[{ label, hint, run }]>`, or null. */
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

    function show() { field.text = ""; found = []; at = 0; open = true; Qt.callLater(() => field.input.forceActiveFocus()) }
    function close() {
        if (!open) return
        open = false
        // A hidden field would keep the keys.
        field.input.focus = false
        closed()
    }
    function move(by) { at = Math.max(0, Math.min(entries.length - 1, at + by)) }

    readonly property string q: field.text.trim().toLowerCase()
    /** Everything the palette knows, scored against the words typed. */
    readonly property var entries: {
        const all = []
        for (const s of sections) all.push({ label: "Go to " + s.label, hint: s.hint || "", keys: "", kind: "section", run: () => root.go && root.go(s.path) })
        for (const c of commands) all.push(Object.assign({ kind: "command" }, c))
        for (const f of found) all.push(Object.assign({ kind: "found" }, f))
        if (q === "") return all.slice(0, 12)
        return all.map(e => ({ e, score: score(e.label, q) + score(e.hint || "", q) * 0.3 })).filter(x => x.score > 0 || x.e.kind === "found").sort((a, b) => b.score - a.score).map(x => x.e).slice(0, 12)
    }
    onEntriesChanged: at = Math.min(at, Math.max(0, entries.length - 1))
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
            if (!root.find || q.length < 2) { root.found = []; return }
            root.busy = true
            Promise.resolve(root.find(q)).then(list => { if (q === root.q) root.found = list || [] }).catch(() => { }).finally(() => root.busy = false)
        }
    }
    function run() {
        const e = entries[at]
        if (!open || !e) return
        close()
        e.run()
    }


    Item { anchors.fill: parent; opacity: root.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.45; tint: Qt.rgba(0, 0, 0, 0.5) }
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
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        MouseArea { anchors.fill: parent }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Theme.lineStrong
            Glass { anchors.fill: parent; anchors.margins: 1; tint: Qt.rgba(0, 0, 0, 0.86) } }

        Column {
            id: column
            x: 1; y: 1
            width: parent.width - 2
            Item {
                width: parent.width
                height: 56
                Field { id: field; x: Theme.s4; width: parent.width - Theme.s4 * 2 - 70; anchors.verticalCenter: parent.verticalCenter; label: ""; placeholder: root.find ? "Go somewhere, do something, find anything" : "Go somewhere, do something"
                    Keys.onUpPressed: event => { root.move(-1); event.accepted = true }
                    Keys.onDownPressed: event => { root.move(1); event.accepted = true }
                    Keys.onEscapePressed: root.close()
                    onAccepted: root.run() }
                Quiet { anchors.right: parent.right; anchors.rightMargin: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Looking…" : "Esc" }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
            Repeater {
                model: root.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.at
                    width: column.width
                    height: 44
                    Rectangle { anchors.fill: parent; color: row.on ? Theme.surfaceHover : "transparent"; Behavior on color { ColorAnimation { duration: Theme.lock } } }
                    Rectangle { visible: row.on; width: 2; height: parent.height - 16; y: 8; color: Theme.world }
                    Row {
                        x: Theme.s4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.s3
                        Text { text: row.modelData.label; font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: Theme.weightValue; color: row.on ? Theme.textBright : Theme.text }
                        Text { visible: !!row.modelData.hint; text: row.modelData.hint || ""; width: Math.max(0, column.width - Theme.s4 * 2 - 220); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.textS; color: Theme.textQuiet; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Quiet { visible: !!row.modelData.keys; anchors.right: parent.right; anchors.rightMargin: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.keys || "" }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.at = row.index; onClicked: root.run() }
                }
            }
            Item { visible: root.entries.length === 0; width: parent.width; height: 44
                Quiet { x: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Looking…" : "Nothing for that"; font.capitalization: Font.MixedCase } }
        }
    }
}

import QtQuick
import Sol.Design

/*
    The command palette: Ctrl+K opens a glass panel over the window with
    one field. It finds the app's sections, the actions the app offers,
    and, as you type, whatever the app's `find` turns up (titles, albums,
    words). Up and down choose, Enter runs, Escape closes.

        Palette { id: palette; sections: shell.sections; commands: [{ label: "Pick one for me", hint: "…", run: () => … }]; find: q => Sol.call("search", { query: q }).then(…) }
*/
Item {
    id: palette

    property var sections: []
    /** `{ label, hint, keys, run }` */
    property var commands: []
    /** `function(query) → Promise<[{ label, hint, run }]>`, or null. */
    property var find: null
    property var go: null
    property bool open: false

    property var found: []
    property int at: 0
    property bool busy: false

    anchors.fill: parent
    visible: open
    z: 940

    function show() { field.text = ""; found = []; at = 0; open = true; Qt.callLater(() => field.input.forceActiveFocus()) }
    function close() { open = false }

    readonly property string q: field.text.trim().toLowerCase()
    /** Everything the palette knows, scored against the words typed. */
    readonly property var entries: {
        const all = []
        for (const s of sections) all.push({ label: "Go to " + s.label, hint: s.hint || "", keys: "", kind: "section", run: () => palette.go && palette.go(s.path) })
        for (const c of commands) all.push(Object.assign({ kind: "command" }, c))
        for (const f of found) all.push(Object.assign({ kind: "found" }, f))
        if (q === "") return all.slice(0, 12)
        return all.map(e => ({ e, score: score(e.label, q) + score(e.hint || "", q) * 0.3 })).filter(x => x.score > 0 || x.e.kind === "found").sort((a, b) => b.score - a.score).map(x => x.e).slice(0, 12)
    }
    onEntriesChanged: at = Math.min(at, Math.max(0, entries.length - 1))
    /** Whole words first, then a prefix, then the letters in order. */
    function score(text, q) {
        const t = text.toLowerCase()
        if (t === q) return 10
        if (t.startsWith(q)) return 6
        if (t.includes(q)) return 4
        let i = 0
        for (const ch of t) if (ch === q[i]) i++
        return i === q.length ? 1 : 0
    }
    onQChanged: look.restart()
    Timer {
        id: look
        interval: 180
        onTriggered: {
            const q = palette.q
            if (!palette.find || q.length < 2) { palette.found = []; return }
            palette.busy = true
            Promise.resolve(palette.find(q)).then(list => { if (q === palette.q) palette.found = list || [] }).catch(() => { }).finally(() => palette.busy = false)
        }
    }
    function run() {
        const e = entries[at]
        if (!e) return
        close()
        e.run()
    }

    Keys.onEscapePressed: close()
    Keys.onUpPressed: at = Math.max(0, at - 1)
    Keys.onDownPressed: at = Math.min(entries.length - 1, at + 1)
    Keys.onReturnPressed: run()
    Keys.onEnterPressed: run()

    Item { anchors.fill: parent; opacity: palette.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.45; tint: Qt.rgba(0, 0, 0, 0.5) }
        MouseArea { anchors.fill: parent; onClicked: palette.close() } }

    Item {
        id: box
        x: (parent.width - width) / 2
        y: Math.min(parent.height * 0.18, 120)
        width: Math.min(560, parent.width - 32)
        height: column.implicitHeight + 2
        opacity: palette.open ? 1 : 0
        scale: palette.open ? 1 : 0.97
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
                Field { id: field; x: Theme.s4; width: parent.width - Theme.s4 * 2 - 70; anchors.verticalCenter: parent.verticalCenter; label: ""; placeholder: palette.find ? "Go somewhere, do something, find anything" : "Go somewhere, do something"
                    Keys.onUpPressed: event => { palette.at = Math.max(0, palette.at - 1); event.accepted = true }
                    Keys.onDownPressed: event => { palette.at = Math.min(palette.entries.length - 1, palette.at + 1); event.accepted = true }
                    Keys.onEscapePressed: palette.close()
                    onAccepted: palette.run() }
                Quiet { anchors.right: parent.right; anchors.rightMargin: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: palette.busy ? "Looking…" : "Esc" }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
            Repeater {
                model: palette.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: index === palette.at
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
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: palette.at = row.index; onClicked: palette.run() }
                }
            }
            Item { visible: palette.entries.length === 0; width: parent.width; height: 44
                Quiet { x: Theme.s4; anchors.verticalCenter: parent.verticalCenter; text: palette.busy ? "Looking…" : "Nothing for that"; font.capitalization: Font.MixedCase } }
        }
    }
}

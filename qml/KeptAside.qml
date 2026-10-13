import QtQuick

/*
    The writes kept aside instead of sent, on a veil over the window: a
    document changed here and on another device (both copies, and which
    stays is the person's choice), a change Sol couldn't take, and changes
    from before this device was paired again with someone else. Nothing
    goes until the person says so; "Save a copy" writes them all to a file.
    The window has one (`win.keptAside`); its notices and the Sol card open it.

        KeptAside { id: keptAside }   // once, in the window
        keptAside.open()
        keptAside.open(sample)        // the gallery: these rows, nothing sent
*/
Item {
    id: root

    /** The kept writes, as `Sol.call("kept")` lists them. */
    property var writes: []
    property bool shown: false
    /** Showing rows it was handed (the gallery): choices only take them off the list. */
    property bool sample: false
    /** What had the keys before; it gets them back after. */
    property Item before: null

    anchors.fill: parent
    visible: shown || box.opacity > 0
    z: 940

    function open(rows) {
        before = Window.window ? Window.window.activeFocusItem : null
        shown = true
        sample = !!rows
        if (rows) writes = rows; else load()
        Qt.callLater(() => box.forceActiveFocus())
    }
    function close() {
        shown = false
        if (before) before.forceActiveFocus()
        before = null
    }
    function load() {
        Sol.call("kept").then(w => { root.writes = w || []; if (root.shown && root.writes.length === 0) root.close() })
            .catch(why => Sol.fail("Couldn’t list them", why))
    }
    function settle(command, seq) {
        if (sample) { writes = writes.filter(w => w.seq !== seq); return }
        Sol.call(command, { seq: seq }).then(() => root.load()).catch(why => Sol.fail("Not done", why))
    }
    // Something a person can read for a document: its name or title, else its JSON, short.
    function describe(kind, data) {
        if (kind === "delete" || data === null || data === undefined) return "deleted"
        if (kind === "event") return data.summary || data.type || "an event"
        if (kind === "widget" || kind === "unwidget") return "a widget on Sol’s overview"
        for (const key of ["name", "title", "label", "text", "summary"])
            if (typeof data[key] === "string" && data[key] !== "") return data[key]
        const json = JSON.stringify(data)
        return json.length > 120 ? json.slice(0, 117) + "…" : json
    }
    function what(w) {
        return w.collection ? w.collection + " · " + w.id : (w.kind === "event" ? "An event" : "A widget")
    }
    Connections { target: Sol; function onKeptChanged() { if (root.shown && !root.sample) root.load() } }

    Item { anchors.fill: parent; opacity: root.shown ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.5; tint: Theme.tint(Theme.frost, Theme.light ? 0.86 : 0.55) }
        MouseArea { anchors.fill: parent; enabled: root.shown; onClicked: root.close() } }

    Item {
        id: box
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 32)
        height: card.implicitHeight
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }
        Card {
            id: card
            width: parent.width
            radius: Theme.radiusL
            title: "Kept on this device"
            gap: Theme.s4
            Words { width: parent.width; small: true; quiet: true
                text: "These didn’t reach Sol as they were. Nothing here is lost: choose what stays, or save a copy first." }
            Flickable {
                width: parent.width
                height: Math.min(list.implicitHeight, root.height - 260)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: list
                    width: parent.width
                    spacing: Theme.s4
                    Repeater {
                        model: root.writes
                        delegate: Column {
                            id: entry
                            required property var modelData
                            readonly property var w: modelData
                            width: list.width
                            spacing: Theme.s2
                            Label { text: root.what(entry.w); width: parent.width }
                            DataRows {
                                width: parent.width
                                rows: entry.w.why === "conflict"
                                    ? [{ label: "On this device", value: root.describe(entry.w.kind, entry.w.data), keepCase: true },
                                       { label: "On another device", value: entry.w.theirs ? root.describe(entry.w.theirs.deleted ? "delete" : "put", entry.w.theirs.data) : "not there", keepCase: true }]
                                    : entry.w.why === "rejected"
                                    ? [{ label: "The change", value: root.describe(entry.w.kind, entry.w.data), keepCase: true }, { label: "Sol said", value: entry.w.message || "no", keepCase: true }]
                                    : [{ label: "The change", value: root.describe(entry.w.kind, entry.w.data), keepCase: true }, { label: "Made", value: "before this device was paired again" }]
                            }
                            Flow {
                                width: parent.width
                                spacing: Theme.s2
                                Button { visible: entry.w.why === "conflict"; variant: "primary"; text: "Keep this device’s"; onClicked: root.settle("keep_mine", entry.w.seq) }
                                Button { visible: entry.w.why === "conflict"; variant: "quiet"; text: "Keep the other"; onClicked: root.settle("drop_kept", entry.w.seq) }
                                Button { visible: entry.w.why !== "conflict"; variant: "quiet"; text: "Let it go"; onClicked: root.settle("drop_kept", entry.w.seq) }
                            }
                        }
                    }
                }
            }
            Row { spacing: Theme.s2
                Button { icon: "download"; text: "Save a copy"; enabled: root.writes.length > 0
                    onClicked: Sol.call("save_kept").then(path => Notices.show({ world: Sol.world, title: "Saved a copy", body: path })).catch(why => Sol.fail("Not saved", why)) }
                Button { variant: "quiet"; text: "Close"; onClicked: root.close() } }
        }
    }
}

pragma Singleton
import QtQuick

/*
    In-app notices: short messages at the top edge. They fade in and leave
    after six seconds unless hovered. The Shell shows them; anything can
    post one.

        Notices.show({ world: "terra", title: "Not saved", body: why, tone: "error" })
*/
QtObject {
    id: notices

    /** How long a notice stays, unless held. */
    readonly property int linger: 6000
    property ListModel list: ListModel {}
    property int next: 1
    property var timers: ({})

    function show(notice) {
        const id = next++
        list.append({ id: id, world: notice.world || "sol", title: notice.title || "", body: notice.body || "", tone: notice.tone || "info", cycle: 0 })
        while (list.count > 4) dismiss(list.get(0).id)
        wait(id)
        return id
    }

    /** Keeps a notice up while it is hovered or focused. */
    function hold(id) {
        if (timers[id]) { timers[id].stop(); timers[id].destroy(); delete timers[id] }
    }

    function wait(id) {
        hold(id)
        const t = Qt.createQmlObject("import QtQuick; Timer { }", notices)
        t.interval = linger
        t.triggered.connect(() => dismiss(id))
        timers[id] = t
        t.start()
    }

    /** Lets a held notice go: its time starts again. */
    function release(id) {
        const i = indexOf(id)
        if (i >= 0) list.setProperty(i, "cycle", list.get(i).cycle + 1)
        wait(id)
    }

    function dismiss(id) {
        hold(id)
        const i = indexOf(id)
        if (i >= 0) list.remove(i)
    }

    function indexOf(id) {
        for (let i = 0; i < list.count; i++) if (list.get(i).id === id) return i
        return -1
    }

    /** A failure as a notice: titled for what didn't happen, the reason as its body. */
    function failed(world, title, why) {
        return show({ world: world, title: title, body: String(why), tone: "error" })
    }
}

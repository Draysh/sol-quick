pragma Singleton
import QtQuick

/*
    In-app notices: short messages at the top edge. They fade in and leave
    after six seconds; the time stops while the pointer is on one. The
    window shows them; anything can post one.

        Notices.show({ world: "terra", title: "Not saved", body: why, tone: "error" })
        Notices.show({ title: "Changed on another device too", action: "See both", run: () => win.keptAside.open() })
*/
QtObject {
    id: notices

    /** How long a notice stays, unless held. */
    readonly property int linger: 6000
    /** Each row: key, world, title, body, tone, action (a button's label, or ""). */
    property ListModel list: ListModel {}
    property int next: 1
    /** What each notice's button does, by key. */
    property var runs: ({})

    /** Posts a notice; `action` and `run` add a button that runs it and closes the notice. */
    function show(notice) {
        const key = next++
        if (notice.action && notice.run) runs[key] = notice.run
        list.append({ key: key, world: notice.world || "sol", title: notice.title || "", body: notice.body || "", tone: notice.tone || "info", action: notice.action && notice.run ? notice.action : "" })
        while (list.count > 4) dismiss(list.get(0).key)
        return key
    }

    function dismiss(key) {
        delete runs[key]
        for (let i = 0; i < list.count; i++) if (list.get(i).key === key) { list.remove(i); return }
    }

    /** Presses a notice's button: runs what it does, and the notice goes. */
    function act(key) {
        const run = runs[key]
        dismiss(key)
        if (run) run()
    }

    /** A failure as a notice: titled for what didn't happen, the reason as its body. */
    function failed(world, title, why) {
        return show({ world: world, title: title, body: String(why), tone: "error" })
    }
}

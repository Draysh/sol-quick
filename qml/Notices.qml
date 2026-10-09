pragma Singleton
import QtQuick

/*
    In-app notices: short messages at the top edge. They fade in and leave
    after six seconds; the time stops while the pointer is on one. The
    window shows them; anything can post one.

        Notices.show({ world: "terra", title: "Not saved", body: why, tone: "error" })
*/
QtObject {
    id: notices

    /** How long a notice stays, unless held. */
    readonly property int linger: 6000
    /** Each row: key, world, title, body, tone. */
    property ListModel list: ListModel {}
    property int next: 1

    function show(notice) {
        const key = next++
        list.append({ key: key, world: notice.world || "sol", title: notice.title || "", body: notice.body || "", tone: notice.tone || "info" })
        while (list.count > 4) list.remove(0)
        return key
    }

    function dismiss(key) {
        for (let i = 0; i < list.count; i++) if (list.get(i).key === key) { list.remove(i); return }
    }

    /** A failure as a notice: titled for what didn't happen, the reason as its body. */
    function failed(world, title, why) {
        return show({ world: world, title: title, body: String(why), tone: "error" })
    }
}

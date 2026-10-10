import QtQuick
import Sol.Design

/*
    Where a world's pictures come from: one of its commands fetches a
    picture to disk (once) and answers with the file's path, "" for none.
    The store asks once per key however many Pictures show it, and knows
    the files it was given, so a picture already here shows with the first
    frame; with `keep`, it remembers them between runs too (written a
    little after the last new one). A file gone since (a cache kept under
    a size) is fetched again (`lost`; Picture does it by itself).

        // In the world's singleton:
        property PictureStore covers: PictureStore { command: "cover"; args: key => ({ id: key }) }
        // On a page:
        Picture { store: Neptune.covers; key: album.cover; ratio: 1 }
*/
QtObject {
    id: store

    /** The world's command that fetches a picture and answers with its path on disk. */
    property string command: ""
    /** What `command` is asked for a key: `{ path: key }` unless given. */
    property var args: key => ({ path: key })
    /** A name to remember the files under between runs (`SolBackend.remember`); "" remembers them for this run only. */
    property string keep: ""
    /** The most remembered between runs, the latest first. */
    property int kept: 1500

    /** The files here, by key: their `file://` addresses. */
    property var files: ({})
    /** Pictures on their way, by key: one request each. */
    property var coming: ({})

    Component.onCompleted: {
        if (keep === "") return
        try { files = JSON.parse(SolBackend.recall(keep) || "{}") } catch (e) { files = {} }
    }
    property Timer later: Timer {
        interval: 4000
        onTriggered: {
            const keys = Object.keys(store.files)
            const kept = {}
            for (const k of keys.slice(Math.max(0, keys.length - store.kept))) kept[k] = store.files[k]
            SolBackend.remember(store.keep, JSON.stringify(kept))
        }
    }
    function written() { if (keep !== "") later.restart() }

    /** A picture already on disk, at once: its `file://` address, or "". */
    function known(key) { return files[key] || "" }
    /** A picture's `file://` address, as a promise: fetched once, then read from disk; "" when there is none. */
    function get(key) {
        if (!key) return Promise.resolve("")
        if (files[key]) return Promise.resolve(files[key])
        if (!coming[key]) {
            coming[key] = Sol.call(command, args(key)).then(path => {
                delete store.coming[key]
                const url = path ? "file://" + path : ""
                if (url) { store.files[key] = url; store.written() }
                return url
            }).catch(() => { delete store.coming[key]; return "" })
        }
        return coming[key]
    }
    /** A picture's file turned out to be gone: asked for again next time. */
    function lost(key) { if (files[key]) { delete files[key]; written() } }
}

pragma Singleton
import QtQuick
import Sol.Design

/*
    The screens' side of the connection to Sol: where the app stands
    (`status`, `paired`, `online`, `unsent`), what changed (`changes`,
    `settingsVersion`), the app's own updates (`app`), and `call`, which
    runs a command on the Rust side and returns a promise.

        Sol.call("tick_habit", { id: habit.id, done: true }).then(h => …).catch(why => Notices.failed(world, "Not ticked", why))
*/
QtObject {
    id: sol

    readonly property string world: SolBackend.world
    /** Mirrors `orbit::link::Status`: `{ state: "unpaired" | "pairing" | "online" | "offline", … }`. */
    readonly property var status: SolBackend.status ? JSON.parse(SolBackend.status) : null
    readonly property bool paired: !!status && (status.state === "online" || status.state === "offline")
    readonly property bool online: !!status && status.state === "online"
    readonly property string server: status && status.server ? status.server : ""
    readonly property var user: status && status.user ? status.user : null
    readonly property int unsent: SolBackend.unsent
    /** Mirrors `orbit::updates::Status`. */
    readonly property var app: SolBackend.app ? JSON.parse(SolBackend.app) : null
    /** Bumped whenever documents change, here or on another device: bind to it to read again. */
    readonly property int changes: SolBackend.changes
    /** Bumped when the world's settings change in Sol. */
    readonly property int settingsVersion: SolBackend.settingsVersion
    readonly property var manifest: JSON.parse(SolBackend.manifest())
    readonly property bool background: SolBackend.background
    /** Working on screens: the Shell without pairing, on a throwaway local copy. */
    readonly property bool preview: SolBackend.preview

    property int nextId: 1
    property var pending: ({})

    // QML's JavaScript has promises but no `finally`; every screen uses it.
    Component.onCompleted: {
        if (!Promise.prototype.finally) {
            Promise.prototype.finally = function (f) {
                return this.then(v => Promise.resolve(f()).then(() => v), e => Promise.resolve(f()).then(() => { throw e }))
            }
        }
    }

    /** Runs a command on the Rust side. Resolves with what it returned, rejects with one sentence on why not. */
    function call(command, args) {
        const id = nextId++
        return new Promise((resolve, reject) => {
            pending[id] = { resolve: resolve, reject: reject }
            SolBackend.call(id, command, JSON.stringify(args || {}))
        })
    }

    /** A world's own event for its screens: `Connections { target: Sol; function onEvent(name, data) { … } }`. */
    signal event(string name, var data)

    property Connections link: Connections {
        target: SolBackend
        function onWorldEvent(name, data) { sol.event(name, data === "" ? null : JSON.parse(data)) }
        function onReplied(id, ok, body) {
            const p = sol.pending[id]
            if (!p) return
            delete sol.pending[id]
            if (ok) p.resolve(body === "" || body === "null" ? null : JSON.parse(body))
            else p.reject(body)
        }
        function onNotice(title, body, tone) {
            Notices.show({ world: "sol", title: title, body: body, tone: tone })
        }
    }

    /** Opens a web address in the system browser. */
    function openUrl(url) { SolBackend.openUrl(url) }

    /** This world's page in Sol, where its settings are changed. */
    function openInSol() {
        call("open_in_sol").catch(why => Notices.failed("sol", "Couldn’t open Sol", why))
    }

    /** Another world's app on this computer. */
    function openWorld(id, name) {
        call("open_world", { world: id }).catch(why => Notices.failed("sol", "Couldn’t open " + (name || id), why))
    }

    /** The worlds whose apps are installed on this computer. */
    function installed() {
        return call("doors").catch(() => [])
    }

    /**
        The doors in this app's sidebar: Sol first, then the moons or the
        planet this world works with, but only those installed here, so a
        door never opens on nothing.
    */
    function doors(me) {
        const w = Worlds.get(me)
        const solDoor = { world: "sol", label: "Sol", hint: w.name + "’s settings and connections, and every other world, in the browser", open: () => openInSol() }
        return installed().then(here => [solDoor].concat(
            Worlds.kin(me).filter(k => here.includes(k.id)).map(k => ({ world: k.id, label: k.name, hint: k.tagline, open: () => openWorld(k.id, k.name) }))))
    }

    /** The same doors for the Sheet, under the world's name. */
    function moons(me) {
        return installed().then(here =>
            Worlds.kin(me).filter(k => here.includes(k.id)).map(k => ({ id: k.id, label: k.name + " · " + k.tagline.toLowerCase(), open: () => openWorld(k.id, k.name) })))
    }

    /** `HH:MM` of an ISO time, in the local zone. */
    function clock(iso) {
        const d = new Date(iso)
        return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
    }
}

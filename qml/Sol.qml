pragma Singleton
import QtQuick
import Sol.Design

/*
    The screens' side of the connection to Sol: where the app stands
    (`status`, `paired`, `online`, `unsent`), what changed (`changedIn`,
    `settingsVersion`), the app's own updates (`app`), and `call`, which
    runs a command on the Rust side and returns a promise.

        Sol.call("tick_habit", { id: habit.id, done: true }).then(h => …).catch(why => Sol.fail("Not ticked", why))
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
    /**
        Writes kept aside instead of sent, by why (`orbit::link::Kept`):
        `{ conflicts, rejected, earlier }`. The window tells the person and
        `KeptAside` lets them choose; `Sol.call("kept")` lists them.
    */
    readonly property var kept: SolBackend.kept ? JSON.parse(SolBackend.kept) : ({ conflicts: 0, rejected: 0, earlier: 0 })
    /** How many writes are kept aside in all. */
    readonly property int keptCount: kept.conflicts + kept.rejected + kept.earlier
    /** Why this device's copy didn't open (`{ problem: "newer" | "damaged" | "other", path, detail }`), or null. */
    readonly property var problem: SolBackend.problem ? JSON.parse(SolBackend.problem) : null
    /** Bumped when the world's settings change in Sol. */
    readonly property int settingsVersion: SolBackend.settingsVersion
    readonly property var manifest: JSON.parse(SolBackend.manifest())
    readonly property bool background: SolBackend.background
    /** Working on screens: the Shell without pairing, on a throwaway local copy. */
    readonly property bool preview: SolBackend.preview
    /**
        The moons this app carries, by id: each `{ name, status, unsent,
        kept, problem, settingsVersion }` as the app's own world's are here.
        A moon's pages reach theirs through `Sol.of("luna")`.
    */
    readonly property var carried: SolBackend.moons ? JSON.parse(SolBackend.moons) : ({})

    property int nextId: 1
    property var pending: ({})
    /** How many commands haven't replied yet: a picture for review waits for them. */
    property int waiting: 0

    // QML's JavaScript has promises but no `finally`; every screen uses it.
    Component.onCompleted: {
        if (!Promise.prototype.finally) {
            Promise.prototype.finally = function (f) {
                return Promise.prototype.then.call(this, v => Promise.resolve(f()).then(() => v), e => Promise.resolve(f()).then(() => { throw e }))
            }
        }
    }

    /** Runs a command on the Rust side. Resolves with what it returned, rejects with one sentence on why not. */
    function call(command, args) { return callIn("", command, args) }

    /** Whether `w` is this app's own world ("" is too). */
    function own(w) { return !w || w === world }

    /** `call` for a world this app carries (`"luna"`); "" for its own. */
    function callIn(w, command, args) {
        const id = nextId++
        return new Promise((resolve, reject) => {
            pending[id] = { resolve: resolve, reject: reject }
            waiting++
            if (own(w)) SolBackend.call(id, command, JSON.stringify(args || {}))
            else SolBackend.callIn(w, id, command, JSON.stringify(args || {}))
        })
    }

    /**
        Calls `command` like `call`, and first, at once, hands `use` the reply
        it gave last time on this device (`use(reply, true)`), so a page shows
        what it showed while the fresh reply comes (`use(reply, false)`).
        Resolves with the fresh reply.
    */
    function callSeen(command, args, use) { return callSeenIn("", command, args, use) }

    /** `callSeen` for a world this app carries. */
    function callSeenIn(w, command, args, use) {
        const id = nextId++
        const key = command + " " + JSON.stringify(args || {})
        return new Promise((resolve, reject) => {
            // What was seen last is read and kept on the Rust side, off the window's thread;
            // `same` says the fresh reply is what was seen, so nothing need compare them here.
            pending[id] = { resolve: resolve, reject: reject, recalled: last => {
                try { use(JSON.parse(last), true, false) } catch (e) { }
            } }
            waiting++
            if (own(w)) SolBackend.callSeen(id, key, command, JSON.stringify(args || {}))
            else SolBackend.callSeenIn(w, id, key, command, JSON.stringify(args || {}))
        }).then(r => { use(r.reply, false, r.same); return r.reply })
    }

    // ---- Little helpers every world's screens share -----------------------------
    /** A failure as a notice from this world: titled for what didn't happen, the reason as its body. */
    function fail(title, why) { return Notices.failed(world, title, why) }
    /** `fail`, as a notice from a carried world. */
    function failIn(w, title, why) { return Notices.failed(own(w) ? world : w, title, why) }

    /**
        Runs the command `command` with `args` as a write that can be taken
        back from its notice for a few seconds: the world's Rust says which
        documents it changes (`Commands::undoable`), keeps them as they
        were, and the notice's Undo puts them back. `o` is the notice's
        `title` and `body`; `undone()` follows a taken-back write (to load
        the page again). A write with a way back of its own (a star in
        Navidrome, Saturn's `put_back`) passes `undo: (result, token) =>
        promise`, handed the token its documents were kept under (null when
        the command keeps none). Resolves with what the command returned.

            Sol.undoable("archive_habit", { id: id }, { title: "Archived", body: "“Walk” is off the list." })
    */
    function undoable(command, args, o) { return undoableIn("", command, args, o) }

    /** `undoable` for a world this app carries. */
    function undoableIn(w, command, args, o) {
        const from = own(w) ? world : w
        return callIn(w, "undoable", { command: command, args: args || {} }).then(r => {
            const back = o.undo ? () => o.undo(r.result, r.undo)
                : r.undo !== null ? () => callIn(w, "restore", { undo: r.undo }) : null
            if (back)
                Notices.show({ world: from, title: o.title, body: o.body || "", action: "Undo",
                    run: () => back().then(() => { Sounds.off(); if (o.undone) o.undone() }).catch(why => failIn(w, "Not taken back", why)) })
            else Notices.show({ world: from, title: o.title, body: o.body || "" })
            // A soft "done" (a world's voice that follows at once takes its place).
            Sounds.done()
            return r.result
        })
    }

    /** Whether two replies say the same (so what shows can stay as it is). */
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

    /**
        Sets `item[name]` to `value` only when it says something new, so a
        reload that changed nothing draws nothing again.
    */
    function update(item, name, value) {
        if (!same(item[name], value)) item[name] = value
    }

    /**
        Loads `command` into `item[name]`: on a cold start at once with what
        this device saw last, then with the fresh reply, which changes
        nothing on screen when it says the same. What was seen last is
        skipped when `item[name]` already holds something. `then(reply)`
        follows each reply taken. Resolves with the fresh reply.
    */
    function fill(item, name, command, args, then) { return fillIn("", item, name, command, args, then) }

    /** `fill` for a world this app carries. */
    function fillIn(w, item, name, command, args, then) {
        let shown = false
        return callSeenIn(w, command, args || {}, (reply, seen, same) => {
            if (seen && item[name]) return
            // The fresh reply is what was seen, and that is what shows: nothing to compare.
            if (same && shown) return
            if (seen) { item[name] = reply; shown = true }
            else update(item, name, reply)
            if (then) then(reply)
        })
    }

    /**
        Runs `command` and gives its reply to `use(reply, seen)`. On a page's
        `first` load, what this device showed last time comes at once
        (`seen` true), then the fresh reply, so the page is there on a cold
        start; later loads ask Sol only. Resolves with the fresh reply.
    */
    function fetch(first, command, args, use) { return fetchIn("", first, command, args, use) }

    /** `fetch` for a world this app carries. */
    function fetchIn(w, first, command, args, use) {
        return first ? callSeenIn(w, command, args, use) : callIn(w, command, args).then(r => { use(r, false); return r })
    }

    /**
        Brings a ListModel to `rows` (each with a `key`, or the role named
        `key`) in place: a row whose key stays where it was keeps its
        delegate, and what the delegate holds (a tick's animation, a field's
        focus), while its data changes. From the first row that differs on,
        the rest is made again.
    */
    function sync(model, rows, key) {
        const k = key || "key"
        let i = 0
        for (; i < rows.length && i < model.count && model.get(i)[k] === rows[i][k]; i++) model.set(i, rows[i])
        if (model.count > i) model.remove(i, model.count - i)
        for (; i < rows.length; i++) model.append(rows[i])
    }

    /**
        Brings `model` (a ListModel with `dynamicRoles`) in line with
        `rows`: each row under `role`, known by `keyOf(row)`. Rows that stay
        are moved where they belong and updated in place, so their cards
        aren't made again (no card arrives twice). A Grid doesn't hear a
        move: place it after.
    */
    function follow(model, rows, keyOf, role) {
        const keys = rows.map(keyOf)
        const wanted = Object.create(null)
        for (const k of keys) wanted[k] = true
        for (let i = model.count - 1; i >= 0; i--) if (!wanted[model.get(i).key]) model.remove(i)
        // The model's keys in its order, kept in step with its moves, so a row is found without asking the model.
        const here = [], has = Object.create(null)
        for (let i = 0; i < model.count; i++) { const k = model.get(i).key; here.push(k); has[k] = true }
        rows.forEach((r, i) => {
            const k = keys[i], json = JSON.stringify(r)
            const entry = { key: k, json: json }
            entry[role] = r
            const at = !has[k] ? -1 : here[i] === k ? i : here.indexOf(k, i)
            if (at < 0) { model.insert(i, entry); here.splice(i, 0, k); has[k] = true; return }
            if (at !== i) { model.move(at, i, 1); here.splice(at, 1); here.splice(i, 0, k) }
            if (model.get(i).json !== json) model.set(i, entry)
        })
    }

    /** A count on the app's icon and in the Sol tray (`"due"`, `"habits left"`); 0 clears it. */
    function badge(count, what) { SolBackend.setBadge(count || 0, what || "") }

    /**
        A main act's impact frame over `item` (the thing hit: the play
        button, the ON AIR sign): a smear, an inverted drawing and a burst of
        speed lines over its region only, the page shaken a few pixels, then
        the held pose (Impact, over the window's pane). Only in a flavour
        with an impact colour (`Theme.impacts`); never with less motion,
        never more than three a second. `opts.way` -1 strikes right to left.
    */
    function impact(item, opts) {
        if (!item || !Theme.impacts) return
        const w = item.Window.window as AppWindow
        const layer = w && w.shell ? (w.shell as Shell).impact as Impact : null
        if (layer) layer.hit(item, opts)
    }

    /**
        The world's navigator reacts to something the person just did:
        `Sol.cheer()` after the world's main good act (an episode watched, a
        habit ticked, a card remembered): a warm light over the portrait,
        and now and then (the first in a few minutes) the big cheer, a hop
        and a burst of sparks, so it stays an occasion. The light rests too:
        acts in a row (twenty cards remembered, five habits ticked) warm it
        once in `happyRest`, not every time. `react(kind)` names the
        reaction: "happy" (the light), "cheer" (the big one).
    */
    function cheer() {
        const now = Date.now()
        const big = now - cheeredAt > cheerRest
        if (big) { cheeredAt = now; happyAt = now; reacted("cheer"); return }
        if (now - happyAt < happyRest) return
        happyAt = now
        reacted("happy")
    }
    /** When the last big cheer was, and how long the navigator rests before the next. */
    property real cheeredAt: 0
    readonly property int cheerRest: 4 * 60 * 1000
    /** When the navigator's light last warmed, and how long it rests before it warms again. */
    property real happyAt: 0
    readonly property int happyRest: 20 * 1000
    function react(kind) { reacted(kind) }
    signal reacted(string kind)

    /** A world's own event for its screens: `Connections { target: Sol; function onEvent(name, data) { … } }`. */
    signal event(string name, var data)
    /** Documents changed in these collections (an empty list: in any); a page reads again with a `Watch`. */
    signal changedIn(var collections)
    /** A carried world's own event, and its documents changed (`Sol.of(w)` passes each on as its own). */
    signal eventIn(string world, string name, var data)
    signal changedInWorld(string world, var collections)

    /**
        The connection as a world's pages see it: `Sol.of("luna")` for a moon
        this app carries (the same members as `Sol`, for that world), the
        app's own for its own id or "".
    */
    function of(w) {
        const id = own(w) ? world : w
        if (!worlds[id]) worlds[id] = worldOf.createObject(sol, { world: id })
        return worlds[id]
    }
    /** The world of the page `item` is on (`Screen.world`), as `of` gives it. */
    function near(item) {
        const screen = Theme.screenOf(item)
        return of(screen && screen.world ? screen.world : "")
    }
    property var worlds: ({})
    property Component worldOf: Component { SolWorld { } }

    property Connections link: Connections {
        target: SolBackend
        function onWorldEvent(name, data) { sol.event(name, data === "" ? null : JSON.parse(data)) }
        function onReplied(id, ok, body) {
            const p = sol.pending[id]
            if (!p) return
            delete sol.pending[id]
            sol.waiting--
            const reply = ok ? (body === "" || body === "null" ? null : JSON.parse(body)) : null
            if (!ok) p.reject(body)
            else if (p.recalled) p.resolve({ reply: reply, same: !!p.same })
            else p.resolve(reply)
        }
        function onRecalled(id, body) { const p = sol.pending[id]; if (p && p.recalled) p.recalled(body) }
        function onRepeated(id) { const p = sol.pending[id]; if (p) p.same = true }
        function onChanged(collections) { sol.changedIn(JSON.parse(collections)) }
        function onEventIn(w, name, data) { sol.eventIn(w, name, data === "" ? null : JSON.parse(data)) }
        function onChangedIn(w, collections) { sol.changedInWorld(w, JSON.parse(collections)) }
        function onNotice(title, body, tone) {
            Notices.show({ world: "sol", title: title, body: body, tone: tone })
        }
    }

    /**
        A file on this computer as an address for an Image, a sound or a
        script, each part of the path encoded (so a `#`, `%` or space in a
        name still reaches the file); "" for none.

            Image { source: Sol.fileUrl(path) }
    */
    function fileUrl(path) { return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : "" }

    /** Opens a web address in the system browser. */
    function openUrl(url) { SolBackend.openUrl(url) }

    /** This world's page in Sol, where its settings are changed. */
    function openInSol() {
        call("open_in_sol").catch(why => Notices.failed("sol", "Couldn’t open Sol", why))
    }

    /** Another world's app on this computer; at a page of it with `path` (`/title?key=x`). */
    function openWorld(id, name, path) {
        call("open_world", path ? { world: id, path: path } : { world: id }).catch(why => Notices.failed("sol", "Couldn’t open " + (name || id), why))
    }

    /** The worlds whose apps are installed on this computer. */
    function installed() {
        return call("doors").catch(() => [])
    }

    /** Where `id`'s pages are in this app: "/" for its own world, `/<moon>` for a moon it carries; "" when they're in another app. */
    function pathOf(id) { return id === world ? "/" : carried[id] ? "/" + id : "" }
    /** Opens a page of this app's window (the window follows it). */
    signal go(string path)
    /** Opens `id`'s pages: here when this app carries them, else its own app. */
    function openKin(k) { const p = pathOf(k.id); if (p) go(p); else openWorld(k.id, k.name) }

    /**
        The doors in this app's sidebar: Sol first, then the moons or the
        planet this world works with, but only those installed here, so a
        door never opens on nothing.
    */
    function doors(me) {
        const w = Worlds.get(me)
        const solDoor = { world: "sol", label: "Sol", role: "Settings and every world", hint: w.name + "’s settings and connections, and every other world, in the browser", open: () => openInSol() }
        // A moon this app carries has its pages here already: no door.
        return installed().then(here => [solDoor].concat(
            Worlds.kin(me).filter(k => here.includes(k.id) && !pathOf(k.id)).map(k => ({ world: k.id, label: k.name, role: k.role, hint: k.tagline, open: () => openWorld(k.id, k.name) }))))
    }

    /** The same doors for the Sheet, under the world's name. */
    function moons(me) {
        return installed().then(here =>
            Worlds.kin(me).filter(k => here.includes(k.id) || pathOf(k.id)).map(k => ({ id: k.id, label: k.name + " · " + (k.role || k.tagline), hint: k.tagline, open: () => openKin(k) })))
    }

    /** `HH:MM` of an ISO time, in the local zone. */
    function clock(iso) {
        const d = new Date(iso)
        return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
    }
}

import QtQuick
import Sol.Design

/*
    The connection as one world's pages see it, with the same members as
    `Sol`: for the app's own world those are `Sol`'s, for a moon the app
    carries the moon's own (its link, its status, its commands). Made by
    `Sol.of(world)`, never by hand; a moon's singleton keeps one
    (`readonly property var sol: Sol.of("luna")`) and its pages call
    through it.

        Luna.sol.call("tonight").then(t => page.tonight = t)
*/
QtObject {
    id: w

    property string world: ""
    readonly property bool own: Sol.own(w.world)
    readonly property var info: own ? null : (Sol.carried[w.world] || null)

    readonly property var status: own ? Sol.status : info ? info.status || null : null
    readonly property bool paired: !!status && (status.state === "online" || status.state === "offline")
    readonly property bool online: !!status && status.state === "online"
    readonly property string server: status && status.server ? status.server : ""
    readonly property var user: status && status.user ? status.user : null
    readonly property int unsent: own ? Sol.unsent : info ? info.unsent || 0 : 0
    readonly property var kept: own ? Sol.kept : info && info.kept ? info.kept : ({ conflicts: 0, rejected: 0, earlier: 0 })
    readonly property int keptCount: kept.conflicts + kept.rejected + kept.earlier
    readonly property var problem: own ? Sol.problem : info ? info.problem || null : null
    readonly property int settingsVersion: own ? Sol.settingsVersion : info ? info.settingsVersion || 0 : 0
    readonly property var manifest: own ? Sol.manifest : JSON.parse(SolBackend.manifestOf(w.world) || "{}")
    readonly property bool preview: Sol.preview

    function call(command, args) { return Sol.callIn(w.world, command, args) }
    function callSeen(command, args, use) { return Sol.callSeenIn(w.world, command, args, use) }
    function fill(item, name, command, args, then) { return Sol.fillIn(w.world, item, name, command, args, then) }
    function fetch(first, command, args, use) { return Sol.fetchIn(w.world, first, command, args, use) }
    function undoable(command, args, o) { return Sol.undoableIn(w.world, command, args, o) }
    function fail(title, why) { return Sol.failIn(w.world, title, why) }
    function update(item, name, value) { Sol.update(item, name, value) }
    function sync(model, rows, key) { Sol.sync(model, rows, key) }
    function follow(model, rows, keyOf, role) { Sol.follow(model, rows, keyOf, role) }
    function openInSol() { call("open_in_sol").catch(why => Notices.failed("sol", "Couldn’t open Sol", why)) }

    /** This world's own event (`sol_quick::emit_in`). */
    signal event(string name, var data)
    /** Documents changed in this world's collections. */
    signal changedIn(var collections)

    property Connections link: Connections {
        target: Sol
        function onEvent(name, data) { if (w.own) w.event(name, data) }
        function onChangedIn(collections) { if (w.own) w.changedIn(collections) }
        function onEventIn(world, name, data) { if (!w.own && world === w.world) w.event(name, data) }
        function onChangedInWorld(world, collections) { if (!w.own && world === w.world) w.changedIn(collections) }
    }
}

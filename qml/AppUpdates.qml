import QtQuick

/*
    A world app's own version: installing it, and keeping it up to date
    through Sol. Reads `Sol.app`; the buttons run the shared commands.

        AppUpdates { name: "Terra" }
*/
Card {
    id: root

    property string name: Sol.manifest.name
    readonly property var status: Sol.app
    readonly property string downloads: Sol.server ? Sol.server + "/worlds/" + Sol.world : ""

    title: "Updates"

    readonly property var how: ({ dev: "a development build", loose: "not installed", portable: "by itself, for you", unsupported: "by hand" })
    readonly property string installed: status ? (status.here.state === "installed" ? how[status.here.kind] : how[status.here.state]) : ""
    readonly property bool updates: !!status && (status.here.state === "loose" || status.here.state === "installed")
    readonly property bool quiet: !!status && (status.here.state === "loose" || (status.here.state === "installed" && status.here.kind === "portable"))

    function mb(n) { return (n / 1000000).toFixed(1) + " MB" }
    function act(command, args) {
        Sol.call(command, args).catch(why => Notices.failed(Sol.world, "Updates", why))
    }

    Words { visible: !!root.status && root.status.here.state === "loose"; width: parent.width; small: true; quiet: true
        text: root.name + " runs from where you unpacked it. Install it to find it in your app menu and have it keep itself up to date." }
    Button { visible: !!root.status && root.status.here.state === "loose"; variant: "primary"; text: "Install " + root.name; onClicked: root.act("install_app") }

    DataRows { width: parent.width; rows: root.status ? [{ label: "Version", value: root.status.current }, { label: "Installed", value: root.installed }] : [] }

    Words { visible: !!root.status && !!root.status.rolled_back; width: parent.width; small: true; color: Theme.dangerText
        text: root.status && root.status.rolled_back ? "Version " + root.status.rolled_back.version + " didn’t start on this computer, so " + root.name + " went back to " + root.status.rolled_back.back_to + ". It won’t install that version by itself again." : "" }
    Words { visible: !!root.status && root.status.state === "checking"; small: true; quiet: true; text: "Asking Sol…" }
    Words { visible: !!root.status && root.status.state === "current"; width: parent.width; small: true; quiet: true
        text: root.status && root.status.state === "current" ? (root.status.message || "Up to date.") + "  Checked " + Sol.clock(root.status.checked_at) + "." : "" }
    Words { visible: !!root.status && root.status.state === "available"; text: root.status && root.status.offer ? "Version " + root.status.offer.version + " is out." : "" }
    Words { visible: !!root.status && root.status.state === "available" && !!root.status.offer.notes; width: parent.width; small: true; text: root.status && root.status.offer ? (root.status.offer.notes || "") : "" }
    Button { visible: !!root.status && root.status.state === "available" && root.status.installs_itself; variant: "primary"
        text: root.status && root.status.offer ? "Update to " + root.status.offer.version : ""; onClicked: root.act("install_update") }
    Words { visible: !!root.status && root.status.state === "available" && !root.status.installs_itself; width: parent.width; small: true; quiet: true
        text: "This copy came from a package, so the new one is installed the same way" + (root.downloads ? ": <a href='" + root.downloads + "'>get it from Sol</a>." : ".")
        textFormat: Text.RichText; linkColor: Theme.textValue; onLinkActivated: link => Sol.openUrl(link) }
    Progress { visible: !!root.status && root.status.state === "downloading"; width: parent.width
        value: root.status && root.status.state === "downloading" ? root.status.done : 0
        max: root.status && root.status.state === "downloading" ? root.status.total : 1
        start: root.status && root.status.state === "downloading" ? "Downloading " + root.status.version : ""
        end: root.status && root.status.state === "downloading" ? root.mb(root.status.done) + " of " + root.mb(root.status.total) : "" }
    Words { visible: !!root.status && root.status.state === "ready"; width: parent.width; text: root.status && root.status.state === "ready" ? "Version " + root.status.version + " is installed. It runs from the next start." : "" }
    Button { visible: !!root.status && root.status.state === "ready"; variant: "primary"; text: "Restart now"; onClicked: root.act("restart") }
    Words { visible: !!root.status && root.status.state === "failed"; width: parent.width; small: true; color: Theme.dangerText; text: root.status && root.status.state === "failed" ? root.status.error : "" }

    Toggle { id: autoToggle; visible: root.updates && root.quiet; width: parent.width; label: "Install updates by myself"
        hint: "New versions are put in place quietly and run from the next start."
        checked: !!root.status && root.status.auto; onToggled: on => Sol.call("set_auto_update", { auto: on }).catch(why => { autoToggle.fail(); Notices.failed(Sol.world, "Updates", why) }) }
    Button { visible: root.updates && !!root.status && root.status.state !== "downloading" && root.status.state !== "ready"; variant: "quiet"; icon: "refresh"; text: "Check now"
        busy: !!root.status && root.status.state === "checking"; onClicked: root.act("check_updates") }
}

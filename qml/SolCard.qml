import QtQuick

/*
    The Settings card every world has: the connection to Sol, as set, and
    the way out of it. Unpairing asks once, in place.
*/
Card {
    id: root

    property bool confirm: false
    readonly property var status: Sol.status

    title: "Sol"

    DataRows {
        width: parent.width
        rows: [].concat(
            [{ label: "Address", value: Sol.server, keepCase: true },
             { label: "Signed in as", value: Sol.user ? Sol.user.username : "" },
             { label: "Status", value: Sol.online ? "in sync" : "offline" }],
            root.status && root.status.state === "offline" && root.status.error ? [{ label: "Why", value: root.status.error }] : [],
            [{ label: "Waiting to send", value: String(Sol.unsent) }],
            Sol.keptCount > 0 ? [{ label: "Kept aside", value: [
                Sol.kept.conflicts ? Sol.kept.conflicts + " changed on two devices" : "",
                Sol.kept.rejected ? Sol.kept.rejected + " Sol couldn’t take" : "",
                Sol.kept.earlier ? Sol.kept.earlier + " from before" : ""].filter(Boolean).join(", ") }] : [])
    }
    Flow {
        visible: !root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { text: "Open in Sol"; onClicked: Sol.openInSol() }
        Button { visible: Sol.keptCount > 0; text: "See what’s kept"; onClicked: (root.Window.window as AppWindow).keptAside.open() }
        Button { variant: "quiet"; text: "Unpair…"; onClicked: root.confirm = true }
    }
    Words {
        visible: root.confirm
        width: parent.width; small: true; quiet: true
        text: "This device forgets its token and its local copy. Everything stays in Sol" + (Sol.unsent ? "; " + Sol.unsent + " change" + (Sol.unsent === 1 ? "" : "s") + " not sent yet stay" + (Sol.unsent === 1 ? "s" : "") + " on this device, and go" + (Sol.unsent === 1 ? "es" : "") + " to Sol when it is paired again as you" : "") + "."
    }
    Flow {
        visible: root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { text: "Unpair this device"; onClicked: Sol.call("forget").catch(why => Notices.failed(Sol.world, "Not unpaired", why)) }
        Button { variant: "quiet"; text: "Keep it"; onClicked: root.confirm = false }
    }
}

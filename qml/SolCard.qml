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
            [{ label: "Waiting to send", value: String(Sol.unsent) }])
    }
    Flow {
        visible: !root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { text: "Open in Sol"; onClicked: Sol.openInSol() }
        Button { variant: "quiet"; text: "Unpair…"; onClicked: root.confirm = true }
    }
    Words {
        visible: root.confirm
        width: parent.width; small: true; quiet: true
        text: "This device forgets its token and its local copy. Everything stays in Sol" + (Sol.unsent ? ", except " + Sol.unsent + " change" + (Sol.unsent === 1 ? "" : "s") + " not sent yet" : "") + "."
    }
    Flow {
        visible: root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { text: "Unpair this device"; onClicked: Sol.call("forget").catch(why => Notices.failed(Sol.world, "Not unpaired", why)) }
        Button { variant: "quiet"; text: "Keep it"; onClicked: root.confirm = false }
    }
}

import QtQuick

/*
    The Settings card every world has: the connection to Sol, as set, and
    the way out of it. Unpairing asks once, in place.
*/
Card {
    id: root
    /** Its world's connection: `world` (Card's) names a moon the app carries, "" the app's own. */
    readonly property var sol: Sol.of(root.world)

    property bool confirm: false
    readonly property var status: root.sol.status

    title: "Sol"
    jp: "ソル"

    DataRows {
        ledger: true
        width: parent.width
        rows: [].concat(
            [{ label: "Address", value: root.sol.server, keepCase: true },
             { label: "Signed in as", value: root.sol.user ? root.sol.user.username : "" },
             { label: "Status", value: root.sol.online ? "in sync" : "offline" }],
            root.status && root.status.state === "offline" && root.status.error ? [{ label: "Why", value: root.status.error }] : [],
            [{ label: "Waiting to send", value: String(root.sol.unsent) }],
            root.sol.keptCount > 0 ? [{ label: "Kept aside", value: [
                root.sol.kept.conflicts ? root.sol.kept.conflicts + " changed on two devices" : "",
                root.sol.kept.rejected ? root.sol.kept.rejected + " Sol couldn’t take" : "",
                root.sol.kept.earlier ? root.sol.kept.earlier + " from before" : ""].filter(Boolean).join(", ") }] : [])
    }
    Flow {
        visible: !root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { icon: "external"; text: "Open in Sol"; onClicked: root.sol.openInSol() }
        // A moon in its planet's app is paired with the planet, and its kept writes are listed there.
        Button { visible: root.sol.own && root.sol.keptCount > 0; text: "See what’s kept"; onClicked: (root.Window.window as AppWindow).keptAside.open() }
        Button { visible: root.sol.own; variant: "quiet"; text: "Unpair…"; onClicked: root.confirm = true }
    }
    Words {
        visible: root.confirm
        width: parent.width; small: true; quiet: true
        text: "This device forgets its token and its local copy. Everything stays in Sol" + (root.sol.unsent ? "; " + root.sol.unsent + " change" + (root.sol.unsent === 1 ? "" : "s") + " not sent yet stay" + (root.sol.unsent === 1 ? "s" : "") + " on this device, and go" + (root.sol.unsent === 1 ? "es" : "") + " to Sol when it is paired again as you" : "") + "."
    }
    Flow {
        visible: root.confirm
        width: parent.width
        spacing: Theme.s2
        Button { variant: "danger"; text: "Unpair this device"; onClicked: root.sol.call("forget").catch(why => Notices.failed(root.sol.world, "Not unpaired", why)) }
        Button { variant: "quiet"; text: "Keep it"; onClicked: root.confirm = false }
    }
}

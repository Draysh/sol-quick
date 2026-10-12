import QtQuick

/*
    The world's settings as set in Sol, read-only here: every device picks
    them up at once. Shown only when the manifest declares any.
*/
Card {
    id: root
    /** Its world's connection: `world` (Card's) names a moon the app carries, "" the app's own. */
    readonly property var sol: Sol.of(root.world)

    property var values: ({})
    readonly property var manifest: root.sol.manifest

    title: manifest.name + "’s settings"
    visible: !!manifest.settings && manifest.settings.length > 0

    Component.onCompleted: load()
    Connections { target: Sol; function onSettingsVersionChanged() { root.load() } }
    function load() { root.sol.call("settings").then(v => root.values = v || {}).catch(() => {}) }

    function show(kind, value) {
        if (value === undefined || value === null || value === "") return "not set"
        if (kind === "secret") return "set"
        if (kind === "toggle") return value ? "on" : "off"
        return String(value)
    }

    DataRows { width: parent.width; rows: (root.manifest.settings || []).map(s => ({ label: s.label, value: root.show(s.kind, root.values[s.key]) })) }
    Words { width: parent.width; small: true; quiet: true; text: "Change these in Sol; every device picks them up at once." }
    Button { variant: "quiet"; text: "Change in Sol"; onClicked: root.sol.openInSol() }
}

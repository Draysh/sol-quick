import QtQuick

/*
    A moon's place beside its planet: it starts by itself, without a
    window, whenever its planet opens, and leaves a little after the planet
    closes. Per computer, on until turned off. Reads and sets it through
    the shared commands, for the app it is in.

        WithPlanet { work: "Picks keep up with what you rate and finish." }
*/
Card {
    id: root

    /** What the moon keeps doing out of sight, in one sentence. */
    property string work: ""
    /** `null` while unknown or when this copy can't (not installed). */
    property var on: undefined

    readonly property var moon: Worlds.get(Sol.world)
    readonly property var planet: Worlds.get(moon.parent || "sol")

    title: "With " + planet.name
    Component.onCompleted: Sol.call("with_planet").then(v => root.on = v).catch(() => root.on = null)

    Words { visible: root.on === null; width: parent.width; small: true; quiet: true
        text: "Once " + root.moon.name + " is installed, it starts by itself whenever " + root.planet.name + " opens: no window, nothing to remember. This copy is a development build or isn’t installed." }
    Toggle {
        id: toggle
        visible: root.on === true || root.on === false
        width: parent.width
        label: "Run whenever " + root.planet.name + " runs"
        checked: root.on === true
        hint: root.on ? root.moon.name + " starts without a window when " + root.planet.name + " opens and stops a little after it closes." + (root.work ? " " + root.work : "")
                      : root.moon.name + " only works while you have it open."
        onToggled: v => Sol.call("set_with_planet", { on: v }).then(r => { root.on = r; if (r !== v) toggle.fail() })
                                                            .catch(why => { toggle.fail(); Notices.failed(Sol.world, "Not changed", why) })
    }
}

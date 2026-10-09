import QtQuick
import QtCore
import Sol.Design

/*
    What is this device's alone: the world's accent (its own colour, or
    one from its photograph), and whether the small sounds play. Every
    other setting lives in Sol.
*/
Card {
    id: root

    title: "On this device"

    readonly property var w: Worlds.get(Sol.world)
    Settings { id: prefs; category: "sol." + Sol.world; property string accent: "" }
    /** The world's own colour, then what its photograph offers. */
    readonly property var choices: [w.color].concat(Theme.picks)

    Label { text: "Accent" }
    Row {
        spacing: Theme.s2
        Repeater {
            model: root.choices
            delegate: Item {
                id: swatch
                required property var modelData
                required property int index
                readonly property bool on: Qt.colorEqual(Theme.world, modelData)
                width: 28; height: 28
                Rectangle { anchors.centerIn: parent; width: swatch.on ? 18 : 14; height: width; radius: width / 2; color: swatch.modelData; Behavior on width { SpringAnimation { spring: 4; damping: 0.3 } } }
                Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "transparent"; border.width: 1; border.color: swatch.on ? Theme.textBright : swatchMouse.containsMouse ? Theme.lineStrong : "transparent"; Behavior on border.color { ColorAnimation { duration: Theme.fade } } }
                MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { prefs.accent = swatch.index === 0 ? "" : String(swatch.modelData); Theme.world = swatch.modelData; Sounds.tick() } }
                Hint { text: swatch.index === 0 ? root.w.name + "’s own" : "From the photograph"; when: swatchMouse.containsMouse }
            }
        }
    }
    Words { width: parent.width; small: true; quiet: true; text: "The glow on buttons, the light in the sidebar, the limb of the world." }
    Toggle { label: "Sounds"; checked: Sounds.on; hint: "A tick, a thing done, a thing taken back: a few milliseconds each."; onToggled: c => Sounds.setOn(c) }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import Sol.Design

/*
    What is this device's alone: night or day (for every Sol app here),
    the world's accent (its own colour, or one from its photograph), and
    whether the small sounds play. Every other setting lives in Sol.
*/
Card {
    id: root

    title: "On this device"

    readonly property var w: Worlds.get(Sol.world)
    Settings { id: prefs; category: "sol." + Sol.world; property string accent: "" }
    /** The world's own colour, then what its photograph offers. */
    readonly property var choices: [w.color].concat(Theme.picks)

    Select {
        width: parent.width
        label: "Light"
        value: Theme.mode
        options: [
            { value: "system", label: "As the desktop is" },
            { value: "sun", label: "With the sun: day from 7 to 19" },
            { value: "night", label: "Always night" },
            { value: "day", label: "Always day" }
        ]
        hint: "For every Sol app on this computer."
        onChosen: v => Theme.setMode(v)
    }
    // The app's widget on the desktop, when it has one.
    readonly property AppWindow app: root.Window.window as AppWindow
    readonly property bool hasWidget: !!app && !!app.widget && app.widgetsHere
    Toggle {
        visible: root.hasWidget
        width: parent.width
        label: root.app ? "On the desktop: " + root.app.widgetName.toLowerCase() : ""
        checked: !!root.app && root.app.widgetPrefs.widget
        hint: "A small panel over the wallpaper while " + root.w.name + " runs, in the tray too. A click opens " + root.w.name + "."
        onToggled: on => root.app.widgetPrefs.widget = on
    }
    Select {
        visible: root.hasWidget && root.app.widgetPrefs.widget
        width: parent.width
        label: "Where"
        value: root.app ? root.app.widgetPrefs.corner : "top-right"
        options: [
            { value: "top-right", label: "Top right" },
            { value: "top-left", label: "Top left" },
            { value: "bottom-right", label: "Bottom right" },
            { value: "bottom-left", label: "Bottom left" }
        ]
        onChosen: v => root.app.widgetPrefs.corner = v
    }
    Toggle {
        id: autostart
        visible: root.starts !== null
        width: parent.width
        label: "Start with the computer"
        checked: root.starts === true
        hint: "In the tray, without a window: its widget and reminders are there from the start."
        onToggled: on => Sol.call("set_autostart", { on: on }).then(v => { root.starts = v; if (v !== on) autostart.fail() }).catch(why => { autostart.fail(); Notices.failed(Sol.world, "Not changed", why) })
    }
    /** Whether the app starts with the computer; null when this copy can't (not installed). */
    property var starts: null
    Component.onCompleted: Sol.call("autostart").then(v => root.starts = v).catch(() => root.starts = null)

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
                function choose() { prefs.accent = swatch.index === 0 ? "" : String(swatch.modelData); Theme.world = swatch.modelData; Sounds.tick() }
                width: 28; height: 28
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: swatch.index === 0 ? root.w.name + "’s own colour" : "A colour from the photograph"
                Accessible.checked: swatch.on
                Accessible.onPressAction: swatch.choose()
                Keys.onPressed: event => { if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; swatch.choose() } }
                // A hairline round it, so a pale colour still shows on a pale card.
                Rectangle { anchors.centerIn: parent; width: swatch.on ? 18 : 14; height: width; radius: width / 2; color: swatch.modelData; border.width: 1; border.color: Theme.line; Behavior on width { SpringAnimation { spring: 4; damping: 0.3 } } }
                Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "transparent"; border.width: 1; border.color: swatch.on ? Theme.textBright : swatchMouse.containsMouse || swatch.activeFocus ? Theme.lineStrong : "transparent"; Behavior on border.color { ColorAnimation { duration: Theme.fade } } }
                Ticks { on: swatch.activeFocus; out: 3 }
                MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: swatch.choose() }
                Hint { text: swatch.index === 0 ? root.w.name + "’s own" : "From the photograph"; when: swatchMouse.containsMouse }
            }
        }
    }
    Words { width: parent.width; small: true; quiet: true; text: "The glow on buttons, the light in the sidebar, the limb of the world." }
    Toggle { label: "Sounds"; checked: Sounds.on; hint: "A tick, a thing done, a thing taken back: a few milliseconds each."; onToggled: c => Sounds.setOn(c) }
}

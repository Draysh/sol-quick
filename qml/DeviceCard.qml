pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    What is this device's alone: the desktop widget, starting with the
    computer, less motion (every Sol app here too), and whether the small
    sounds play. Every other setting lives in Sol. The world's light is its
    flavour's own, matched to its stills, so there is no accent to choose.
*/
Card {
    id: root

    title: "On this device"
    jp: "端末"

    readonly property var w: Worlds.get(Sol.world)

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
        onToggled: on => Sol.call("set_autostart", { on: on }).then(v => { root.starts = v; if (v !== on) autostart.fail() }).catch(why => { autostart.fail(); Sol.fail("Not changed", why) })
    }
    /** Whether the app starts with the computer; null when this copy can't (not installed). */
    property var starts: null
    Component.onCompleted: Sol.call("autostart").then(v => root.starts = v).catch(() => root.starts = null)

    Toggle { label: "Less motion"; checked: Theme.calm; hint: "Moments are short and still. For every Sol app on this computer."; onToggled: c => Theme.setCalm(c) }
    Toggle { label: "Sounds"; checked: Sounds.on; hint: "Quiet: a tick for a press, a soft note when something is done or taken back, a chime for a moment" + (Sounds.voiceName ? ", and " + Sounds.voiceName + " when something goes well." : "."); onToggled: c => Sounds.setOn(c) }
}

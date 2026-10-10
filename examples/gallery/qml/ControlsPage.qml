pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The controls, each in every state it has: Button in its variants
    (resting, busy, off, with the keys), Chip, Check, Toggle, Slider,
    Field, TextArea (and its large way), Select shut and open, Editable,
    Back, MoonLink, a page's own Key, and the focus Ticks on their own.
    `focusOn` says which control has the keys as the page shows: `button`,
    `field`, `textarea`, `slider`, or `select` (its list open); none when "".
*/
Screen {
    id: page

    title: "Controls"
    property string focusOn: ""

    function giveKeys() {
        if (!page.visible || focusOn === "") return
        if (focusOn === "field") focusField.input.forceActiveFocus(Qt.TabFocusReason)
        else if (focusOn === "textarea") largeArea.focusIn()
        else if (focusOn === "slider") focusSlider.forceActiveFocus(Qt.TabFocusReason)
        // Opened without the keys: a list that has them closes when the window loses them.
        else if (focusOn === "select") openSelect.show()
        else if (focusOn === "button") focusButton.forceActiveFocus(Qt.TabFocusReason)
    }
    // Once the page has settled in (and the window has come up), so nothing takes the keys back;
    // again whenever the window comes to the front, since the keys show only while it is there.
    Timer { id: keysLater; interval: 700; onTriggered: page.giveKeys() }
    Connections { target: page.Window.window; function onActiveChanged() { if (page.Window.window.active) keysLater.restart() } }
    onVisibleChanged: if (visible) keysLater.restart()
    Component.onCompleted: { keysLater.restart(); failing.flip() }

    property int pressed: 0
    Key { on: page; sequence: "K"; onActivated: page.pressed++ }

    header: PageHead {
        title: "Controls"
        lead: "Every control, in every state"
        Button { variant: "quiet"; text: "The keys"; hint: "Every key the app knows, as ? shows them"; onClicked: page.shell.keys = true }
    }

    Grid {
        width: parent.width
        min: 380

        Card {
            title: "Button"
            Repeater {
                model: [
                    { variant: "primary", text: "Log it" },
                    { variant: "ghost", text: "Export" },
                    { variant: "quiet", text: "Remove" }
                ]
                delegate: Flow {
                    id: buttons
                    required property var modelData
                    width: parent.width
                    spacing: Theme.s2
                    Button { variant: buttons.modelData.variant; text: buttons.modelData.text; hint: "A " + buttons.modelData.variant + " button" }
                    Button { variant: buttons.modelData.variant; text: "Busy"; busy: true }
                    Button { variant: buttons.modelData.variant; text: "Off"; enabled: false }
                }
            }
            Flow {
                width: parent.width
                spacing: Theme.s2
                Button { variant: "round"; icon: "plus"; hint: "Round, an icon alone" }
                Button { variant: "round"; icon: "play"; busy: true }
                Button { variant: "round"; icon: "close"; enabled: false }
                Button { icon: "arrow-up-right"; text: "Open in Sol" }
                Button { id: focusButton; text: "With the keys"; hint: "Tab moves the keys; the ticks follow" }
            }
        }
        Card {
            title: "Field"
            Field { width: parent.width; label: "Empty"; placeholder: "What happened?" }
            Field { width: parent.width; label: "Typed"; text: "A walk by the river"; hint: "A line under it, when it helps" }
            Field { id: focusField; width: parent.width; label: "With the keys"; text: "Rain, then sun" }
            Field { width: parent.width; label: "Remind at"; time: true; text: "25:70"; error: "Write a time as HH:MM, e.g. 07:30." }
        }
        Card {
            id: selectCard
            title: "Select"
            readonly property var sorts: [{ value: "added", label: "Added" }, { value: "name", label: "Name" }, { value: "rating", label: "Rating" }, { value: "year", label: "Year" }]
            Select { id: shutSelect; width: parent.width; label: "Sort"; options: selectCard.sorts; value: "added"; onChosen: v => value = v }
            Select { id: openSelect; width: parent.width; label: "Then by"; hint: "Space, Enter or Down opens the list"; options: selectCard.sorts; value: "year"; onChosen: v => value = v }
        }
        Card {
            title: "TextArea"
            TextArea { width: parent.width; label: "Your notes"; hint: "Kept as you leave the field"; text: "Slow first episode, then it finds its feet." }
            TextArea { id: largeArea; width: parent.width; large: true; name: "Today"; minLines: 3; placeholder: "Write as much or as little as you like."; text: "A slow morning, then a long walk by the river." }
            TextArea { width: parent.width; large: true; single: true; minLines: 1; name: "Good moment"; placeholder: "One thought; Enter goes on."; onAccepted: Notices.show({ world: page.Window.window.world, title: "Enter", body: "A single answer goes on." }) }
        }
        Card {
            title: "Chip"
            Flow {
                width: parent.width
                spacing: Theme.s2
                Chip { id: chipA; text: "Good"; on: true; onClicked: on = !on }
                Chip { text: "Low"; onClicked: on = !on }
                Chip { text: "Off"; enabled: false }
                Chip { tag: true; text: "walk"; on: true; onClicked: on = !on }
                Chip { tag: true; text: "work"; onClicked: on = !on }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Plain chips, then tags; click one to turn it over." }
        }
        Card {
            title: "Check"
            Column {
                width: parent.width
                Check { width: parent.width; label: "Walk"; meta: "12 d"; checked: true; onToggled: c => checked = c }
                Check { width: parent.width; label: "Read"; meta: "due 21:30"; onToggled: c => checked = c }
                Check { width: parent.width; label: "Saving"; meta: "busy"; busy: true }
                Check {
                    id: failing
                    width: parent.width
                    label: "Fails: the write didn’t take"
                    meta: "click it"
                    last: true
                    onToggled: failLater.restart()
                    Timer { id: failLater; interval: 500; onTriggered: failing.fail() }
                }
            }
        }
        Card {
            title: "Toggle"
            Toggle { width: parent.width; label: "Sounds"; checked: true; onToggled: on => checked = on }
            Toggle { width: parent.width; label: "Start with the computer"; hint: "In the tray, without a window"; onToggled: on => checked = on }
            Toggle { width: parent.width; label: "Off"; enabled: false }
        }
        Card {
            title: "Slider"
            Slider { width: parent.width; value: 0.35; onMoved: v => value = v }
            Slider { id: focusSlider; width: parent.width; from: 0; to: 240; value: 180; live: true; onMoved: v => value = v }
            DataRows { width: parent.width; rows: [{ label: "Second", value: Format.timer(focusSlider.value) + " of 4:00" }] }
        }
        Card {
            title: "Editable"
            Editable { text: "Click to rename me"; onCommitted: t => text = t }
            Editable { text: "In capitals"; caps: true; size: Theme.textL; onCommitted: t => text = t }
        }
        Card {
            title: "Back, MoonLink and keys"
            Flow {
                width: parent.width
                spacing: Theme.s3
                Back { label: "Diary"; onGo: Notices.show({ world: page.Window.window.world, title: "Back", body: "To the Diary." }) }
                Back { label: "A rather long page name that is cut short"; onGo: { } }
            }
            MoonLink { text: "Luna · Sleep and evenings"; hint: "Terra’s moon, as a Sheet links to it" }
            DataRows { width: parent.width; rows: [{ label: "K (this page’s own Key)", value: page.pressed + " presses" }] }
        }
        Card {
            title: "Ticks"
            Words { width: parent.width; small: true; quiet: true; text: "Focus marks on their own, round each corner the kit uses." }
            Flow {
                width: parent.width
                spacing: Theme.s5
                Repeater {
                    model: [{ name: "S", r: Theme.radiusS }, { name: "M", r: Theme.radiusM }, { name: "", r: Theme.radius }, { name: "Square", r: 0 }]
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        width: 72; height: 40
                        radius: modelData.r
                        color: Theme.surface
                        border.width: 1; border.color: Theme.line
                        Ticks { on: true; radius: tile.modelData.r }
                        Quiet { anchors.centerIn: parent; text: tile.modelData.name || "Card" }
                    }
                }
            }
        }
    }
}

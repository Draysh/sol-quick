pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Sol.Design

/*
    Quick capture: one line over the desktop, opened by its key from
    whichever Sol app is running (the desktop knocks on its door with
    `ask capture`). As you type, every running world says what it would
    do with the line (the kit's `capture` command asks each one, 100 ms at
    most), and the line shows who will do it ("Terra · tick Walk"); ↑ and
    ↓ choose among several, Enter has it done, Escape closes. It never
    starts an app: the ones not running are named under the line. In the
    night palette whatever the light, on the compositor's frost (its
    layer, `sol-capture`, is blurred like the widgets). Wayland desktops
    with layer-shell only, so AppWindow loads it by address.
*/
Window {
    id: cap

    /** The app's window: closing sets its `capturing` to false. */
    property var host: null
    property var offers: ({ answers: [], away: [] })
    property int chosen: 0
    readonly property var answer: offers.answers.length ? offers.answers[Math.min(chosen, offers.answers.length - 1)] : null
    /** What the world said it did, or why it couldn't. */
    property string said: ""
    property bool failed: false
    property bool busy: false
    /** Each ask counts, so a late answer to an older line is dropped. */
    property int asked: 0
    property bool wasActive: false

    // Night, whatever the light: the line floats over any wallpaper.
    readonly property color sky: "#0c0e13"
    readonly property color text: "#e6e8ed"
    readonly property color bright: "#ffffff"
    readonly property color quiet: "#8b919d"
    readonly property color faint: "#4f5561"
    readonly property color hair: Qt.rgba(1, 1, 1, 0.09)

    color: "transparent"
    width: 680
    height: 300
    visible: true
    title: "Quick capture"

    LayerShell.Window.scope: "sol-capture"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    // No anchors: the compositor centres it on the screen in use.
    LayerShell.Window.anchors: LayerShell.Window.AnchorNone
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    function close_() { if (host) host.capturing = false }
    function ask() {
        const n = ++asked
        const line = field.text.trim()
        if (line === "") { offers = { answers: [], away: offers.away }; return }
        Sol.call("capture", { line: line }).then(o => { if (n === cap.asked) { cap.offers = o; cap.chosen = 0 } }).catch(() => { })
    }
    function go() {
        if (!answer || busy) return
        busy = true
        Sol.call("capture", { line: field.text.trim(), world: answer.world })
            .then(s => { cap.failed = false; cap.said = s || "Done."; closing.start() })
            .catch(why => { cap.failed = true; cap.said = String(why) })
            .finally(() => cap.busy = false)
    }

    onActiveChanged: { if (active) wasActive = true; else if (wasActive && !closing.running) close_() }
    Timer { id: closing; interval: 1300; onTriggered: cap.close_() }
    Timer { id: soon; interval: 40; onTriggered: cap.ask() }
    Component.onCompleted: {
        // Who is running, before anything is typed (a line typed by then wins).
        Sol.call("capture", { line: "" }).then(o => { if (cap.asked === 0) cap.offers = o }).catch(() => { })
        if (host && host.stagedCapture) { field.text = host.stagedCapture; ask() }
        // `_capture=<line>` in a picture's path: the app takes this window's picture beside its own.
        field.forceActiveFocus()
    }

    Rectangle {
        id: panel
        x: 20; y: 20
        width: parent.width - 40
        height: column.y + column.height + 18
        radius: Theme.radiusL
        color: Qt.rgba(0.047, 0.055, 0.075, 0.84)
        border.width: 1; border.color: cap.hair
        // Lit a little from above, as the apps' panels are.
        Rectangle { anchors.fill: parent; anchors.margins: 1; radius: Theme.radiusL - 1; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.045) } GradientStop { position: 0.4; color: "transparent" } } }

        TextInput {
            id: field
            x: 24; y: 18
            width: parent.width - 48 - 18
            font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.weightValue
            color: cap.bright
            selectionColor: Qt.rgba(1, 1, 1, 0.2)
            clip: true
            focus: true
            onTextEdited: { cap.said = ""; cap.failed = false; soon.restart() }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { event.accepted = true; cap.close_() }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; cap.go() }
                else if (event.key === Qt.Key_Down && cap.offers.answers.length) { event.accepted = true; cap.chosen = (cap.chosen + 1) % cap.offers.answers.length }
                else if (event.key === Qt.Key_Up && cap.offers.answers.length) { event.accepted = true; cap.chosen = (cap.chosen + cap.offers.answers.length - 1) % cap.offers.answers.length }
            }
            Text {
                visible: field.text === ""
                text: "Walk, watched, slept 7.5, radio frieren…"
                font: field.font
                color: cap.faint
            }
        }
        Rectangle { x: 1; y: field.y + field.height + 14; width: parent.width - 2; height: 1; color: cap.hair }

        Column {
            id: column
            x: 24; y: field.y + field.height + 28
            width: parent.width - 48
            spacing: 10

            // Who will do it, before Enter.
            Repeater {
                model: cap.offers.answers.slice(0, 3)
                delegate: Row {
                    id: offer
                    required property var modelData
                    required property int index
                    readonly property bool on: offer.index === Math.min(cap.chosen, cap.offers.answers.length - 1)
                    spacing: 12
                    opacity: on ? 1 : 0.55
                    WorldGlyph { world: offer.modelData.world; size: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: offer.modelData.name
                        font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightLabel
                        font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textS); font.capitalization: Font.AllUppercase
                        color: Worlds.get(offer.modelData.world).color
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "·"; color: cap.quiet; font.family: Theme.font; font.pixelSize: Theme.textM }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, column.width - 160)
                        elide: Text.ElideRight
                        text: offer.modelData.does
                        font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: Theme.weightValue
                        color: offer.on ? cap.bright : cap.text
                    }
                    Text { visible: offer.on; anchors.verticalCenter: parent.verticalCenter; text: cap.busy ? "…" : "Enter"; color: cap.faint
                        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel; font.capitalization: Font.AllUppercase; font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs) }
                }
            }
            Text {
                visible: cap.said !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: cap.said
                font.family: Theme.font; font.pixelSize: Theme.textM; font.weight: Theme.weightValue
                color: cap.failed ? "#ff8a7a" : "#8ee6b0"
            }
            Text {
                visible: field.text.trim() !== "" && !cap.offers.answers.length && cap.said === ""
                text: "No world running here knows what to do with that."
                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                color: cap.quiet
            }
            Text {
                visible: cap.offers.away.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                text: cap.awayLine(cap.offers.away)
                font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase
                color: cap.faint
            }
        }
    }

    /** "Neptune and Mercury aren't running." */
    function awayLine(names) {
        if (!names.length) return ""
        const list = names.length === 1 ? names[0] : names.slice(0, -1).join(", ") + " and " + names[names.length - 1]
        return list + (names.length === 1 ? " isn’t running" : " aren’t running")
    }
}

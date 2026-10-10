import QtQuick
import QtQuick.Particles

/*
    Pairing with Sol: the address, then the code to approve in Sol. Shown
    until the app is paired. The world rises out of the corner; the card
    sits on real glass.
*/
Item {
    id: root

    property string world: "terra"
    readonly property var w: Worlds.get(world)

    property string server: ""
    property bool busy: false
    property string error: ""
    property real now: Date.now()
    // The minutes left on the code, counted down while there is one.
    Timer { interval: 1000; running: !!root.pairing; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() }

    readonly property var pairing: Sol.status && Sol.status.state === "pairing" ? Sol.status : null
    readonly property string ended: Sol.status && Sol.status.state === "unpaired" && Sol.status.error ? Sol.status.error : ""
    readonly property int minutesLeft: pairing ? Math.max(0, Math.round((new Date(pairing.expires_at).getTime() - now) / 60000)) : 0

    function connect() {
        if (busy || server.trim() === "") return
        busy = true
        error = ""
        Sol.call("connect", { server: server.trim() }).catch(why => error = String(why)).finally(() => busy = false)
    }

    Rectangle { anchors.fill: parent; color: Theme.space }

    // The world, out of the corner, lit from above the panel.
    Item {
        id: scene
        anchors.fill: parent
        clip: true
        readonly property real vmax: Math.max(width, height) / 100
        Body {
            world: root.world
            disc: scene.vmax * 64
            x: -scene.vmax * 26
            y: scene.height + scene.vmax * 34 - disc
            light: 20
            phase: 0.55
            // A slow drift, so the scene breathes.
            transform: Translate { id: breathe; y: 0 }
            SequentialAnimation { running: Theme.alive; loops: Animation.Infinite; NumberAnimation { target: breathe; property: "y"; to: -6; duration: Theme.drift / 2; easing.type: Easing.InOutSine } NumberAnimation { target: breathe; property: "y"; to: 0; duration: Theme.drift / 2; easing.type: Easing.InOutSine } }
        }
    }

    // Dust in the dark: a few motes drifting up past the world, lit by it.
    ParticleSystem {
        id: dust
        anchors.fill: parent
        running: Theme.alive
        Emitter {
            anchors.fill: parent
            emitRate: 6
            lifeSpan: 14000
            lifeSpanVariation: 6000
            size: 2
            sizeVariation: 2
            velocity: AngleDirection { angle: -90; angleVariation: 20; magnitude: 8; magnitudeVariation: 6 }
        }
        ItemParticle {
            fade: true
            // By day a mote is a shadow on paper: fainter.
            delegate: Rectangle { width: 2; height: 2; radius: 1; color: Theme.textBright; opacity: Theme.day ? 0.12 : 0.35 }
        }
    }

    // The panel: the name, the tagline, and the card on glass; in the middle,
    // or scrolling when the window is shorter than it (the code waiting in Sol is tall).
    Flickable {
        id: pane
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, panel.height + Theme.s4 * 2)
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Settle {
            id: panel
            wait: Theme.rise / 3
            slow: true
            x: (pane.width - width) / 2
            y: Math.max(Theme.s4, (pane.height - height) / 2)
            width: Math.min(440, pane.width - Theme.s4 * 2)
            height: panelColumn.implicitHeight

            Column {
                id: panelColumn
                width: parent.width
                spacing: Theme.s3

                Text {
                    text: root.w.name
                    font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textXs
                    font.letterSpacing: Theme.track(0.32, Theme.textXs); font.capitalization: Font.AllUppercase
                    color: Theme.textBright
                }
                Words { text: root.w.tagline; small: true; color: Theme.textValue }

                Item {
                    width: parent.width
                    height: card.implicitHeight

                    // Real glass: what is behind the card, blurred, rounded with it.
                    Glass { anchors.fill: parent; from: scene; blur: 0.8; bend: 0; radius: card.radius; tint: Theme.tint(Theme.veil, 0.72) }

                    Card {
                        id: card
                        width: parent.width
                        gap: Theme.s4

                        Item { width: 1; height: 10 }

                        // Approve in Sol.
                        Column {
                            visible: !!root.pairing
                            width: parent.width
                            spacing: Theme.s4
                            Heading { level: 2; text: "Approve in Sol" }
                            Words {
                                width: parent.width
                                text: "Open Sol at <b>" + (root.pairing ? root.pairing.server : "") + "</b> and approve this code, under Devices or on " + root.w.name + "’s page."
                                textFormat: Text.RichText
                            }
                            Item {
                                width: parent.width; height: 210 + Theme.s3 * 2
                                Reticle {
                                    anchors.centerIn: parent
                                    size: 210; tilt: root.w.tilt
                                    Rectangle {
                                        width: digits.implicitWidth + 20; height: digits.implicitHeight + 4
                                        radius: Theme.radiusS
                                        color: Theme.space
                                        Text {
                                            id: digits
                                            anchors.centerIn: parent
                                            text: root.pairing ? root.pairing.code : ""
                                            font.family: Theme.font; font.weight: Theme.weightDisplay; font.pixelSize: 30
                                            font.letterSpacing: Theme.track(0.14, 30)
                                            color: Theme.text
                                        }
                                    }
                                }
                            }
                            Quiet { text: "Waiting · " + root.minutesLeft + " min left"; width: parent.width; horizontalAlignment: Text.AlignHCenter }
                            Button { variant: "quiet"; text: "Cancel"; onClicked: Sol.call("cancel") }
                        }

                        // Connect to Sol.
                        Column {
                            visible: !root.pairing
                            width: parent.width
                            spacing: Theme.s4
                            Heading { level: 2; text: "Connect to Sol" }
                            Words { width: parent.width; text: root.w.name + " keeps its data in your Sol. Where does it run?" }
                            Field {
                                id: address
                                width: parent.width
                                label: "Sol address"
                                placeholder: "https://sol.your-tailnet.ts.net"
                                error: root.error !== "" ? root.error : root.ended
                                onTextChanged: root.server = text
                                onAccepted: root.connect()
                                Component.onCompleted: input.forceActiveFocus()
                            }
                            Button { variant: "primary"; text: "Connect"; busy: root.busy; enabled: root.server.trim() !== ""; onClicked: root.connect() }
                            Words { visible: Sol.kept.earlier > 0; width: parent.width; small: true; quiet: true
                                text: (Sol.kept.earlier === 1 ? "A change made here wasn’t sent before this device was unpaired. It is kept, and goes"
                                    : Sol.kept.earlier + " changes made here weren’t sent before this device was unpaired. They are kept, and go")
                                    + " to Sol once you connect again as the same person." }
                        }

                        Item { width: 1; height: 10 }
                    }
                }

                Row {
                    visible: !!Sol.app && Sol.app.here && Sol.app.here.state === "loose"
                    spacing: Theme.s2
                    Quiet { text: root.w.name + " isn’t installed yet."; anchors.verticalCenter: parent.verticalCenter }
                    Button { variant: "quiet"; text: "Install it"; onClicked: Sol.call("install_app").catch(why => root.error = String(why)) }
                }
            }
        }
    }

    Grain { }
}

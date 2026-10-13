pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The worlds: the window's world's Sheet across the top (pinned, as on
    a world's first screen, its figures beside the main action), chips to
    turn the window into each world in turn (← and → too), then the
    pictures a world shows when its art is missing.
*/
Screen {
    id: page

    title: "Worlds"
    padded: false

    readonly property var order: ["terra", "luna", "saturn", "titan", "mercury", "neptune", "triton", "sol"]
    readonly property var win: page.Window.window
    readonly property string world: win ? win.world : "sol"
    readonly property var w: Worlds.get(world)

    function turn(by) {
        const i = order.indexOf(world)
        win.world = order[(i + by + order.length) % order.length]
    }

    Key { on: page; sequence: "Left"; onActivated: page.turn(-1) }
    Key { on: page; sequence: "Right"; onActivated: page.turn(1) }

    // What each world's band says, as its own first screen would.
    readonly property var samples: ({
        terra: { callout: ["Walk = done", "Read = 20 min", "Water = 6 / 8"], figures: [{ value: "12", label: "Streak", jp: "連続" }, { value: "3/5", label: "Today", jp: "今日" }] },
        luna: { callout: ["Lights out = 23:10", "Wind down = 22:40"], figures: [{ value: "7h20", label: "Slept", jp: "睡眠" }, { value: "23:10", label: "Lights out", jp: "就寝" }] },
        saturn: { callout: ["Dune: Part Two = 1:12 left", "Frieren = ep 14"], figures: [{ value: "06", label: "Watching", jp: "視聴中" }, { value: "291", label: "Episodes", jp: "話" }, { value: "126h", label: "Watched", jp: "時間" }] },
        titan: { callout: ["Tonight = Past Lives", "Then = Paprika"], figures: [{ value: "12", label: "Picks", jp: "推し" }, { value: "03", label: "Seen", jp: "視聴" }] },
        mercury: { callout: ["Due = 24 cards", "New = 10 words"], figures: [{ value: "24", label: "Due", jp: "復習" }, { value: "40", label: "Streak", jp: "連続" }] },
        neptune: { callout: ["Playing = Blue in Green", "Next = So What"], figures: [{ value: "418", label: "Albums", jp: "アルバム" }, { value: "03/11", label: "Queue", jp: "キュー" }] },
        triton: { callout: ["On air = FIP Jazz", "Found = 3 new"], figures: [{ value: "26", label: "Stations", jp: "局" }, { value: "93.5", label: "On air", jp: "放送中" }] },
        sol: { callout: ["Worlds = 7", "Events = 1 204"], figures: [{ value: "07", label: "Worlds", jp: "世界" }, { value: "03", label: "Devices", jp: "端末" }] }
    })
    readonly property var sample: samples[world] || samples.sol

    header: Sheet {
        world: page.world
        drift: page.contentY
        callout: page.sample.callout
        figures: page.sample.figures
        moons: Worlds.kin(page.world).map(k => ({ id: k.id, label: k.name + " · " + k.role, hint: k.tagline, open: () => { page.win.world = k.id } }))
        Button { variant: "primary"; text: "Next world"; hint: "Or →"; onClicked: page.turn(1) }
    }

    Column {
        x: page.margin
        width: parent.width - page.margin * 2
        spacing: Theme.s4

        Column {
            width: parent.width
            spacing: Theme.s2
            Words { width: parent.width; quiet: true; text: page.w.name + " · " + page.w.role + " — " + page.w.tagline }
            Flow {
                width: parent.width
                spacing: Theme.s2
                Repeater {
                    model: page.order
                    delegate: Chip {
                        required property string modelData
                        text: Worlds.get(modelData).name
                        on: page.world === modelData
                        onClicked: page.win.world = modelData
                    }
                }
            }
        }

        // What a world shows where a poster, a cover or a still can't be had: one character in its colours.
        Card {
            width: parent.width
            title: "Missing art"
            jp: "画像なし"
            Flow {
                width: parent.width
                spacing: Theme.s3
                Repeater {
                    model: ["Severance", "Frieren", "Harbour Lights", "天気の子", "Quiet Static", "Blue in Green"]
                    delegate: Picture { required property string modelData; width: 120; name: modelData }
                }
                Picture { width: 160; ratio: 1; name: "Late Tides" }
                Picture { width: 48; name: "Small" }
            }
            Words { width: parent.width; small: true; quiet: true; text: "The name's first Japanese character, else one of the flavour's own chosen by the name; the name at the foot once the card is wide enough." }
        }

        // Every Icon by name: the chrome's own first, then Lucide's.
        Card {
            id: iconCard
            width: parent.width
            title: "Icon"
            Icon { id: probe; visible: false }
            Flow {
                width: parent.width
                spacing: Theme.s2
                Repeater {
                    model: Object.keys(probe.paths).concat(Object.keys(probe.lines))
                    delegate: Item {
                        id: iconCell
                        required property string modelData
                        width: 84
                        height: 56
                        Icon { x: (parent.width - width) / 2; y: 6; name: iconCell.modelData; size: 20; color: Theme.text }
                        Text {
                            x: (parent.width - width) / 2; y: 36
                            width: Math.min(implicitWidth, parent.width)
                            elide: Text.ElideRight
                            text: iconCell.modelData
                            font.family: Theme.font; font.pixelSize: Theme.textXs
                            color: Theme.textQuiet
                        }
                    }
                }
            }
            Row {
                spacing: Theme.s4
                Repeater {
                    model: [12, 16, 24, 48]
                    delegate: Icon { required property int modelData; name: "settings"; size: modelData; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                Icon { name: "sparkles"; size: 48; stroke: 1; color: Theme.textFaint; anchors.verticalCenter: parent.verticalCenter }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Each at 20 px. Then one at 12 (a button), 16 (the sidebar, menus and the palette), 24 and 48, and a large faint one as an empty page has." }
        }
    }
}

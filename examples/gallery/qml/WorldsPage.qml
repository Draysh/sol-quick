pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The worlds: the window's world's Sheet across the top (pinned, as on
    a world's first screen), chips to turn the window into each world in
    turn (← and → too), then every Body at the sizes the kit draws them
    and every WorldGlyph.
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
        terra: { callout: ["Walk = done", "Read = 20 min", "Water = 6 / 8"], rows: [[{ label: "Streak", value: "12 days" }, { label: "Today", value: "3 of 5" }], [{ label: "Slept", value: "7.5 h" }], [{ label: "Sol", value: "in sync" }]] },
        luna: { callout: ["Lights out = 23:10", "Wind down = 22:40"], rows: [[{ label: "Tonight", value: "Waxing gibbous" }], [{ label: "Slept", value: "7 h 20 min" }]] },
        saturn: { callout: ["Dune: Part Two = 1:12 left", "Frieren = ep 14"], rows: [[{ label: "Watching", value: "6" }, { label: "This week", value: "4 h 30 min" }], [{ label: "Sol", value: "in sync" }]] },
        titan: { callout: ["Tonight = Past Lives", "Then = Paprika"], rows: [[{ label: "Picks", value: "12" }], [{ label: "Seen", value: "3 this week" }]] },
        mercury: { callout: ["Due = 24 cards", "New = 10 words"], rows: [[{ label: "Kana", value: "92 %" }, { label: "Streak", value: "40 days" }], [{ label: "Sol", value: "in sync" }]] },
        neptune: { callout: ["Playing = Blue in Green", "Next = So What"], rows: [[{ label: "Albums", value: "418" }], [{ label: "Navidrome", value: "answering" }]] },
        triton: { callout: ["On air = FIP Jazz", "Found = 3 new"], rows: [[{ label: "Stations", value: "26" }], [{ label: "Listening", value: "1 h 10 min" }]] },
        sol: { callout: ["Worlds = 7", "Events = 1 204"], rows: [[{ label: "Devices", value: "3" }], [{ label: "Version", value: "0.9.0" }]] }
    })
    readonly property var sample: samples[world] || samples.sol

    header: Sheet {
        world: page.world
        drift: page.contentY
        // Mercury's rings: three weeks of reviews in a row.
        rings: page.world === "mercury" ? 3 : 0
        callout: page.sample.callout
        rows: page.sample.rows
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

        Card {
            width: parent.width
            title: "Body · Terra's surface (green, cloudy)"
            Strip {
                width: parent.width
                spacing: Theme.s3
                fades: true
                ground: Theme.raised
                Repeater {
                    model: [{ green: 0, cloudy: 0.2, name: "Dry, clear" }, { green: 0.2, cloudy: 0.85, name: "Dry, overcast" }, { green: 0.5, cloudy: 0.5, name: "As it is" },
                        { green: 0.8, cloudy: 0.35, name: "Green" }, { green: 1, cloudy: 0.1, name: "Lush, clear" }]
                    delegate: Item {
                        id: surfaceCell
                        required property var modelData
                        width: 150
                        height: 150 + 48 + Theme.s4 * 2
                        Body { world: "terra"; disc: 120; x: 15; y: 15; green: surfaceCell.modelData.green; cloudy: surfaceCell.modelData.cloudy }
                        Row {
                            y: 150
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.s2
                            Body { world: "terra"; disc: 48; animated: false; green: surfaceCell.modelData.green; cloudy: surfaceCell.modelData.cloudy }
                            Item { width: 22; height: 48; Body { world: "terra"; disc: 22; y: 13; animated: false; green: surfaceCell.modelData.green; cloudy: surfaceCell.modelData.cloudy } }
                        }
                        Quiet { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: surfaceCell.modelData.name }
                    }
                }
            }
        }

        Repeater {
            model: [22, 48, 120, 300]
            delegate: Card {
                id: sizeCard
                required property int modelData
                width: parent.width
                title: "Body · " + modelData + " px"
                Strip {
                    width: parent.width
                    spacing: Theme.s3
                    fades: true
                    ground: Theme.raised
                    Repeater {
                        model: page.order
                        delegate: Item {
                            id: cell
                            required property string modelData
                            readonly property real room: Math.max(72, sizeCard.modelData * 1.5)
                            width: room
                            height: room + Theme.s4
                            Body {
                                world: cell.modelData
                                disc: sizeCard.modelData
                                x: (cell.room - disc) / 2
                                y: (cell.room - disc) / 2
                            }
                            Quiet { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: Worlds.get(cell.modelData).name }
                        }
                    }
                }
            }
        }

        Card {
            width: parent.width
            title: "WorldGlyph"
            Flow {
                width: parent.width
                spacing: Theme.s4
                Repeater {
                    model: page.order
                    delegate: Row {
                        id: glyphs
                        required property string modelData
                        spacing: Theme.s2
                        WorldGlyph { world: glyphs.modelData; size: 10; anchors.verticalCenter: parent.verticalCenter }
                        WorldGlyph { world: glyphs.modelData; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        WorldGlyph { world: glyphs.modelData; size: 10; hollow: true; anchors.verticalCenter: parent.verticalCenter }
                        Words { text: Worlds.get(glyphs.modelData).name; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Each at 10 and 16 px, then hollow (the app isn’t answering)." }
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

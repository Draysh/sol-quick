pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The panels and what goes in them: Card in its ways (plain, titled,
    with a world, openable, with a menu), Grid at a few widths, DataRows,
    Display, Progress, Callout, every kind of Skeleton and Chart, a
    Settle list, a Strip, and Picture and Poster loaded, missing, dimmed
    and lifted. The pictures are the kit's own photographs.
*/
Screen {
    id: page

    title: "Panels"

    readonly property var order: ["terra", "luna", "saturn", "titan", "mercury", "neptune", "triton", "sol"]
    readonly property string missing: "qrc:/qt/qml/Sol/Design/assets/worlds/not-there.png"
    readonly property var week: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    header: PageHead {
        title: "Panels"
        lead: "Cards, figures, charts and pictures"
        Button { variant: "quiet"; text: "Again"; hint: "The figures and charts arrive again"; onClicked: { page.round++ } }
    }
    /** Bumped by Again: the counting figures and the charts take new values. */
    property int round: 0

    Grid {
        width: parent.width
        min: 340

        Card {
            Words { width: parent.width; text: "A plain card: no title, just what it holds." }
        }
        Card {
            title: "Titled"
            Words { width: parent.width; quiet: true; text: "Its title in the world’s light, over a hairline." }
        }
        Card {
            title: "With a world"
            world: "saturn"
            openable: true
            onOpened: Notices.show({ world: "saturn", title: "Opened", body: "The card’s Open link." })
            Words { width: parent.width; quiet: true; text: "The world’s glyph by the title, and Open in the head." }
        }
        Card {
            title: "With a menu"
            menu: [{ label: "Rename", run: () => { } }, { label: "Move to", items: () => [{ label: "Watching", run: () => { } }, { label: "Later", run: () => { } }] }, { separator: true }, { label: "Remove", danger: true, run: () => { } }]
            Words { width: parent.width; quiet: true; text: "Right-click it for its menu." }
        }

        Card {
            title: "DataRows"
            DataRows { width: parent.width; rows: [{ label: "Streak", value: "12 days" }, { label: "Slept", value: "7.5 h" }, { label: "Path", value: "~/Music/Library", keepCase: true }] }
            DataRows { width: parent.width; align: Text.AlignRight; rows: [{ label: "Right", value: "aligned" }] }
        }
        Card {
            title: "Display and Progress"
            Row {
                spacing: Theme.s5
                Display { value: page.round % 2 ? 318 : 1204 }
                Display { value: page.round % 2 ? 95 : 452; format: m => Math.round(m / 60) + " h"; size: 32; anchors.bottom: parent.bottom }
            }
            Progress { width: parent.width; value: page.round % 2 ? 0.8 : 0.42; start: "1:12"; end: "2:46" }
            Progress { width: parent.width; value: 1 }
        }
        Card {
            title: "Callout"
            Callout { lines: ["Walk = done", "Read = 20 min", "Water = 6 / 8"] }
            Callout { flip: true; lines: ["Next = So What"] }
        }
        Card {
            title: "Settle"
            Column {
                width: parent.width
                Repeater {
                    model: ["The first row arrives", "then the next", "a stagger later", "never more than 400 ms late"]
                    delegate: Settle {
                        id: row
                        required property string modelData
                        required property int index
                        place: index
                        width: parent.width
                        height: 40
                        Rectangle { visible: row.index < 3; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                        Words { anchors.verticalCenter: parent.verticalCenter; text: row.modelData }
                    }
                }
            }
        }
    }

    Card {
        width: parent.width
        title: "Chart"
        Grid {
            width: parent.width
            min: 300
            gap: Theme.s4
            Column {
                spacing: Theme.s2
                Quiet { text: "Bars, one series" }
                Chart { width: parent.width; height: 160; labels: page.week; series: [{ name: "Slept", unit: " h", values: page.round % 2 ? [6, 7, 8, 5.5, 7, 9, 8] : [7.5, 6, 8, 7, null, 9, 6.5] }] }
            }
            Column {
                spacing: Theme.s2
                Quiet { text: "Bars, two series" }
                Chart { width: parent.width; height: 160; labels: page.week; series: [{ name: "Done", values: [3, 4, 5, 2, 4, 5, 3] }, { name: "Due", values: [5, 5, 5, 5, 5, 5, 5], color: Theme.textQuiet }] }
            }
            Column {
                spacing: Theme.s2
                Quiet { text: "Line, two series" }
                Chart { width: parent.width; height: 160; kind: "line"; labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"]; series: [{ name: "Hours", values: [12, 18, 9, 22, 30, 26, 14, 20] }, { name: "Titles", values: [4, 6, 3, 8, 9, 7, 5, 6], color: Theme.textQuiet }] }
            }
            Column {
                spacing: Theme.s2
                Quiet { text: "Empty" }
                Chart { width: parent.width; height: 160; labels: page.week; series: [] }
            }
        }
    }

    Card {
        width: parent.width
        title: "Grid at three widths"
        Repeater {
            model: [1, 0.62, 0.36]
            delegate: Column {
                id: band
                required property real modelData
                width: parent.width * modelData
                spacing: Theme.s2
                Quiet { text: Math.round(band.width) + " px" }
                Grid {
                    width: parent.width
                    min: 180
                    gap: Theme.s3
                    Repeater {
                        model: 3
                        delegate: Card {
                            required property int index
                            title: "Card " + (index + 1)
                            Words { width: parent.width; small: true; quiet: true; text: index === 1 ? "A taller card: every row is as tall as its tallest, each card starting at the top." : "A card." }
                        }
                    }
                }
            }
        }
    }

    Card {
        width: parent.width
        title: "Skeleton"
        Grid {
            width: parent.width
            min: 300
            Column { spacing: Theme.s2; Quiet { text: "rows" } Skeleton { width: parent.width; kind: "rows"; count: 3 } }
            Column { spacing: Theme.s2; Quiet { text: "cards" } Skeleton { width: parent.width; kind: "cards"; count: 2 } }
            Column { spacing: Theme.s2; Quiet { text: "posters" } Skeleton { width: parent.width; kind: "posters"; count: 4 } }
        }
    }

    Card {
        width: parent.width
        title: "Strip"
        Strip {
            width: parent.width
            fades: true
            ground: Theme.raised
            Repeater {
                model: page.order.concat(page.order)
                delegate: Poster {
                    required property string modelData
                    width: 92
                    source: Worlds.get(modelData).image
                    name: Worlds.get(modelData).name
                }
            }
        }
        Words { width: parent.width; small: true; quiet: true; text: "Sideways wheel, swipe or Shift with the wheel; the hairline shows where you are." }
    }

    Card {
        width: parent.width
        title: "Picture and Poster"
        Flow {
            width: parent.width
            spacing: Theme.s4
            Repeater {
                model: [
                    { label: "Loaded", url: "terra" },
                    { label: "Missing", url: "" },
                    { label: "Dim", url: "neptune", dim: true },
                    { label: "Lifted", url: "titan", lift: true },
                    { label: "1:1, outlined", url: "luna", ratio: 1, outline: true },
                    { label: "16:9, a still", url: "saturn", ratio: 16 / 9, radius: Theme.radius }
                ]
                delegate: Column {
                    id: pic
                    required property var modelData
                    spacing: Theme.s2
                    Picture {
                        width: pic.modelData.ratio > 1 ? 220 : 120
                        url: pic.modelData.url ? Worlds.get(pic.modelData.url).image : page.missing
                        name: pic.modelData.url ? Worlds.get(pic.modelData.url).name : "A picture that isn’t there"
                        ratio: pic.modelData.ratio || 2 / 3
                        outline: !!pic.modelData.outline
                        dim: !!pic.modelData.dim
                        lift: !!pic.modelData.lift
                        hovered: !!pic.modelData.lift
                        radius: pic.modelData.radius || Theme.radiusM
                    }
                    Quiet { text: pic.modelData.label }
                }
            }
            Column {
                spacing: Theme.s2
                Poster { width: 120; source: Worlds.get("mercury").image; name: "Mercury" }
                Quiet { text: "Poster" }
            }
            Column {
                spacing: Theme.s2
                Poster { width: 120; source: page.missing; name: "A cover that never came" }
                Quiet { text: "Poster, missing" }
            }
        }
    }
}

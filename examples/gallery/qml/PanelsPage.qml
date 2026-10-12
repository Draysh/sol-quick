pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The panels and what goes in them: Card in its ways (plain, titled,
    with a world, openable, with a menu), the ExportCard, Grid at a few
    widths, DataRows, Display, Progress, Callout, every kind of Skeleton
    and Chart, a Settle list, a Strip, Picture and Poster loaded,
    missing, dimmed and lifted, a long grid and list sifted by a field, and
    a masonry grid of uneven cards with a feature card across two columns
    (Again grows one, and the cards under it glide to their new places).
    In the Yozora look a card more shows its own pieces (HudLabel,
    HudSeal square and round, AngledButton, SlantTicks, HudPanel, a ruled
    TextArea in ink). The pictures are the
    kit's own photographs.
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
            Words { width: parent.width; quiet: true; text: "Right-click it, or the button in its head, for its menu." }
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
        ExportCard { }
        Card {
            title: "Empty"
            Empty { width: parent.width; world: "luna"; icon: "bed"; line: "A quiet sky so far."; hint: "Nights appear here as you log bedtimes and mornings."; action: "Log tonight" }
            Empty { width: parent.width; compact: true; world: "saturn"; icon: "star"; line: "Nothing in orbit yet."; hint: "Rate a title and it starts to circle here." }
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
        // The Yozora look's own pieces (SOL_LOOK=yozora): only while it is on.
        Card {
            visible: Theme.yozora
            title: "Yozora"
            jp: "夜空"
            HudLabel { text: "A HUD label"; jp: "見出し" }
            Row {
                spacing: Theme.s3
                HudSeal { text: "学" }
                HudSeal { text: "済"; size: 28 }
                HudSeal { text: "良"; size: 28; round: true; tilt: 8; color: Theme.hudAccent; paper: Theme.hud.ink || Theme.hud.ground }
                AngledButton { text: "Play"; icon: "play" }
                AngledButton { text: "Details"; outline: true; light: Theme.hudSecond }
            }
            SlantTicks { width: parent.width; value: page.round % 2 ? 0.3 : 0.7 }
            HudPanel { width: parent.width; title: "A HudPanel"; jp: "硝子"; aside: "03"; brackets: Theme.hudSecond
                Words { width: parent.width; quiet: true; text: "Glass over the still, its corner cut, brackets in the second light." } }
            // Writing in ink on a ruled page (Terra's notebook).
            Rectangle {
                width: parent.width
                height: ruledArea.height + Theme.s3 * 2
                color: "#fbf8ee"
                TextArea { id: ruledArea; x: Theme.s3; y: Theme.s3; width: parent.width - Theme.s3 * 2; large: true; minLines: 3; name: "Today"; ink: "#14233f"; ruled: Theme.tint("#5b8fd6", 0.4); text: "Swam in the lake after work; the light came through the trees in stripes." }
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

    // A library's worth of tiles and rows: only those in sight are made, and the field sifts them.
    // Masonry: each card into the shortest column, a feature card across two, one across the row.
    Column {
        width: parent.width
        spacing: Theme.s3
        Heading { level: 3; text: "Masonry" }
        Grid {
            width: parent.width
            min: 240
            masonry: true
            Card {
                title: "A feature card"
                span: 2
                world: "saturn"
                Words { width: parent.width; text: "Two columns wide (span 2): the cards around it fill in beside and under it, each into the shortest column." }
            }
            Card {
                title: "Short"
                Words { width: parent.width; quiet: true; text: "One line." }
            }
            Card {
                title: "Tall"
                DataRows { width: parent.width; rows: page.week.map((d, n) => ({ label: d, value: (6 + n % 3) + " h" })) }
            }
            Card {
                title: "Grows with Again"
                Words { width: parent.width; quiet: true; text: page.round % 2 ? "Taller now: the cards under it glide down to their new places, and back up again with the next Again. A grid places its cards again whenever one grows, hides or shows." : "Press Again in the head: this card grows." }
            }
            Card {
                title: "Medium"
                Progress { width: parent.width; value: 0.6; start: "3 of 5" }
                Words { width: parent.width; quiet: true; text: "A figure and a line under it." }
            }
            Card {
                title: "Another"
                Words { width: parent.width; quiet: true; text: "Into whichever column is shortest when its turn comes." }
            }
            Card {
                title: "The whole row"
                span: "row"
                Words { width: parent.width; quiet: true; text: "Span “row” takes every column, under everything before it." }
            }
        }
    }

    readonly property var many: Array.from({ length: 600 }, (_, n) => ({ n: n + 1, world: page.order[n % page.order.length], name: Worlds.get(page.order[n % page.order.length]).name + " " + (n + 1) }))
    Sift { id: sift; rows: page.many; words: longFilter.text; text: r => r.name; order: (a, b) => b.n - a.n }
    Card {
        width: parent.width
        title: "LongGrid, LongList and Sift"
        Column {
            width: parent.width
            spacing: Theme.s4
            Field { id: longFilter; width: Math.min(320, parent.width); label: "Filter"; placeholder: "A world or a number" }
            Quiet { text: sift.shown.length + " of 600 · " + longGrid.count + " tiles, only those in sight made" }
            LongGrid {
                id: longGrid
                width: parent.width
                min: 110
                rows: 4
                tileHeight: cell + Theme.s2 + Theme.textS * 1.5
                model: sift.shown
                delegate: Settle {
                    id: tile
                    required property var modelData
                    required property int index
                    width: longGrid.cell; height: longGrid.tileHeight
                    place: index
                    animated: longGrid.arrives(index)
                    Picture { id: tilePic; width: parent.width; ratio: 1; url: Worlds.get(tile.modelData.world).image; name: tile.modelData.name; outline: true }
                    Words { y: tilePic.height + Theme.s2; width: parent.width; small: true; elide: Text.ElideRight; text: tile.modelData.name }
                }
            }
            LongList {
                id: longList
                width: parent.width
                model: sift.shown
                delegate: Settle {
                    id: line
                    required property var modelData
                    required property int index
                    width: longList.width; height: 40
                    place: index
                    animated: longList.arrives(index)
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                    Words { anchors.verticalCenter: parent.verticalCenter; text: line.modelData.name }
                    Quiet { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Row " + (line.index + 1) }
                }
            }
        }
    }
}

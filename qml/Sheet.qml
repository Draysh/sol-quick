pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

/*
    The band across the top of a world's first screen: a title card over
    the world's still. A HUD line, the page's Japanese (`jp`, the world's
    name in Japanese unless given) in the title serif, the callout as the
    English under it, then what sits under the title (moon links, the
    screen's main action) beside two or three big figures with their
    Japanese tags (`figures`, drawn as HeroFigures); Mercury's has a line
    written down the right (`vertical`). The HUD line is the world, the day
    and the hour unless the page says what is on (`hud`, `hudJp`). On a few
    days a year a comet crosses its sky. It is a header, not a hero: the
    working surface starts right under it, and in a window under 1300 px
    wide it is a compact card (about 220 px), so the page's own first card
    shows in the first view.

    `drift` is the pane's scroll: the title sinks a little slower than the
    band, so the sheet has depth.

    With `aside`, in a window under 1300 px wide the title card stands
    beside the page instead of over it: a column down the left of the pane,
    on the still, the title at its top and what sits under it at its foot,
    and the page's own content to its right from the first line (a page
    places its column at the Screen's `startX`, `startWidth` wide).

        Sheet { world: "terra"; callout: ["Walk = done"]; figures: [{ value: "12", label: "Streak", jp: "連続" }, { value: "3/5", label: "Today", jp: "今日" }] }
        Sheet { aside: true; … }   …   Column { x: page.startX; width: page.startWidth; … }
*/
Item {
    id: root

    property string world: "terra"
    /** Defaults to the world's name. */
    property string name: ""
    property var callout: []
    /** Two or three big figures beside what sits under the title: `{ value, label, jp }` ("06", "Watching", "視聴中"). */
    property var figures: []
    /** `{ label, open }` links to the world's moons, shown under the name. */
    property var moons: []
    /** Extra content under the name, such as the screen's main action. */
    default property alias under: underRow.data
    property real drift: 0
    /** The title in Japanese: "続きから。". The world's name in Japanese when not given. */
    property string jp: ""
    /** The HUD line over the title, and its Japanese: "Now playing · 3 of 11", "再生中". The world, the day and the hour when "". */
    property string hud: ""
    property string hudJp: ""
    /** A line written down the right, top to bottom (Mercury's flavour shows one); with the flavour's `signs`, a lit sign (katakana reads best). */
    property string vertical: Theme.hud.motif === "shrine" ? "今日も一歩ずつ" : ""
    /** 0 at rest, 1 shrunk to a bar; the Screen drives it when the Sheet is pinned. */
    property real collapse: 0
    readonly property real compact: Theme.navHeight

    /** Beside the page rather than over it in a window under 1300 px wide (see above). */
    property bool aside: false
    /** Standing beside the page now: `aside`, in such a window. */
    readonly property bool beside: aside && tight
    /** The column's width beside the page. */
    readonly property real besideWidth: Math.round(Math.max(300, Math.min(380, width * 0.36)))
    /** The page it heads, for its height beside it. */
    readonly property Item hostScreen: Theme.screenOf(root)

    readonly property var w: Worlds.get(world)
    readonly property bool portrait: width < 700
    /** A window under 1300 px wide: the title card is compact, so the page's first card is in view. */
    readonly property bool tight: !portrait && (Window.window ? Window.window.width : width + Theme.sidebar) < 1300
    readonly property real u: portrait ? width / 390 : width / 1600
    /** Its title card and what sits under it, with their room above and below. */
    readonly property real contentH: hero.implicitHeight + (center.height > 0 ? center.height + Theme.s3 : 0) + (tight ? Theme.s3 * 2 : Theme.s4 * 2)
    // Never shorter than the title and what sits under it (a narrow pane stacks a button and
    // the moons in lines of their own).
    readonly property real bandH: tight ? Math.max(200, contentH)
        : Math.max(portrait ? Math.max(240, Math.min(360, u * 340)) : Math.max(260, Math.min(400, u * 470)), contentH)

    /** The title card lands (0 → 1) as its page arrives: after the page's turn, or at the opening's last beat. */
    property real landed: 1
    function reveal(dir) {
        landing.stop()
        // The window opening: once the title has landed, the flavour's sign catches its light.
        if (dir === "open" && sign.visible) sign.catchLight(Theme.calm ? 0 : Theme.land + Theme.hit)
        if (dir === "tab" || Theme.calm || Theme.land === 0) { landed = 1; return }
        const page = Theme.screenOf(root)
        landWait.duration = page && typeof page.landWait === "function" ? page.landWait(dir) : 0
        landed = 0
        landing.start()
    }
    SequentialAnimation {
        id: landing
        PauseAnimation { id: landWait; duration: 0 }
        NumberAnimation { target: root; property: "landed"; to: 1; duration: Theme.land + Theme.hit; easing: Theme.beat.curve }
    }
    Settling { when: landing.running }

    width: parent ? parent.width : 1200
    readonly property real fullHeight: beside && hostScreen ? hostScreen.height : bandH
    implicitHeight: fullHeight
    height: beside ? fullHeight : Math.round(fullHeight - (fullHeight - compact) * collapse)
    // Shrinking, nothing of it draws past its edge over the page.
    clip: true

    Item {
        id: band
        width: root.beside ? root.besideWidth : parent.width
        height: Math.max(root.compact, root.height)
        clip: true

        // The bar it becomes: the world small at the left, the name beside it.
        Row {
            x: Theme.margin(root.width)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s3
            opacity: Math.max(0, (root.collapse - 0.6) / 0.4)
            z: 2
            // The world's kanji in a diamond, as the rail has it.
            Item {
                width: 24; height: 24
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.centerIn: parent; width: 18; height: 18; rotation: 45; antialiasing: true; color: Theme.tint(Theme.hudAccent, 0.12); border.width: 1.5; border.color: Theme.hudAccent }
                Text { anchors.centerIn: parent; text: Theme.jpOf(root.world).charAt(0); font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle; font.pixelSize: 12; color: Theme.hudText }
            }
            Text { text: root.name !== "" ? root.name : root.w.name; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontCaps; font.weight: Theme.weightName; font.pixelSize: Theme.textM; font.letterSpacing: Theme.track(0.12, Theme.textM); font.capitalization: Font.AllUppercase; color: Theme.textBright }
            Text { visible: root.figures.length > 0 && width >= 80; text: root.figures.map(f => f.value + " " + f.label).join(" · "); anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase; color: Theme.textQuiet; elide: Text.ElideRight; width: Math.max(0, root.width - 400) }
        }

        // Shrunk to a bar, it is glass; a light flavour's frost comes in later, once the white title
        // over the still has mostly gone, so the two never stand faint on each other.
        HudGlass { visible: root.collapse > 0.05; opacity: Theme.light ? Math.max(0, Math.min(1, (root.collapse - 0.35) / 0.4)) : Math.min(1, root.collapse * 2); anchors.fill: parent; cuts: [0, 0, 0, 0] }

        // On a few days a year a comet crosses the still, behind the title card: catch it with a click.
        Comet { anchors.fill: parent; opacity: Math.max(0, 1 - root.collapse * 2) }

        // The title card: the HUD line, the Japanese, the English under it.
        Column {
            id: hero
            x: Theme.margin(root.width)
            width: parent.width - x * (root.beside ? 1 : 2) - (tategaki.visible ? tategaki.width + Theme.s4 : sign.visible ? sign.width + (root.beside ? Theme.s3 * 2 : Theme.s5) : 0)
            // Beside the page, at the column's top; over it, in the middle of the band, sinking as the page scrolls.
            y: root.beside ? Theme.s4 : Math.max(Theme.s3, (band.height - height - (center.height > 0 ? center.height + Theme.s3 : 0)) / 2) - root.drift * 0.1
            opacity: Math.min(1, root.landed * 1.6) * Math.max(0, 1 - root.collapse * 1.6)
            transform: Translate { x: (1 - root.landed) * 32 }
            spacing: Theme.s1
            // A soft dark glow behind the words, so they read on a bright still (Terra's noon).
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.hud.dim || Theme.hud.ground; shadowOpacity: 1; shadowBlur: 1; shadowScale: 1.02; shadowVerticalOffset: 2; shadowHorizontalOffset: 0 }
            HudLabel {
                id: hudLine
                text: root.hud !== "" ? root.hud : [root.name !== "" ? root.name : root.w.name, Qt.formatDate(Worlds.now, "ddd d MMM"), Qt.formatTime(Worlds.now, "HH:mm")].join(" · ")
                jp: root.hudJp
                color: Theme.artAccent
                light: Theme.artAccent
                size: Theme.textS - 1
                // Beside the page the line runs the column's width, over the sign hung under it.
                room: root.beside ? band.width - hero.x - Theme.s3 - Theme.s5 : hero.width
            }
            // Neptune's splits its colours at the edges (the flavour's `chroma`).
            ChromaText {
                id: heroTitle
                width: parent.width
                text: root.jp !== "" ? root.jp : Theme.jpOf(root.world)
                elide: Text.ElideRight
                // Beside the page a title takes up to three lines of the column, as a poster's does.
                // (Beside, as large as its longest word allows on a line of the column.)
                readonly property int longest: text.split(/\s+/).reduce((m, w) => Math.max(m, w.length), 1)
                readonly property real size: root.beside ? Math.round(Math.max(28, Math.min(text.length > 16 ? 44 : 60, width / (longest * 0.68)))) : root.tight ? Math.min(76, Math.max(48, root.width / 12)) : Math.min(Theme.textHero * 0.85, Math.max(48, root.width / 10))
                font.family: Theme.titleFace(size); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(size); font.pixelSize: size
                // Broken between words only: the size keeps the longest word on its line.
                wrapMode: root.beside ? Text.WordWrap : Text.NoWrap
                maximumLineCount: root.beside ? 3 : 1
                lineHeight: root.beside ? 0.92 : 1
                // A long title (a song's, a station's) shrinks to its line before it is cut short.
                fontSizeMode: root.beside ? Text.FixedSize : Text.HorizontalFit; minimumPixelSize: 40
                color: Theme.artBright
            }
            Text {
                visible: text !== ""
                width: parent.width
                // The callout's "Walk = done" read as a sentence's parts: "Walk: done · Read: 20 min".
                text: root.callout.map(l => String(l).replace(/\s*=\s*/, ": ")).join(" · ")
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                // English, as written, in the display face: the subtitle under the Japanese.
                font.family: Theme.fontDisplay; font.pixelSize: Math.round(Theme.textLede * 0.8); font.weight: Font.Bold
                color: Theme.tint(Theme.artBright, 0.92)
            }
        }
        // Mercury's line, written down the right.
        Text {
            id: tategaki
            visible: root.vertical !== "" && !root.portrait && !sign.wanted
            x: band.width - (root.beside ? Theme.s3 : Theme.margin(root.width)) - width
            y: root.tight ? Theme.s3 : Theme.s4
            // Gone before the shrinking band reaches its foot, so it is never cut.
            opacity: Math.max(0, 1 - root.collapse * 3)
            // Written down: the punctuation and the long vowel take their upright forms (︑ ︒ ︱).
            text: root.vertical.split("").map(c => ({ "、": "\ufe11", "。": "\ufe12", "ー": "\ufe31" })[c] || c).join("\n")
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.05
            font.family: Theme.titleFace(root.tight ? 17 : 24); font.features: Theme.titleFeatures; font.pixelSize: root.tight ? 17 : 24; font.weight: Theme.titleWeight(root.tight ? 17 : 24)
            color: Theme.tint(Theme.hud.washi || Theme.artBright, 0.85)
        }

        // Neptune's is a lit sign down the right (the flavour's `signs`), as a shop's over the street.
        NeonSign {
            id: sign
            readonly property bool wanted: !!Theme.hud.signs
            visible: wanted && root.vertical !== "" && !root.portrait
            text: root.vertical
            size: root.tight ? 22 : 28
            room: root.beside ? Math.max(120, center.y - y - Theme.s4) : root.fullHeight - y - Theme.s3
            x: band.width - (root.beside ? Theme.s3 : Theme.margin(root.width)) - width
            y: root.beside ? hero.y + hudLine.height + Theme.s2 : root.tight ? Theme.s3 : Theme.s4
            opacity: Math.max(0, 1 - root.collapse * 3)
        }

        // What sits under the title card: the moons and the main action, then the figures
        // beside them (under them when the pane has no room for both on one line).
        Item {
            id: center
            x: hero.x
            y: root.beside ? Math.max(hero.y + hero.height + Theme.s4, band.height - height - Theme.s4) : hero.y + hero.height + Theme.s3
            opacity: root.landed * Math.max(0, 1 - root.collapse * 1.6)
            readonly property bool both: underBox.visible && figureRow.visible
            readonly property bool beside: !both || !root.beside && underBox.width + Theme.s6 + figureRow.implicitWidth <= root.width - Theme.margin(root.width) * 2
            width: Math.max(underBox.visible ? underBox.width : 0, figureRow.visible ? figureRow.x + figureRow.implicitWidth : 0)
            height: Math.max(underBox.visible ? underBox.height : 0, figureRow.visible ? figureRow.y + figureRow.implicitHeight : 0)

            Flow {
                id: figureRow
                visible: root.figures.length > 0
                // Beside the page, the column's width: the figures go two to a line, or one.
                width: root.beside ? band.width - hero.x - Theme.s3 : root.width
                // Clear of the moon links and the action, and each figure clear of the one before.
                x: center.both && center.beside ? underBox.width + Theme.s6 : 0
                y: center.both && !center.beside ? underBox.height + Theme.s3 : center.both ? (underBox.height - implicitHeight) / 2 : 0
                spacing: root.beside ? Theme.s4 : Theme.s5
                Repeater {
                    // Two on a narrow pane, where three would run off its edge. By count, so a figure
                    // that changes is the same one counting on, not a new one arriving.
                    model: Math.min(root.figures.length, root.portrait ? 2 : 3)
                    delegate: Settle {
                        id: fig
                        required property int index
                        readonly property var modelData: root.figures[index] || ({ value: "", label: "" })
                        place: 3 + index
                        width: figure.implicitWidth
                        height: figure.implicitHeight
                        HeroFigure { id: figure; value: fig.modelData.value; label: fig.modelData.label; jp: fig.modelData.jp || ""; lead: fig.index === 0; compact: root.tight || root.portrait }
                    }
                }
            }

            Settle {
                id: underBox
                wait: Theme.rise / 2
                width: underRow.implicitWidth
                height: underRow.implicitHeight
                // Moons, or anything else put under the name (the Repeater is a child too).
                visible: root.moons.length > 0 || underRow.children.length > moonRepeater.count + 1
                // In a row when they fit across the pane; else in lines, each centred under the
                // name, and none wider than the pane (a long one is held to it and elides).
                Item {
                    id: underRow
                    readonly property real spacing: Theme.s4
                    readonly property real room: Math.max(80, root.beside ? band.width - hero.x - Theme.s3 : root.width - Theme.margin(root.width) * 2)
                    // For a Button among them: this row's own width follows theirs.
                    readonly property real childRoom: room
                    onRoomChanged: place()
                    onChildrenChanged: watch()
                    Component.onCompleted: watch()
                    Repeater { id: moonRepeater; model: root.moons; delegate: MoonLink { required property var modelData; text: modelData.label; jp: modelData.id ? Theme.jpOf(modelData.id) : ""; hint: modelData.hint || ""; onClicked: modelData.open() } }

                    property var watched: []
                    function watch() {
                        const now = []
                        for (const c of children) {
                            if (c === moonRepeater) continue
                            now.push(c)
                            if (watched.indexOf(c) >= 0) continue
                            c.implicitWidthChanged.connect(underRow.place)
                            c.heightChanged.connect(underRow.place)
                            c.visibleChanged.connect(underRow.place)
                        }
                        watched = now
                        place()
                    }
                    function place() {
                        // A child can still call while the sheet is being torn down.
                        if (!Array.isArray(watched)) return
                        const lines = [[]]
                        let x = 0
                        for (const c of watched) {
                            // A moon link the Repeater has let go of (a reload) is no longer ours.
                            if (!c || c.parent !== underRow || !c.visible) continue
                            c.width = Math.min(c.implicitWidth, room)
                            const line = lines[lines.length - 1]
                            if (line.length && x + c.width > room + 0.5) { lines.push([c]); x = c.width + spacing }
                            else { line.push(c); x += c.width + spacing }
                        }
                        const widthOf = line => line.reduce((w, c) => w + c.width, 0) + Math.max(0, line.length - 1) * spacing
                        const wide = Math.max(0, ...lines.map(widthOf))
                        let y = 0
                        for (const line of lines) {
                            if (!line.length) continue
                            const h = Math.max(...line.map(c => c.height))
                            let cx = (wide - widthOf(line)) / 2
                            for (const c of line) { c.x = cx; c.y = y + (h - c.height) / 2; cx += c.width + spacing }
                            y += h + Theme.s1
                        }
                        implicitWidth = wide
                        implicitHeight = Math.max(0, y - Theme.s1)
                    }
                }
            }
        }

        // Tonight's real sky, where the world follows it (a full moon in Luna,
        // Saturn's opposition in Saturn): a quiet line at the bottom right.
        Settle {
            id: tonight
            wait: Theme.rise / 2
            visible: tonight.events.length > 0 && root.collapse < 0.3
            readonly property real edge: Theme.margin(root.width)
            x: root.beside ? hero.x : band.width - width - edge
            y: root.beside ? center.y - height - Theme.s3 : band.height - height - Theme.s3
            width: root.portrait || root.beside ? band.width - edge * 2 : 300
            height: tonightColumn.implicitHeight
            property var asked: []
            readonly property AppWindow win: root.Window.window as AppWindow
            readonly property var staged: ({
                "full-moon": { title: "Full moon tonight", line: "The Hunter’s Moon is up all night." },
                "perseids": { title: "The Perseids tonight", line: "Up to a hundred shooting stars an hour after midnight. Stay up a little?" },
                "opposition": { title: "Saturn at its brightest", line: "Closest to us this year and up all night: look south-east after dark." } })
            readonly property var events: win && win.stagedSky !== "" && staged[win.stagedSky] ? [staged[win.stagedSky]] : asked
            Component.onCompleted: Sol.near(root).call("sky_tonight").then(e => tonight.asked = e || []).catch(why => console.warn("tonight’s sky couldn’t be asked for", why))
            Column {
                id: tonightColumn
                width: parent.width
                spacing: Theme.s1
                Repeater {
                    model: tonight.events
                    delegate: Column {
                        id: ev
                        required property var modelData
                        width: tonightColumn.width
                        spacing: 2
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: ev.modelData.title
                            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                            font.letterSpacing: Theme.track(Theme.trackLabel, Theme.textXs); font.capitalization: Font.AllUppercase
                            color: Theme.artAccent
                            elide: Text.ElideLeft
                        }
                        Text {
                            width: Math.min(implicitWidth, ev.width)
                            x: ev.width - width
                            horizontalAlignment: Text.AlignRight
                            text: ev.modelData.line
                            wrapMode: Text.WordWrap
                            font.family: Theme.font; font.pixelSize: Theme.textXs + 1
                            color: Theme.artQuiet
                        }
                    }
                }
            }
        }

        Rectangle { visible: !root.beside; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.collapse > 0.5 ? Theme.line : Theme.artLine }
    }
}

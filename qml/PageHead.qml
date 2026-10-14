import QtQuick

/*
    The top of a working page: a band of glass that stays put while the
    page scrolls under it. The title's Japanese (`jp`, or its section's) in
    the title serif, beside a HUD line (the section's number and the
    eyebrow) over the English; a quiet line beside them, and the page's
    actions on the right. Neptune's flickers in as it comes. On a page opened from another,
    the way back comes first. Put it in a Screen's `header`.

    With a flavour's `outline` the section's number stands first, large, in
    outline figures of the light, and the English title in outline capitals
    under a caption (`captions`: "neptune_music / albums"); both draw
    themselves on as the page lands.

    A page's one lead object (an album's cover and name, a station's dial)
    goes in `feature`: it stands on the still under the band, and as the
    page scrolls it folds away under the band, which stays. A feature with
    a `reveal(dir, wait)` of its own is told as the page lands.

    With `tabs`, the tabs run along its foot. A tab is part of the page's
    path (`/schedule?tab=calendar`): choosing one changes the page's
    `params` in place (`Shell.retab`, no new step in the history), so Back,
    links and the palette reach it; the page reads `tab` (or `params.tab`).

        Screen { header: PageHead { title: "Settings"; lead: "…"; Button { text: "Export" } } … }
        Screen { header: PageHead { title: "Harbour Lights"; feature: AlbumLead { … } } … }
        Screen { id: page; header: PageHead { title: "Schedule"; tabs: [{ id: "calendar", label: "Calendar" }, { id: "timeline", label: "Timeline" }]; tab: page.params.tab || "" } … }
*/
Item {
    id: root

    property string title: ""
    /**
        The title itself in the title face, large, as written: a detail
        page's name (a series, an album, an artist), so the page is carried
        by its type. Off, the title is the HUD line's English subtitle.
    */
    property bool named: false
    /** A `feature` under the band carries the name large already (an album's): the band takes it only as the feature folds away. False when the feature is something else (a month's figures), so the band has the name from the start. */
    property bool featureNamed: true
    /** The size a `named` title is set at: over every title face's floor (`Theme.titleFloors`). */
    readonly property int namedSize: 30
    /** The title in Japanese: "書庫". Its section's `jp` when not given. */
    property string jp: ""
    /** A quiet label before the title, e.g. the world it belongs to. */
    property string eyebrow: ""
    property string lead: ""
    default property alias actions: actionRow.data
    /** The Screen this heads; set by Screen. */
    property var screen: null
    /** The title can be changed in place: click it and type; `renamed` carries the new one. */
    property bool editable: false
    signal renamed(string title)
    /** Tabs along its foot, `{ id, label, count?, hint? }`; none by default. */
    property var tabs: []
    /** The page's one lead object, under the band, on the still: it folds away as the page scrolls. */
    property alias feature: featureSlot.data
    /** 0 with the feature shown, 1 folded under the band; the Screen drives it while there is a feature. */
    property real collapse: 0
    /** With a feature, the Screen pins the head: the page scrolls under it as the feature folds away. */
    readonly property bool pins: featureSlot.children.length > 0
    onPinsChanged: if (pins && screen) screen.pin(root)
    /** The feature between a film's black bars (the flavour's `letterbox`, Saturn's). */
    property bool letterbox: pins && !!Theme.hud.letterbox
    /** The band alone (the words, the actions and the tabs). */
    readonly property real barHeight: topHeight + (tabs.length ? tabStrip.height - Theme.s2 : 0)
    readonly property real featureHeight: pins ? featureSlot.childrenRect.height + Theme.s4 * 2 : 0
    readonly property real fullHeight: barHeight + featureHeight
    /** How tall it is folded: the band. */
    readonly property real compact: barHeight
    /** The tab that is on, by id ("" for the first): bind it to the page's `params.tab`. */
    property string tab: ""
    /** The tab that shows: `tab`, or the first. */
    readonly property string current: tab !== "" ? tab : tabs.length ? String(tabs[0].id) : ""
    /** A tab was chosen (the page's path has it already, through the Shell). */
    signal tabChosen(string id)
    /** Shows tab `id`: in the page's path when it is in a Shell, else here. */
    function choose(id) {
        if (id === current) return
        const sh = screen ? screen.shell : null
        if (sh && sh.page === screen && typeof sh.retab === "function") sh.retab(Object.assign({}, screen.params, { tab: id }))
        else tab = id
        tabChosen(id)
    }

    readonly property var back: screen && screen.back ? screen.back : null
    /** The sidebar row this page is at (a page opened from another: none), for its number and Japanese. */
    readonly property var row: {
        const sh = screen ? screen.shell : null
        if (!sh) return null
        const e = sh.history.find(h => h.item === screen)
        return e ? sh.rows.find(r => r.path === e.path) || null : null
    }
    readonly property string jpTitle: jp !== "" ? jp : row && row.jp ? row.jp : ""
    /** The section's number, two figures: "02" ("" on a page opened from another). */
    readonly property string number: row ? (row.top + 1 < 10 ? "0" : "") + (row.top + 1) : ""
    /** The world it is in: a moon's own. */
    readonly property string worldId: screen && screen.world !== "" ? screen.world : Sol.world
    /** The HUD line: the section's number and the eyebrow (or the world's name); a flavour's caption: its tag, then the eyebrow or the title. */
    readonly property string hudLine: Theme.captions ? Theme.caption(eyebrow !== "" ? eyebrow : row ? row.label : title, Theme.tagOf(worldId))
        : [number, eyebrow !== "" ? eyebrow : Worlds.get(worldId).name].filter(Boolean).join(" · ")
    /** The English title in outline capitals: the flavour has them, it isn't a name set in the title face, and no feature carries a big title of its own (one outline title a page). */
    readonly property bool outlineTitle: Theme.outlined(title) && !named && !editable && !pins
    /** The size the number is set at: its figures as tall as the band's words allow. */
    readonly property int numberSize: Math.round(Math.min(88, (railHead - Theme.s2 * 2) / 0.7))
    /** Where the page's content starts, so the words line up with it (the Screen's column). */
    readonly property bool lined: !!screen && screen.padded && !screen.composed
    readonly property real margin: lined ? screen.contentX : Theme.margin(width)

    readonly property real room: lined ? screen.contentWidth : width - margin * 2
    /** The actions side by side, as wide as they would like (a Button's own width, not the one its row allows it). */
    readonly property real actionsWidth: {
        let w = 0, n = 0
        for (const c of actionRow.children) {
            if (!c.visible) continue
            w += c.hasOwnProperty("natural") ? c.natural : c.implicitWidth
            n++
        }
        return w + Math.max(0, n - 1) * actionRow.spacing
    }
    readonly property bool hasActions: actionsWidth > 0
    /** The words on one line as they would like it: the way back, the title and the lead. */
    readonly property real wordsWidth: {
        const parts = [back ? backButton.implicitWidth : 0,
                       titleEdit.visible ? titleEdit.implicitWidth + hudTitle.implicitWidth + textRow.spacing : hudTitle.implicitWidth, lead !== "" ? leadText.implicitWidth : 0].filter(w => w > 0)
        return parts.reduce((a, w) => a + w, 0) + Math.max(0, parts.length - 1) * textRow.spacing
    }
    /** Too narrow for the words and the actions side by side (the words want their line, or 240 px of
        one): the actions go on lines of their own under the title and the lead, which get the full width. */
    readonly property bool stacked: hasActions && room - actionsWidth - Theme.s4 < Math.min(wordsWidth, 240)

    /** The rail's head beside it (`Shell.headHeight`): the words' part of the band is as tall, so its foot is level with the brand's. */
    readonly property real railHead: screen && screen.shell && screen.shell.headHeight ? screen.shell.headHeight : Theme.navHeight
    /** The words and the actions, above the tabs: the rail's head, or more when they need it. */
    readonly property real topHeight: stacked ? Math.max(railHead, textRow.implicitHeight + actionRow.height + Theme.s2 * 3)
                                              : Math.max(railHead, Math.max(textRow.implicitHeight, actionRow.height) + Theme.s2 * 2)
    // The tabs take the words' bottom padding, so their line sits on the bar's hairline.
    implicitHeight: fullHeight
    height: pins ? Math.round(fullHeight - (fullHeight - compact) * collapse) : implicitHeight

    /** The title and the actions settle in with their page (its Screen calls this as the page
        shows); the bar itself stays, so nothing flashes behind it. */
    function reveal(dir) {
        headIn.stop()
        glitch.stop()
        textRow.opacity = 0
        actionRow.opacity = 0
        tabStrip.opacity = 0
        // The words land as the page's turn reveals it (its hold over), the way it runs (back:
        // from the other side); the opening's land at once; a tab's page only fades in, in place.
        plain = dir === "tab"
        wait = screen && typeof screen.landWait === "function" ? screen.landWait(dir) : 0
        const by = Theme.calm || plain ? 0 : Theme.hud.motif === "shrine" ? 12 : 36
        textShift.x = dir === "back" ? -by : by
        actionShift.x = dir === "back" ? -by / 2 : by / 2
        // The title lands a touch large and settles to its size: a small slam.
        jpBox.scale = Theme.calm || plain ? 1 : 1.08
        headIn.start()
        if (plain) still()
        else if (Theme.hud.motif === "neon" && !Theme.calm) glitch.restart()
        // The number and the outline title trace themselves in as the words land, and the feature
        // is told (an outline name of its own draws on with them).
        if (!plain) {
            if (numberText.visible) numberText.drawOn(wait)
            if (outlined.visible) outlined.drawOn(wait + Theme.hit)
        }
        for (const f of featureSlot.children) if (typeof f.reveal === "function") f.reveal(dir, wait)
    }
    /** How long the words wait under the page's turn before they land. */
    property real wait: 0
    /** Arriving as a tab does: a plain fade. */
    property bool plain: false
    // Neptune's flicker stopped where it was, the words back in place.
    function still() {
        glitch.stop()
        ghostRed.opacity = 0; ghostCyan.opacity = 0
        ghostRed.x = 0; ghostCyan.x = 0; jpText.x = 0
    }
    Settling { when: headIn.running || glitch.running }
    SequentialAnimation {
        id: headIn
        PauseAnimation { duration: root.wait }
        ParallelAnimation {
            NumberAnimation { target: textRow; property: "opacity"; to: 1; duration: root.plain || Theme.calm ? Theme.fade : Theme.hit; easing: Theme.easeOut }
            NumberAnimation { target: actionRow; property: "opacity"; to: 1; duration: root.plain || Theme.calm ? Theme.fade : Theme.land; easing: Theme.easeOut }
            NumberAnimation { target: tabStrip; property: "opacity"; to: 1; duration: root.plain || Theme.calm ? Theme.fade : Theme.land; easing: Theme.easeOut }
            NumberAnimation { target: textShift; property: "x"; to: 0; duration: Theme.land; easing: Theme.easeOut }
            NumberAnimation { target: actionShift; property: "x"; to: 0; duration: Theme.land; easing: Theme.easeOut }
            NumberAnimation { target: jpBox; property: "scale"; to: 1; duration: Theme.land; easing: Theme.spring }
        }
    }

    // Neptune's flicker as the title lands: two flickers of a red and a cyan ghost, then still,
    // inside the turn's landing.
    SequentialAnimation {
        id: glitch
        PauseAnimation { duration: root.wait }
        ScriptAction { script: { ghostRed.opacity = 0.8; ghostCyan.opacity = 0.8; ghostRed.x = 4; ghostCyan.x = -4; jpText.x = -1 } }
        PauseAnimation { duration: Theme.flicker }
        ScriptAction { script: { ghostRed.x = -2; ghostCyan.x = 2; jpText.x = 1 } }
        PauseAnimation { duration: Theme.flicker }
        ScriptAction { script: { ghostRed.opacity = 0; ghostCyan.opacity = 0; ghostRed.x = 0; ghostCyan.x = 0; jpText.x = 0 } }
    }

    // The feature, on the still under the band: it folds away under the band as the page scrolls.
    Item {
        id: featureClip
        y: root.barHeight
        width: root.width
        height: Math.max(0, root.height - root.barHeight)
        clip: true
        visible: root.pins && height > 0
        Item {
            id: featureSlot
            x: root.margin
            y: Theme.s4 - root.collapse * Theme.s4
            width: root.room
            height: childrenRect.height
            opacity: Math.max(0, 1 - root.collapse * 1.4)
            onChildrenChanged: { for (const c of children) if (!c.width) c.width = Qt.binding(() => featureSlot.width) }
        }
        // A film's bars over and under it (the flavour's `letterbox`: Saturn's), so the still
        // between reads as a frame of the film; the foot's folds up with it.
        Rectangle { visible: root.letterbox; width: parent.width; height: Theme.s2; color: Theme.tint(Theme.hud.ground, 0.92) }
        Rectangle { visible: root.letterbox; width: parent.width; height: Theme.s2; y: Math.max(height, parent.height - height); color: Theme.tint(Theme.hud.ground, 0.92) }
    }

    Item {
        id: bar
        width: root.width
        height: root.barHeight
        HudGlass { anchors.fill: parent; cuts: [0, 0, 0, 0] }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
    }
    // What slides under the bar dims out over a few pixels first; nothing has, nothing dims.
    readonly property real scrolled: screen && screen.contentY > featureHeight ? Math.min(1, (screen.contentY - featureHeight) / 32) : 0
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: bar.bottom
        height: 14
        opacity: root.scrolled
        gradient: Gradient { GradientStop { position: 0; color: Theme.tint(Theme.deep, 0.8) } GradientStop { position: 1; color: Theme.tint(Theme.deep, 0) } }
    }

    Flow {
        id: textRow
        x: root.margin
        y: root.stacked ? Theme.s2 : (root.topHeight - height) / 2
        width: root.stacked || !root.hasActions ? root.room : root.room - root.actionsWidth - Theme.s4
        spacing: Theme.s3
        transform: Translate { id: textShift }

        // The way back and the lead stand as tall as the title beside them, their words on its centre line.
        Back { id: backButton; visible: !!root.back; height: Math.max(implicitHeight, hudTitle.height); label: root.back ? root.back.label : ""; onGo: root.back.go() }
        // The title: the Japanese in the title serif, then the HUD line over the English
        // (a title that can be renamed follows, as it is).
        Row {
            id: hudTitle
            spacing: Theme.s3
            height: Math.max(32, implicitHeight)
            // The section's number, large, in outline figures of the light (the flavour's `outline`).
            OutlineText {
                id: numberText
                visible: Theme.outlines && root.number !== "" && !(root.screen && root.screen.composed)
                anchors.verticalCenter: parent.verticalCenter
                text: root.number
                size: root.numberSize
                color: Theme.hudAccent
                drawFor: Theme.fade
            }
            Item {
                id: jpBox
                // A page composed to the still sets its title large over it instead.
                visible: root.jpTitle !== "" && !(root.screen && root.screen.composed)
                anchors.verticalCenter: parent.verticalCenter
                transformOrigin: Item.Left
                width: jpText.implicitWidth
                height: jpText.implicitHeight
                // Neptune's title flickers in: two ghosts of it, red and cyan, jump and fade.
                Text { id: ghostRed; text: jpText.text; font: jpText.font; color: Theme.hudAccent; opacity: 0 }
                Text { id: ghostCyan; text: jpText.text; font: jpText.font; color: Theme.hudSecond; opacity: 0 }
                Text {
                    id: jpText
                    text: root.jpTitle
                    font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle; font.pixelSize: 26
                    color: Theme.hudText
                }
            }
            Rectangle { visible: jpBox.visible; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 26; color: Theme.lineMid }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: root.hudLine
                    font.family: Theme.fontCaps; font.pixelSize: Theme.captions ? Theme.textXs + 1 : Theme.textXs; font.weight: Theme.captions ? Font.Medium : Font.DemiBold
                    font.letterSpacing: Theme.track(Theme.captions ? 0.04 : Theme.trackHud, Theme.textXs); font.capitalization: Theme.captions ? Font.MixedCase : Font.AllUppercase
                    color: Theme.hudAccentText
                }
                // The subtitle, in the display face: a few words in capitals; a longer title, or Japanese, as written.
                // A `named` page's title is its name, in the title face, large; while a feature under the band
                // carries the name large already, the band keeps the subtitle and the name takes its place as the
                // feature folds away.
                // With captions, a title that can be renamed stands under the caption, as any title does.
                Editable { visible: root.editable && Theme.captions; text: root.title; width: Math.min(implicitWidth, textRow.width - (jpBox.visible ? jpBox.width + Theme.s3 * 2 + 1 : 0)); size: Theme.textM; weight: Theme.weightName; caps: true; color: Theme.text; height: 24; hint: "Click to rename"; onCommitted: t => root.renamed(t) }
                Item {
                    id: titleBox
                    visible: !root.editable
                    // Beside the Japanese, and the section's number when it is drawn large.
                    readonly property real room: textRow.width - (jpBox.visible ? jpBox.width + Theme.s3 * 2 + 1 : 0) - (numberText.visible ? numberText.width + Theme.s3 : 0)
                    /** 1 where the name stands in the title face, 0 where the subtitle does. */
                    readonly property real named: !root.named ? 0 : root.pins && root.featureNamed ? Math.max(0, Math.min(1, (root.collapse - 0.45) / 0.4)) : 1
                    width: Math.min(Math.max(subtitle.visible ? subtitle.implicitWidth : 0, nameText.visible ? nameText.implicitWidth : 0, outlined.visible ? outlined.implicitWidth : 0), room)
                    height: root.named ? nameText.implicitHeight : root.outlineTitle ? outlined.implicitHeight + 3 : subtitle.implicitHeight
                    // In outline capitals (the flavour's `outline`), as large as the band allows.
                    OutlineText {
                        id: outlined
                        visible: root.outlineTitle
                        y: 3
                        text: root.title
                        room: titleBox.room
                        size: 40
                        minSize: 26
                        color: Theme.hudText
                        drawFor: Theme.fade
                    }
                    Text {
                        id: subtitle
                        visible: titleBox.named < 1 && !root.outlineTitle
                        opacity: 1 - titleBox.named
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        width: Math.min(implicitWidth, titleBox.room)
                        elide: Text.ElideRight
                        readonly property bool caps: Theme.capsFor(root.title)
                        readonly property int size: caps ? Theme.textS : Theme.textM
                        font.family: Theme.fontDisplay; font.pixelSize: size; font.weight: Font.Bold
                        font.letterSpacing: caps ? Theme.track(Theme.trackHud, Theme.textS) : 0; font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
                        color: Theme.hudText
                    }
                    Text {
                        id: nameText
                        visible: root.named && titleBox.named > 0
                        opacity: titleBox.named
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        width: Math.min(implicitWidth, titleBox.room)
                        elide: Text.ElideRight
                        font.family: Theme.titleFace(root.namedSize); font.pixelSize: root.namedSize
                        font.weight: Theme.titleWeight(root.namedSize); font.features: Theme.titleFeatures
                        color: Theme.hudText
                    }
                }
            }
        }
        Editable { id: titleEdit; visible: root.editable && !Theme.captions; text: root.title; width: Math.min(implicitWidth, textRow.width); size: Theme.textM; weight: Theme.weightName; caps: true; color: Theme.text; height: 32; hint: "Click to rename"; onCommitted: t => root.renamed(t) }
        // The lead: beside the title, in two lines where one doesn't fit, so the band stays as tall as the
        // rail's head; on its own line only when there are not 200 px beside the title.
        Text {
            id: leadText
            visible: root.lead !== ""
            text: root.lead
            readonly property real beside: textRow.width - [backButton, hudTitle, titleEdit].filter(i => i.visible).reduce((w, i) => w + i.width + textRow.spacing, 0)
            width: Math.min(implicitWidth, beside >= 200 ? beside : textRow.width)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            // Beside the title, as tall as it; on a line of its own, its own height, drawn up into the
            // row's gap, so the band stays as tall as the rail's head.
            readonly property bool own: y > hudTitle.y + 1
            topPadding: own ? -Theme.s3 : 0
            height: !own ? Math.max(32, hudTitle.height, implicitHeight) : implicitHeight
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
            color: Theme.textQuiet
            onTextChanged: fade.restart()
            NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
        }
    }

    // The page's actions: on the right, or on lines of their own under the title when narrow.
    // Laid out here rather than by a Row or a Flow: they sit in a row as a Row would put them
    // (an action may centre itself with `anchors.verticalCenter`), and wrap when there is no room.
    Item {
        id: actionRow
        readonly property real spacing: Theme.s2
        x: root.stacked ? root.margin : root.width - root.margin - width
        y: root.stacked ? textRow.y + textRow.height + Theme.s2 : (root.topHeight - height) / 2
        width: root.stacked ? root.room : root.actionsWidth
        height: 0
        transform: Translate { id: actionShift }
        onWidthChanged: place()
        onChildrenChanged: watch()
        Component.onCompleted: watch()

        property var watched: []
        function watch() {
            const now = []
            for (const c of children) {
                if (Theme.isRepeater(c)) continue
                now.push(c)
                if (watched.indexOf(c) >= 0) continue
                c.widthChanged.connect(actionRow.place)
                c.heightChanged.connect(actionRow.place)
                c.visibleChanged.connect(actionRow.place)
            }
            watched = now
            place()
        }
        function place() {
            let x = 0, top = 0, line = [], lineH = 0
            const end = () => {
                for (const c of line) c.y = top + (lineH - c.height) / 2
                top += lineH
                line = []; lineH = 0
            }
            for (const c of watched) {
                if (!c || !c.visible) continue
                if (line.length && x + c.width > width + 0.5) { end(); top += spacing; x = 0 }
                c.x = x
                x += c.width + spacing
                line.push(c)
                lineH = Math.max(lineH, c.height)
            }
            if (line.length) end()
            height = top
        }
    }

    // The tabs along the foot, the one that is on drawn over the bar's hairline.
    Tabs {
        id: tabStrip
        visible: root.tabs.length > 0
        x: root.margin
        y: root.barHeight - height
        width: Math.min(implicitWidth, root.room)
        options: root.tabs
        value: root.current
        ground: Theme.deep
        onChosen: v => root.choose(v)
    }
}

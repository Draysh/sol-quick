import QtQuick

/*
    The top of a working page: a slim toolbar that stays put while the
    page scrolls under it. The title in the name style, a quiet line beside
    it, and the page's actions on the right. On a page opened from another,
    the way back comes first. Put it in a Screen's `header`.

    With `tabs`, the tabs run along its foot. A tab is part of the page's
    path (`/schedule?tab=calendar`): choosing one changes the page's
    `params` in place (`Shell.retab`, no new step in the history), so Back,
    links and the palette reach it; the page reads `tab` (or `params.tab`).

    In the Yozora look it is a band of glass: the title's Japanese (`jp`,
    or its section's) in the title serif, beside a HUD line (the section's
    number and the eyebrow) over the English in the mono face; Neptune's
    flickers in as it comes.

        Screen { header: PageHead { title: "Settings"; lead: "…"; Button { text: "Export" } } … }
        Screen { id: page; header: PageHead { title: "Schedule"; tabs: [{ id: "calendar", label: "Calendar" }, { id: "timeline", label: "Timeline" }]; tab: page.params.tab || "" } … }
*/
Item {
    id: root

    property string title: ""
    /** The title in Japanese, for the Yozora look: "書庫". Its section's `jp` when not given. */
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
    /** The sidebar row this page is at (a page opened from another: none), for the look's number and Japanese. */
    readonly property var row: {
        const sh = screen ? screen.shell : null
        if (!sh || !Theme.yozora) return null
        const e = sh.history.find(h => h.item === screen)
        return e ? sh.rows.find(r => r.path === e.path) || null : null
    }
    readonly property string jpTitle: jp !== "" ? jp : row && row.jp ? row.jp : ""
    /** The look's HUD line: the section's number and the eyebrow (or the world's name). */
    readonly property string hudLine: [row ? (row.top + 1 < 10 ? "0" : "") + (row.top + 1) : "", eyebrow !== "" ? eyebrow : Worlds.get(screen && screen.world !== "" ? screen.world : Sol.world).name].filter(Boolean).join(" · ")
    readonly property real margin: Theme.margin(width)

    readonly property real room: width - margin * 2
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
    /** The words on one line as they would like it: the way back, the eyebrow, the title and the lead. */
    readonly property real wordsWidth: {
        const parts = [back ? backButton.implicitWidth : 0, eyebrow !== "" ? eyebrowText.implicitWidth : 0,
                       editable ? titleEdit.implicitWidth + (Theme.yozora ? hudTitle.implicitWidth + textRow.spacing : 0) : Theme.yozora ? hudTitle.implicitWidth : titleText.implicitWidth, lead !== "" ? leadText.implicitWidth : 0].filter(w => w > 0)
        return parts.reduce((a, w) => a + w, 0) + Math.max(0, parts.length - 1) * textRow.spacing
    }
    /** Too narrow for the words and the actions side by side (the words want their line, or 240 px of
        one): the actions go on lines of their own under the title and the lead, which get the full width. */
    readonly property bool stacked: hasActions && room - actionsWidth - Theme.s4 < Math.min(wordsWidth, 240)

    /** The words and the actions, above the tabs. */
    readonly property real topHeight: stacked ? textRow.implicitHeight + actionRow.height + Theme.s2 * 3
                                              : Math.max(Theme.navHeight, Math.max(textRow.implicitHeight, actionRow.height) + Theme.s2 * 2)
    // The tabs take the words' bottom padding, so their line sits on the bar's hairline.
    implicitHeight: topHeight + (tabs.length ? tabStrip.height - Theme.s2 : 0)

    /** The title and the actions settle in with their page (its Screen calls this as the page
        shows); the bar itself stays, so nothing flashes behind it. */
    function reveal(dir) {
        headIn.stop()
        textRow.opacity = 0
        actionRow.opacity = 0
        tabStrip.opacity = 0
        textShift.x = dir === "in" ? 16 : dir === "back" ? -10 : 0
        headIn.start()
        if (Theme.yozora && Theme.hud.motif === "neon" && !Theme.calm) glitch.restart()
    }
    Settling { when: headIn.running || glitch.running }
    ParallelAnimation {
        id: headIn
        NumberAnimation { target: textRow; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: actionRow; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: tabStrip; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: textShift; property: "x"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    // Neptune's flicker as the page comes: a quarter of a second, then still.
    SequentialAnimation {
        id: glitch
        ScriptAction { script: { ghostRed.opacity = 0.8; ghostCyan.opacity = 0.8; ghostRed.x = 4; ghostCyan.x = -4; jpText.x = -1 } }
        PauseAnimation { duration: 60 }
        ScriptAction { script: { ghostRed.x = -3; ghostCyan.x = 3; jpText.x = 2 } }
        PauseAnimation { duration: 50 }
        ScriptAction { script: { ghostRed.x = 2; ghostCyan.x = -1; jpText.x = 0 } }
        PauseAnimation { duration: 40 }
        ParallelAnimation {
            NumberAnimation { target: ghostRed; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: ghostCyan; property: "opacity"; to: 0; duration: 140 }
        }
    }

    Rectangle { visible: !Theme.yozora; anchors.fill: parent; color: Theme.deep }
    HudGlass { visible: Theme.yozora; anchors.fill: parent; cuts: [0, 0, 0, 0] }
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
    // What slides under the bar dims out over a few pixels first; nothing has, nothing dims.
    readonly property real scrolled: screen && screen.contentY > 0 ? Math.min(1, screen.contentY / 32) : 0
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.bottom
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

        Back { id: backButton; visible: !!root.back; label: root.back ? root.back.label : ""; onGo: root.back.go() }
        Quiet { id: eyebrowText; visible: root.eyebrow !== "" && !Theme.yozora; text: root.eyebrow; width: Math.min(implicitWidth, textRow.width); height: 32; verticalAlignment: Text.AlignVCenter }
        Heading { id: titleText; visible: !root.editable && !Theme.yozora; level: 3; text: root.title; width: Math.min(implicitWidth, textRow.width); height: 32; verticalAlignment: Text.AlignVCenter }
        // The Yozora look's title: the Japanese in the title serif, then the HUD line over the English
        // (a title that can be renamed follows, as it is).
        Row {
            id: hudTitle
            visible: Theme.yozora
            spacing: Theme.s3
            height: Math.max(32, implicitHeight)
            Item {
                id: jpBox
                visible: root.jpTitle !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: jpText.implicitWidth
                height: jpText.implicitHeight
                // Neptune's title flickers in: two ghosts of it, red and cyan, jump and fade.
                Text { id: ghostRed; text: jpText.text; font: jpText.font; color: Theme.hudAccent; opacity: 0 }
                Text { id: ghostCyan; text: jpText.text; font: jpText.font; color: Theme.hudSecond; opacity: 0 }
                Text {
                    id: jpText
                    text: root.jpTitle
                    font.family: Theme.fontTitle; font.weight: Font.Black; font.pixelSize: 26
                    color: Theme.hudText
                }
            }
            Rectangle { visible: jpBox.visible; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 26; color: Theme.lineMid }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: root.hudLine
                    font.family: Theme.fontMono; font.pixelSize: Theme.textXs - 1; font.weight: Font.DemiBold
                    font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
                    color: Theme.hudAccent
                }
                Text {
                    visible: !root.editable
                    text: root.title
                    width: Math.min(implicitWidth, textRow.width - (jpBox.visible ? jpBox.width + Theme.s3 * 2 + 1 : 0))
                    elide: Text.ElideRight
                    font.family: Theme.fontMono; font.pixelSize: Theme.textS; font.weight: Font.Bold
                    font.letterSpacing: Theme.track(0.14, Theme.textS); font.capitalization: Font.AllUppercase
                    color: Theme.hudText
                }
            }
        }
        Editable { id: titleEdit; visible: root.editable; text: root.title; width: Math.min(implicitWidth, textRow.width); size: Theme.textM; weight: Theme.weightName; caps: true; color: Theme.text; height: 32; hint: "Click to rename"; onCommitted: t => root.renamed(t) }
        // The lead: beside the title when it fits, else on its own line, wrapping (at most two lines).
        Text {
            id: leadText
            visible: root.lead !== ""
            text: root.lead
            width: Math.min(implicitWidth, textRow.width)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            height: Math.max(32, implicitHeight); verticalAlignment: Text.AlignVCenter
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
        y: root.implicitHeight - height
        width: Math.min(implicitWidth, root.room)
        options: root.tabs
        value: root.current
        ground: Theme.deep
        onChosen: v => root.choose(v)
    }
}

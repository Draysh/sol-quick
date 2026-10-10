import QtQuick

/*
    The top of a working page: a slim toolbar that stays put while the
    page scrolls under it. The title in the name style, a quiet line beside
    it, and the page's actions on the right. On a page opened from another,
    the way back comes first. Put it in a Screen's `header`.

        Screen { header: PageHead { title: "Settings"; lead: "…"; Button { text: "Export" } } … }
*/
Item {
    id: root

    property string title: ""
    /** A quiet label before the title, e.g. the world it belongs to. */
    property string eyebrow: ""
    property string lead: ""
    default property alias actions: actionRow.data
    /** The Screen this heads; set by Screen. */
    property var screen: null
    /** The title can be changed in place: click it and type; `renamed` carries the new one. */
    property bool editable: false
    signal renamed(string title)

    readonly property var back: screen && screen.back ? screen.back : null
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
                       editable ? titleEdit.implicitWidth : titleText.implicitWidth, lead !== "" ? leadText.implicitWidth : 0].filter(w => w > 0)
        return parts.reduce((a, w) => a + w, 0) + Math.max(0, parts.length - 1) * textRow.spacing
    }
    /** Too narrow for the words and the actions side by side (the words want their line, or 240 px of
        one): the actions go on lines of their own under the title and the lead, which get the full width. */
    readonly property bool stacked: hasActions && room - actionsWidth - Theme.s4 < Math.min(wordsWidth, 240)

    implicitHeight: stacked ? textRow.implicitHeight + actionRow.height + Theme.s2 * 3
                            : Math.max(Theme.navHeight, Math.max(textRow.implicitHeight, actionRow.height) + Theme.s2 * 2)

    /** The title and the actions settle in with their page (its Screen calls this as the page
        shows); the bar itself stays, so nothing flashes behind it. */
    function reveal(dir) {
        headIn.stop()
        textRow.opacity = 0
        actionRow.opacity = 0
        textShift.x = dir === "in" ? 16 : dir === "back" ? -10 : 0
        headIn.start()
    }
    ParallelAnimation {
        id: headIn
        NumberAnimation { target: textRow; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: actionRow; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: textShift; property: "x"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    Rectangle { anchors.fill: parent; color: Theme.deep }
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
        y: root.stacked ? Theme.s2 : (root.height - height) / 2
        width: root.stacked || !root.hasActions ? root.room : root.room - root.actionsWidth - Theme.s4
        spacing: Theme.s3
        transform: Translate { id: textShift }

        Back { id: backButton; visible: !!root.back; label: root.back ? root.back.label : ""; onGo: root.back.go() }
        Quiet { id: eyebrowText; visible: root.eyebrow !== ""; text: root.eyebrow; width: Math.min(implicitWidth, textRow.width); height: 32; verticalAlignment: Text.AlignVCenter }
        Heading { id: titleText; visible: !root.editable; level: 3; text: root.title; width: Math.min(implicitWidth, textRow.width); height: 32; verticalAlignment: Text.AlignVCenter }
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
        y: root.stacked ? textRow.y + textRow.height + Theme.s2 : (root.height - height) / 2
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
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    The Shell's sidebar: the world (its disc, its name, what the app is
    for), the field that filters the page or searches the app, the
    sections with the world's light on the current one (a section with
    children opens out to them while one of them is open, as a carried
    moon's group does), the doors to other apps, and where the app stands
    with Sol at the bottom. On the rail (a narrow window) it is the same
    glass: the world's kanji in its diamond, each section's number over
    its short Japanese, and the field folded away behind a button until it
    is used. The Shell makes one and reads `finder` back.
*/
Item {
    id: side

    /** The Shell it is the sidebar of. */
    required property Shell frame
    /** The bottom of the sidebar: LinkStatus (the Shell's `status`). */
    property alias status: statusSlot.data
    /** The field, for the Shell's keys and its pages' filters. */
    readonly property alias finder: finder

    // Over the pane: the field floats out over it on the rail.
    z: 2
    width: side.frame.rail ? Theme.rail : Theme.sidebar
    height: parent.height
    // Folding to the rail or opening out, its width changes at once and it glides from where its
    // edge was: a transform, so nothing is laid out again on the way (never with less motion).
    property real lastWidth: -1
    Component.onCompleted: lastWidth = width
    onWidthChanged: {
        if (lastWidth >= 0 && !Theme.calm) { fold.stop(); edge.x = lastWidth - width; fold.start() }
        lastWidth = width
    }
    transform: Translate { id: edge }
    NumberAnimation { id: fold; target: edge; property: "x"; to: 0; duration: Theme.settle; easing: Theme.easeOut }
    Design.Settling { when: fold.running }

    // A rail of glass over the art, its bottom-right corner cut (narrow, it meets the window's edges).
    readonly property bool hud: true
    Design.HudGlass { anchors.fill: parent; cuts: [0, 0, side.frame.rail ? 0 : Theme.hudCut + 6, 0] }
    Design.HudBrackets { visible: !side.frame.rail; anchors.fill: parent; color: Theme.tint(Theme.hudAccent, 0.7); cuts: [0, 0, Theme.hudCut + 6, 0] }
    Rectangle { visible: side.frame.rail; anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    // The brand: the world's disc, its name, and what the app is for.
    Item {
        id: brand
        x: side.frame.rail ? 0 : 20
        width: side.frame.rail ? parent.width : parent.width - 36
        // As tall as its words (the name in Japanese, the name, what the app is for), never less than a bar.
        height: Math.max(Theme.navHeight, brandRow.implicitHeight + Theme.s3)
        y: Theme.s2
        Row {
            id: brandRow
            anchors.verticalCenter: parent.verticalCenter
            // A binding, not a conditional anchor (see SidebarRow).
            x: side.frame.rail ? (parent.width - width) / 2 : 0
            spacing: 12
            Item {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                scale: brandMouse.containsMouse ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
                // On the floating rail: the world's kanji in a diamond.
                Rectangle {
                    visible: side.hud
                    anchors.centerIn: parent
                    width: 24; height: 24
                    rotation: 45
                    color: Theme.tint(Theme.hudAccent, 0.12)
                    border.width: 1.5; border.color: Theme.hudAccent
                    antialiasing: true
                }
                Text {
                    visible: side.hud
                    anchors.centerIn: parent
                    text: Theme.jpOf(side.frame.world).charAt(0)
                    font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle; font.pixelSize: 14
                    color: Theme.hudText
                }
            }
            Column {
                visible: !side.frame.rail
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                // The world's name in Japanese over the name.
                Text {
                    text: Theme.jpOf(side.frame.world)
                    font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle; font.pixelSize: Theme.textM + 2
                    color: Theme.hudText
                }
                Text {
                    text: side.frame.w.name
                    width: Math.min(implicitWidth, brand.width - 34)
                    elide: Text.ElideRight
                    font.family: Theme.fontCaps; font.weight: Font.Bold; font.pixelSize: Theme.textS
                    font.letterSpacing: Theme.track(Theme.trackHud, Theme.textS); font.capitalization: Font.AllUppercase
                    color: Theme.textBright
                }
                Text {
                    visible: text !== ""
                    text: side.frame.w.role
                    width: Math.min(implicitWidth, brand.width - 34)
                    elide: Text.ElideRight
                    font.family: Theme.font; font.weight: Theme.weightValue; font.pixelSize: Theme.textXs
                    font.letterSpacing: Theme.track(0.04, Theme.textXs)
                    color: side.hud ? Theme.hudQuiet : Theme.textWorld
                }
            }
        }
        MouseArea { id: brandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: side.frame.go(side.frame.home) }
        Hint { text: side.frame.w.tagline; when: brandMouse.containsMouse }
    }

    // The field: filters the page in place when it can, searches the app
    // otherwise; there only when it can do one or the other. On the rail it
    // waits behind a button and floats over the top of the pane while used.
    Item {
        id: findButton
        visible: side.frame.rail && finder.usable
        y: brand.y + brand.height
        width: parent.width
        height: Theme.control
        activeFocusOnTab: false
        Rectangle { anchors.centerIn: parent; width: Theme.control; height: Theme.control; radius: Theme.radiusM; color: findMouse.containsMouse || side.frame.finding ? Theme.surface : "transparent"; Behavior on color { ColorAnimation { duration: Theme.fade } } }
        Icon { anchors.centerIn: parent; name: "search"; size: 13; color: findMouse.containsMouse || side.frame.finding ? Theme.textBright : Theme.textQuiet }
        MouseArea { id: findMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: side.frame.find() }
        Hint { text: (finder.filtering ? "Filter this page" : "Search") + " · /"; when: findMouse.containsMouse }
    }
    // Its ground while it floats over the pane.
    Rectangle {
        visible: side.frame.rail && finder.visible
        x: finder.x - Theme.s3; y: finder.y - Theme.s1
        width: finder.width + Theme.s3 * 2; height: finder.height + Theme.s1 * 2
        radius: Theme.radiusM
        color: Theme.deep
        border.width: 1; border.color: Theme.lineMid
    }
    Field {
        id: finder
        readonly property Design.Screen screen: side.frame.page as Design.Screen
        readonly property bool filtering: !!screen && screen.filters
        readonly property bool usable: filtering || side.frame.search !== ""
        visible: usable && (!side.frame.rail || side.frame.finding)
        x: side.frame.rail ? side.width + Theme.s4 : 20
        y: side.frame.rail ? Theme.s2 : brand.y + brand.height + Theme.s1
        width: side.frame.rail ? Math.min(320, side.frame.width - side.width - Theme.s4 * 2) : parent.width - 36
        label: ""
        placeholder: filtering ? "Filter · /" : "Search · /"
        // Gone (a page that doesn't filter, a search sent), it filters nothing.
        onVisibleChanged: if (!visible) text = ""
        onTextChanged: if (screen) screen.filter = text
        onAccepted: { if (!filtering && side.frame.search !== "" && text.trim() !== "") { const q = text.trim(); text = ""; side.frame.finding = false; side.frame.go(side.frame.search, { query: q }) } }
        Keys.onEscapePressed: { text = ""; side.frame.finding = false; side.frame.forceActiveFocus() }
    }
    // Left empty on the rail, it folds away again.
    Connections { target: finder.input; function onActiveFocusChanged() { if (!finder.input.activeFocus && finder.text === "") side.frame.finding = false } }

    // The sections and the doors, between the brand and the status; they scroll
    // only when they don't fit (a planet with its moon's group open, a short window).
    Flickable {
        id: scroller
        readonly property real from: side.frame.rail ? (findButton.visible ? findButton.y + findButton.height + Theme.s2 : brand.y + brand.height + Theme.s2)
            : finder.visible ? finder.y + finder.height + Theme.s3 : brand.y + brand.height + Theme.s2
        y: from
        width: parent.width
        height: Math.max(0, (navigator.holds ? navigator.y : statusSlot.y) - from - Theme.s2)
        contentHeight: doorColumn.visible ? doorColumn.y + doorColumn.height : list.height
        interactive: contentHeight > height
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
        /** Scrolls the current section into view, when the list scrolls at all. */
        function reveal() {
            const r = light.row
            if (!r || !interactive) return
            if (r.y < contentY) contentY = r.y
            else if (r.y + r.height > contentY + height) contentY = Math.min(contentHeight - height, r.y + r.height - height)
        }
        Connections { target: side.frame; function onPathChanged() { Qt.callLater(scroller.reveal) } }
        onHeightChanged: Qt.callLater(scroller.reveal)

    // The sections, with the world's light on the current one.
    Item {
        id: list
        x: side.frame.rail ? Theme.s1 : Theme.s2
        y: 0
        width: parent.width - x * 2
        height: sectionColumn.implicitHeight

        Rectangle {
            id: light
            x: 0
            // On the floating rail, a bar in the world's light the row's height.
            width: 3
            height: row ? row.full - row.rowTop : Theme.control
            color: Theme.hudAccent
            opacity: side.frame.currentRow >= 0 ? 1 : 0
            // On the current row (a moon's group has its name above it).
            readonly property var row: sectionRepeater.count > 0 ? sectionRepeater.itemAt(Math.max(0, side.frame.currentRow)) : null
            y: row ? row.y + row.rowTop : 0
            property bool moved: false
            onYChanged: moved = true
            Behavior on y { enabled: light.moved; NumberAnimation { duration: Theme.settle; easing: Theme.spring } }
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            RectangularShadow { anchors.fill: parent; blur: 8; spread: 0; color: light.color; z: -1 }
        }

        Column {
            id: sectionColumn
            width: parent.width
            Repeater {
                id: sectionRepeater
                // By count, so a row's badge or hint changing (a card graded, Today's count going
                // down) updates its row in place instead of making every row and its arrival again.
                model: side.frame.rows.length
                // A carried moon's sections are a group under its name (on the rail, a line above);
                // a section's children follow it, a step in.
                delegate: Item {
                    id: entry
                    required property int index
                    readonly property var modelData: side.frame.rows[index] || ({ top: 0 })
                    readonly property bool first: !!modelData.group && !modelData.child && (modelData.top === 0 || side.frame.sections[modelData.top - 1].group !== modelData.group)
                    readonly property real caption: !first ? 0 : side.frame.rail ? Theme.s3 : 30
                    // The gap above it, as a Column's spacing would put it.
                    readonly property real gap: index === 0 ? 0 : 2
                    /** Where its row starts: under the gap and the group's name. */
                    readonly property real rowTop: gap + caption
                    readonly property string here: side.frame.path
                    /** The section it is, or is a child of. */
                    readonly property var section: side.frame.sections[modelData.top]
                    // A moon's group shows its first page until one of its pages is open, then all;
                    // a section's children show while it or one of them is open.
                    readonly property bool leads: modelData.top === 0 || side.frame.sections[modelData.top - 1].world !== section.world
                    readonly property bool folded: (!!section.world && side.frame.worldOf(here) !== section.world && (!leads || modelData.child))
                        || (modelData.child && here !== section.path && !section.children.some(c => c.path === entry.here))
                    readonly property real full: rowTop + row.height
                    width: sectionColumn.width
                    // Folding and opening out settle: the rows under it glide as it opens, and it
                    // fades and slips into place (at once with less motion, and the first time).
                    property real shown: folded ? 0 : 1
                    property bool ready: false
                    Component.onCompleted: Qt.callLater(() => entry.ready = true)
                    Behavior on shown { enabled: entry.ready && !Theme.calm; NumberAnimation { id: folding; duration: Theme.settle; easing: Theme.easeOut } }
                    height: full * shown
                    visible: shown > 0.01
                    opacity: shown
                    transform: Translate { y: (1 - entry.shown) * -6 }
                    Design.Settling { when: folding.running }
                    Rectangle {
                        visible: entry.first
                        y: entry.gap + Theme.s1
                        width: parent.width
                        height: 1
                        color: Theme.line
                    }
                    // A moon's group: 衛星 (a moon, in the title serif), then its name in capitals.
                    Row {
                        visible: entry.first && !side.frame.rail
                        x: 18
                        // A little higher than a line of capitals alone: the serif's 衛星 is taller.
                        y: entry.gap + Theme.s3 - 3
                        spacing: Theme.s2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "衛星"
                            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 2; font.weight: Theme.weightTitle
                            color: Theme.textQuiet
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.group || ""
                            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                            font.letterSpacing: Theme.track(Theme.trackLabel, Theme.textXs); font.capitalization: Font.AllUppercase
                            color: Theme.textQuiet
                        }
                    }
                    Design.SidebarRow {
                        id: row
                        y: entry.rowTop
                        place: entry.index
                        width: parent.width
                        rail: side.frame.rail
                        hud: side.hud
                        jp: entry.modelData.jp || ""
                        moon: !!entry.modelData.group
                        child: !!entry.modelData.child
                        label: entry.modelData.label
                        world: entry.modelData.icon || entry.modelData.child ? "" : entry.modelData.world || ""
                        icon: entry.modelData.icon || ""
                        badge: entry.modelData.badge || 0
                        current: side.frame.path === entry.modelData.path
                        // On the rail only the mark shows: the hint names the section too.
                        readonly property string parentLabel: entry.modelData.child ? side.frame.sections[entry.modelData.top].label + " · " : ""
                        hint: [side.frame.rail ? (entry.modelData.group ? entry.modelData.group + " · " : "") + parentLabel + entry.modelData.label + (entry.modelData.badge ? " (" + entry.modelData.badge + ")" : "") : "", entry.modelData.hint, !entry.modelData.child && entry.modelData.top < 9 ? "Ctrl+" + (entry.modelData.top + 1) : ""].filter(Boolean).join(" · ")
                        onClicked: side.frame.go(entry.modelData.path)
                    }
                }
            }
        }
    }

    // Doors to other apps: after the sections, before the status.
    Column {
        id: doorColumn
        visible: side.frame.doors.length > 0
        x: list.x
        y: list.y + list.height + Theme.s3
        width: list.width
        spacing: 2
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Item { width: 1; height: Theme.s2 - 2 }
        Repeater {
            model: side.frame.doors
            delegate: SidebarRow {
                required property var modelData
                required property int index
                place: side.frame.sections.length + index
                width: doorColumn.width
                // Another app: its name, and under it what it is for.
                height: side.frame.rail || !modelData.role ? Theme.control : Theme.target
                door: true
                rail: side.frame.rail
                label: modelData.label
                role: modelData.role || ""
                world: modelData.world
                hint: [side.frame.rail ? modelData.label + (modelData.role ? " · " + modelData.role : "") : "", modelData.hint || ""].filter(Boolean).join(" · ")
                onClicked: modelData.open()
            }
        }
    }

    }

    // The navigator, over the status, while the rows leave it room; else its head chip, on
    // the rail's edge beside the status (on the narrow rail, over it).
    Design.Navigator {
        id: navigator
        /** The room the rows leave above the status. */
        readonly property real room: statusSlot.y - Theme.s3 - scroller.from - Theme.s2 - scroller.contentHeight
        /** Whether it takes room from the rows (the chip beside the status takes none). */
        readonly property bool holds: here && (!chip || narrow)
        narrow: side.frame.rail
        space: room
        x: side.frame.rail ? 0 : 18
        width: parent.width - x * 2
        edge: x
        height: implicitHeight
        // The chip's middle on the status line, or the whole of it over the status.
        y: holds ? statusSlot.y - Theme.s3 - height : statusSlot.y + 1 + statusSlot.spacing + (statusSlot.height - 1 - statusSlot.spacing - height) / 2
        z: 3
        world: side.frame.world
        jp: side.frame.navigatorJp
        line: side.frame.navigatorLine
        looking: side.frame.path
        away: side.frame.navigatorAway
    }
    /** How far the navigator reaches past the sidebar's edge into the page (the Screen keeps its big title clear). */
    readonly property real navigatorReach: navigator.here ? Math.max(0, navigator.reach) : 0

    // The bottom: where the app stands with Sol.
    Column {
        id: statusSlot
        // On the rail it stays, as dots (LinkStatus is compact there).
        x: side.frame.rail ? Theme.s2 : 20
        width: parent.width - (side.frame.rail ? Theme.s2 * 2 : 36)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s3
        spacing: Theme.s2
        /** How far its words may run: short of the navigator's head chip when that sits beside them
            (the diamond's edge at the words' height, a little apart). */
        readonly property real room: navigator.here && navigator.chip && !side.frame.rail
            ? Math.min(width, navigator.x + navigator.chipEdge(Theme.textXs / 2) - x - Theme.s1) : width
        Rectangle { width: statusSlot.width; height: 1; color: Theme.line }
    }
}

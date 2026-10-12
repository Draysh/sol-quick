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
    with Sol at the bottom. On the rail (a
    narrow window) only the icons and marks show, and the field folds away
    behind a button until it is used. The Shell makes one and reads
    `finder` back.
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
    Behavior on width { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

    // The chrome sits a step deeper than the pane.
    Rectangle { anchors.fill: parent; color: Theme.deep }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

    // The brand: the world's disc, its name, and what the app is for.
    Item {
        id: brand
        x: side.frame.rail ? 0 : 20
        width: side.frame.rail ? parent.width : parent.width - 36
        height: Theme.navHeight
        y: Theme.s2
        Row {
            anchors.verticalCenter: parent.verticalCenter
            // A binding, not a conditional anchor (see SidebarRow).
            x: side.frame.rail ? (parent.width - width) / 2 : 0
            spacing: 12
            Item {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                scale: brandMouse.containsMouse ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                Body { world: side.frame.world; disc: 22; animated: false }
            }
            Column {
                visible: !side.frame.rail
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: side.frame.w.name
                    width: Math.min(implicitWidth, brand.width - 34)
                    elide: Text.ElideRight
                    font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textS
                    font.letterSpacing: Theme.track(0.28, Theme.textS); font.capitalization: Font.AllUppercase
                    color: Theme.textBright
                }
                Text {
                    visible: text !== ""
                    text: side.frame.w.role
                    width: Math.min(implicitWidth, brand.width - 34)
                    elide: Text.ElideRight
                    font.family: Theme.font; font.weight: Theme.weightValue; font.pixelSize: Theme.textXs
                    font.letterSpacing: Theme.track(0.04, Theme.textXs)
                    color: Theme.textWorld
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
        y: side.frame.rail ? Theme.s2 : brand.y + brand.height
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
        height: Math.max(0, statusSlot.y - from - Theme.s2)
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
            width: 2
            height: Theme.control - 18
            color: Theme.accent
            opacity: side.frame.currentRow >= 0 ? 1 : 0
            // On the current row (a moon's group has its name above it).
            readonly property var row: sectionRepeater.count > 0 ? sectionRepeater.itemAt(Math.max(0, side.frame.currentRow)) : null
            y: (row ? row.y + row.rowTop : 0) + 9
            property bool moved: false
            onYChanged: moved = true
            Behavior on y { enabled: light.moved; SpringAnimation { spring: 3.2; damping: 0.28; mass: 0.9 } }
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            RectangularShadow { anchors.fill: parent; blur: 8; spread: 0; color: Theme.accent; z: -1 }
        }

        Column {
            id: sectionColumn
            width: parent.width
            Repeater {
                id: sectionRepeater
                model: side.frame.rows
                // A carried moon's sections are a group under its name (on the rail, a line above);
                // a section's children follow it, a step in.
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
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
                    Behavior on shown { enabled: entry.ready && !Theme.calm; NumberAnimation { id: folding; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
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
                    Text {
                        visible: entry.first && !side.frame.rail
                        x: Theme.s3
                        y: entry.gap + Theme.s3
                        text: entry.modelData.group || ""
                        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                        font.letterSpacing: Theme.track(Theme.trackLabel, Theme.textXs); font.capitalization: Font.AllUppercase
                        color: Theme.textQuiet
                    }
                    Design.SidebarRow {
                        id: row
                        y: entry.rowTop
                        place: entry.index
                        width: parent.width
                        rail: side.frame.rail
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

    // The bottom: where the app stands with Sol.
    Column {
        id: statusSlot
        // On the rail it stays, as dots (LinkStatus is compact there).
        x: side.frame.rail ? Theme.s2 : 20
        width: parent.width - (side.frame.rail ? Theme.s2 * 2 : 36)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s3
        spacing: Theme.s2
        Rectangle { width: statusSlot.width; height: 1; color: Theme.line }
    }
}

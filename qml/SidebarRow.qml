import QtQuick

/*
    One row of the Shell's sidebar: a section (its number, its Japanese,
    its name, a count) or, with `door`, a door to another app (its world's
    kanji in a small diamond, its name and under it what it is for). On the
    rail the number shows over a short Japanese name (two characters at
    most), a door's diamond alone, and the hint names the row. A `child`
    (a page under a section) sits a step in. The Sidebar lays them out.
*/
Settle {
    id: row

    property bool rail: false
    property string label: ""
    /** Under the name: what a door's app is for. */
    property string role: ""
    /** A world's glyph instead of the plain mark. */
    property string world: ""
    /** The section's icon (an `Icon` name) instead of the plain mark: quiet at rest, bright when current or under the pointer. */
    property string icon: ""
    /** A count at the row's end (a section's), 0 for none. */
    property var badge: 0
    /** The whole hint, shown while the pointer is on the row. */
    property string hint: ""
    property bool current: false
    /** A door: its name rests brighter and stays put on hover. */
    property bool door: false
    /** A page under a section: a step in from the section's row. */
    property bool child: false
    /** On the floating rail (not the narrow one): its number in the HUD face for its mark, and a wash in the world's light while current. */
    property bool hud: false
    /** Its name in Japanese, before the English: "書庫". */
    property string jp: ""
    /** A carried moon's row: its number in the world's second light. */
    property bool moon: false
    /** Whether the flavour writes the numbers in kanji (Mercury's: 一, 二, 三), in its title face. */
    readonly property bool kanjiNumber: !!Theme.hud.kanjiNumbers
    /** The number it shows on the floating rail: its place, from 01 (or 一). */
    readonly property string number: kanjiNumber ? Format.kanji(place + 1) : (place + 1 < 10 ? "0" : "") + (place + 1)
    readonly property bool numbered: hud && !door
    /** Its Japanese on the rail, under the number: only when it is short enough to read there. */
    readonly property string railJp: jp.length > 0 && jp.length <= 2 ? jp : ""
    signal clicked()

    readonly property bool iconed: row.icon !== "" && row.world === ""
    // The mark's box: an icon takes a little more room than the dot.
    readonly property int markSize: row.iconed || row.world !== "" ? 16 : 10

    height: rail && numbered && railJp !== "" ? Theme.target + 4 : Theme.control

    Rectangle {
        visible: !row.hud
        anchors.fill: parent
        radius: Theme.radiusM
        color: row.current ? Theme.surfaceHover : rowMouse.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    // The wash: the world's light from the left, fading out to the right.
    Rectangle {
        visible: row.hud
        anchors.fill: parent
        opacity: row.current ? 1 : rowMouse.containsMouse ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.tint(Theme.hudAccent, 0.24) }
            GradientStop { position: 0.7; color: Theme.tint(Theme.hudAccent, 0.03) }
            GradientStop { position: 1; color: Theme.tint(Theme.hudAccent, 0) }
        }
    }
    // On the rail: the number over the short Japanese.
    Column {
        visible: row.rail && row.numbered
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: row.number
            // A kanji number is a mark (一, 二, 三: a few strokes), so it keeps the title face at any size.
            font.family: row.kanjiNumber ? Theme.fontTitle : Theme.fontHud; font.pixelSize: row.kanjiNumber ? Theme.textS + 1 : Theme.textXs + 1
            font.weight: row.kanjiNumber ? Theme.weightTitle : Font.DemiBold
            color: row.current ? Theme.hudAccent : rowMouse.containsMouse ? Theme.hudText : row.moon ? Theme.tint(Theme.hudSecond, 0.8) : Theme.hudFaint
        }
        Text {
            visible: row.railJp !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: row.railJp
            font.family: Theme.titleFace(Theme.textS); font.features: Theme.titleFeatures; font.pixelSize: Theme.textS; font.weight: Theme.titleWeight(Theme.textS)
            color: row.current || rowMouse.containsMouse ? Theme.hudText : Theme.hudQuiet
        }
    }
    Row {
        visible: !(row.rail && row.numbered)
        anchors.verticalCenter: parent.verticalCenter
        // One binding, not an anchor that comes and goes: a released anchor
        // leaves the row where it was put (off by a few pixels after the
        // sidebar starts as a rail for a moment).
        x: row.rail ? (row.width - width) / 2 : (row.child ? Theme.s4 : 0) + (row.hud ? 18 : 12)
        spacing: row.iconed ? 10 : 12
        Text {
            visible: row.numbered && !row.rail
            anchors.verticalCenter: parent.verticalCenter
            text: row.number
            // A kanji number takes the square two figures take, so the names still start in one column.
            width: row.kanjiNumber ? Math.max(implicitWidth, Math.ceil(Theme.textS * 1.2)) : implicitWidth
            horizontalAlignment: Text.AlignHCenter
            // A kanji number is a mark (一, 二, 三: a few strokes), so it keeps the title face at any size.
            font.family: row.kanjiNumber ? Theme.fontTitle : Theme.fontHud; font.pixelSize: row.kanjiNumber ? Theme.textS + 1 : Theme.textXs + 1
            font.weight: row.kanjiNumber ? Theme.weightTitle : Font.DemiBold
            font.letterSpacing: row.kanjiNumber ? 0 : Theme.track(0.06, Theme.textXs)
            color: row.current ? Theme.hudAccent : rowMouse.containsMouse ? Theme.hudText : row.moon ? Theme.tint(Theme.hudSecond, 0.8) : Theme.hudFaint
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Item {
            visible: !row.numbered
            width: row.markSize; height: row.markSize
            anchors.verticalCenter: parent.verticalCenter
            // Another world: its kanji in a small diamond.
            Rectangle { visible: row.world !== ""; anchors.centerIn: parent; width: 12; height: 12; rotation: 45; antialiasing: true; color: "transparent"; border.width: 1; border.color: rowMouse.containsMouse ? Theme.hudAccent : Theme.lineStrong }
            Text { visible: row.world !== ""; anchors.centerIn: parent; text: Theme.jpOf(row.world || "sol").charAt(0); font.family: Theme.fontTitle; font.pixelSize: 8; font.weight: Theme.weightTitle; color: Theme.hudText }
            Icon {
                visible: row.iconed
                name: row.icon || "close"
                size: 16
                stroke: 1.25
                color: row.current || rowMouse.containsMouse ? Theme.textBright : Theme.textQuiet
                scale: rowMouse.containsMouse && !row.current ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Rectangle {
                visible: row.world === "" && !row.iconed
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: row.current ? Theme.textBright : "transparent"
                border.width: 1
                border.color: row.current || rowMouse.containsMouse ? Theme.textBright : Theme.lineStrong
                scale: rowMouse.containsMouse && !row.current ? 1.2 : 1
                Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
                Behavior on color { ColorAnimation { duration: Theme.lock } }
                Behavior on border.color { ColorAnimation { duration: Theme.lock } }
            }
        }
        Text {
            id: jpText
            visible: row.hud && row.jp !== "" && !row.rail
            anchors.verticalCenter: parent.verticalCenter
            text: row.jp
            font.family: Theme.titleFace(Theme.textS); font.features: Theme.titleFeatures; font.pixelSize: Theme.textS; font.weight: Theme.titleWeight(Theme.textS)
            color: row.current || rowMouse.containsMouse ? Theme.hudText : Theme.hudQuiet
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Column {
            visible: !row.rail
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: row.label
                width: Math.min(implicitWidth, row.width - (row.door ? 34 : 60 + (row.iconed ? 4 : 0) + (badge.visible ? 28 : 0) + (row.child ? Theme.s4 : 0) + (jpText.visible ? jpText.width + 12 : 0)))
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: row.hud && row.current ? Theme.weightName : Theme.weightValue
                color: row.current || rowMouse.containsMouse ? Theme.textBright : row.door ? Theme.text : row.hud ? Theme.hudQuiet : Theme.textQuiet
                transform: Translate { x: !row.door && rowMouse.containsMouse ? 2 : 0; Behavior on x { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } } }
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Text {
                visible: row.role !== ""
                text: row.role
                width: Math.min(implicitWidth, row.width - 34)
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue
                color: Theme.textQuiet
            }
        }
    }
    Rectangle {
        id: badge
        visible: !!row.badge
        // At the row's end; on the rail, smaller, over the mark's shoulder.
        x: row.rail ? parent.width / 2 + (row.iconed ? 5 : 3) : parent.width - 12 - width
        y: row.rail ? 2 : (parent.height - height) / 2
        width: Math.max(height, badgeText.implicitWidth + (row.rail ? 6 : 10)); height: row.rail ? 14 : 18; radius: height / 2
        // The world's light, the number dark on it.
        color: Theme.textWorld
        border.width: row.rail ? 2 : 0; border.color: row.current ? Theme.surfaceHover : Theme.deep
        Text { id: badgeText; anchors.centerIn: parent; text: row.badge || ""; font.family: Theme.fontHud; font.pixelSize: row.rail ? 9 : 10; font.weight: Font.Bold; color: Theme.space }
        onVisibleChanged: if (visible) pop.restart()
        SequentialAnimation { id: pop; NumberAnimation { target: badge; property: "scale"; from: 0.6; to: 1; duration: Theme.settle; easing: Theme.easeOut } }
    }
    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
    Hint { text: row.hint; when: rowMouse.containsMouse }
}

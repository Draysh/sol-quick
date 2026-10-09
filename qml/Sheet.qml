pragma ComponentBehavior: Bound
import QtQuick

/*
    The band across the top of a world's first screen: the lit body, its
    name in a reticle, a callout, moon links and data rows along the
    bottom. It is a header, not a hero: the working surface starts right
    under it. It arrives in order: the body rises, the reticle finds the
    name, the callout and the strip of facts settle after it.

    `drift` is the pane's scroll: the bodies sink a little slower than the
    band, so the sheet has depth.

        Sheet { world: "terra"; callout: ["Walk = done"]; rows: [[{ label: "Streak", value: "12 days" }], [{ label: "Sol", value: "in sync" }]] }
*/
Item {
    id: root

    property string world: "terra"
    /** Defaults to the world's name. */
    property string name: ""
    property var callout: []
    /** Up to three blocks of rows: left, centre and right. */
    property var rows: []
    /** `{ label, open }` links to the world's moons, shown under the name. */
    property var moons: []
    /** Extra content under the name, such as the screen's main action. */
    default property alias under: underRow.data
    property real drift: 0
    /** 0 at rest, 1 shrunk to a bar; the Screen drives it when the Sheet is pinned. */
    property real collapse: 0
    readonly property real compact: Theme.navHeight

    readonly property var w: Worlds.get(world)
    readonly property bool portrait: width < 700
    readonly property real u: portrait ? width / 390 : width / 1600
    readonly property real frameH: portrait ? 580 : 900
    readonly property real bandH: portrait ? Math.max(240, Math.min(360, u * 340)) : Math.max(260, Math.min(400, u * 470))
    readonly property real reticle: portrait ? 140 : Math.max(140, Math.min(210, u * 200))

    width: parent ? parent.width : 1200
    readonly property real stripH: rows.length ? stripRow.implicitHeight + Theme.s2 * 2 + 1 : 0
    readonly property real fullHeight: bandH + stripH
    implicitHeight: fullHeight
    height: Math.round(fullHeight - (fullHeight - compact) * collapse)
    // Shrinking, nothing of it draws past its edge over the page.
    clip: true

    Item {
        id: band
        width: parent.width
        height: Math.max(root.compact, root.height - root.stripH * Math.max(0, 1 - root.collapse * 2))
        clip: true

        // The bar it becomes: the body small at the left, the name beside it.
        Row {
            x: Theme.margin(root.width)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s3
            opacity: Math.max(0, (root.collapse - 0.6) / 0.4)
            z: 2
            Item { width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter; Body { world: root.world; disc: 24; animated: false } }
            Text { text: root.name !== "" ? root.name : root.w.name; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.weight: Theme.weightName; font.pixelSize: Theme.textM; font.letterSpacing: Theme.track(0.12, Theme.textM); font.capitalization: Font.AllUppercase; color: Theme.textBright }
            Text { visible: root.rows.length > 0 && root.rows[0].length > 0; text: root.rows.length ? root.rows[0].map(r => r.label + " " + r.value).join(" · ") : ""; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Theme.textXs; font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase; color: Theme.textQuiet; elide: Text.ElideRight; width: Math.max(0, root.width - 400) }
        }

        Rectangle { anchors.fill: parent; color: Theme.deep }

        // The frame keeps its shape (16:9, or the phone's); the band shows its middle.
        Item {
            id: frame
            width: parent.width
            height: root.u * root.frameH
            y: band.height / 2 - height / 2 - root.drift * 0.18
            opacity: 1 - root.collapse
            scale: 1 - root.collapse * 0.15
            transformOrigin: Item.Top
            // A slow drift, so the scene breathes.
            transform: Translate { id: breathe; y: 0 }
            SequentialAnimation { running: Theme.alive && root.visible && root.collapse < 1; loops: Animation.Infinite; NumberAnimation { target: breathe; property: "y"; to: -4; duration: Theme.drift / 2; easing.type: Easing.InOutSine } NumberAnimation { target: breathe; property: "y"; to: 0; duration: Theme.drift / 2; easing.type: Easing.InOutSine } }

            component Placed: Body {
                id: placed
                property var at
                disc: root.u * placed.at.r * 2
                x: root.u * (placed.at.cx - placed.at.r)
                y: root.u * (placed.at.cy - placed.at.r)
                light: placed.at.light
                phase: placed.at.phase
            }

            Placed { world: root.world; at: root.portrait ? root.w.portrait : root.w.hero }
            Repeater {
                model: root.portrait ? [] : (root.w.companions || [])
                delegate: Placed { required property var modelData; world: modelData.world; at: modelData }
            }
        }

        // The name in its reticle, and what sits under it.
        Column {
            id: center
            x: parent.width / 2 - width / 2
            y: band.height / 2 - root.reticle / 2
            spacing: Theme.s2
            opacity: Math.max(0, 1 - root.collapse * 1.6)
            scale: 1 - root.collapse * 0.3
            transformOrigin: Item.Center
            width: Math.max(root.reticle, nameText.implicitWidth + 40)

            Reticle {
                size: root.reticle
                tilt: root.w.tilt
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    id: nameText
                    text: root.name !== "" ? root.name : root.w.name
                    font.family: Theme.font
                    font.weight: Theme.weightName
                    readonly property int size: root.portrait ? 24 : Math.max(20, Math.min(34, root.u * 36))
                    font.pixelSize: size
                    font.capitalization: Font.AllUppercase
                    color: Theme.text
                    style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35)
                    // The name comes into focus: from wide-spaced and faint to set.
                    property real focusT: 0
                    font.letterSpacing: Theme.track(0.3 - 0.22 * focusT, size)
                    opacity: focusT
                    SequentialAnimation { running: true; PauseAnimation { duration: Theme.rise / 4 } NumberAnimation { target: nameText; property: "focusT"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                }
            }
            Settle {
                wait: Theme.rise / 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: underRow.implicitWidth
                height: underRow.implicitHeight
                // Moons, or anything else put under the name (the Repeater is a child too).
                visible: root.moons.length > 0 || underRow.children.length > moonRepeater.count + 1
                Flow {
                    id: underRow
                    spacing: Theme.s4
                    Repeater { id: moonRepeater; model: root.moons; delegate: MoonLink { required property var modelData; text: modelData.label; hint: modelData.hint || ""; onClicked: modelData.open() } }
                }
            }
        }

        // The callout: a leader from the body and what comes next.
        Item {
            id: calloutBox
            visible: !root.portrait && root.callout.length > 0 && root.collapse < 0.5
            x: root.u * root.w.callout.x - (root.w.callout.flip ? width : 0)
            y: frame.y + root.u * root.w.callout.y
            width: calloutView.implicitWidth
            height: calloutView.implicitHeight
            opacity: 0
            SequentialAnimation { running: true; PauseAnimation { duration: Theme.rise / 2 } NumberAnimation { target: calloutBox; property: "opacity"; to: 1; duration: Theme.fade } }
            Callout { id: calloutView; lines: root.callout; flip: !!root.w.callout.flip }
        }

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
    }

    // The facts, on a strip of their own under the band.
    Item {
        id: strip
        y: band.height
        width: parent.width
        height: visible ? root.stripH : 0
        visible: root.rows.length > 0 && root.collapse < 0.5
        opacity: Math.max(0, 1 - root.collapse * 2)
        clip: true
        readonly property var blocks: root.rows.slice(0, root.portrait ? 2 : 3)
        readonly property int cols: root.portrait ? 2 : 3
        readonly property real margin: Theme.margin(width)

        Rectangle { anchors.fill: parent; color: Theme.deep }
        Item {
            id: stripRow
            x: strip.margin; y: Theme.s2
            width: parent.width - strip.margin * 2
            implicitHeight: Math.max(1, ...Array.from(stripRow.children).filter(c => c.hasOwnProperty("blockHeight")).map(c => c.blockHeight))
            readonly property real cell: (width - Theme.s4 * (strip.cols - 1)) / strip.cols
            Repeater {
                id: blockRepeater
                model: strip.blocks
                delegate: Settle {
                    id: block
                    required property var modelData
                    required property int index
                    readonly property int slot: strip.blocks.length === 3 ? index : index === 0 ? 0 : strip.cols - 1
                    readonly property real blockHeight: rowsView.implicitHeight
                    wait: Theme.rise / 3
                    place: index * 3
                    x: slot * (stripRow.cell + Theme.s4)
                    width: stripRow.cell
                    height: rowsView.implicitHeight
                    DataRows {
                        id: rowsView
                        width: parent.width
                        rows: block.modelData
                        align: block.slot === 0 ? Text.AlignLeft : block.slot === strip.cols - 1 ? Text.AlignRight : Text.AlignHCenter
                    }
                }
            }
        }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
    }
}

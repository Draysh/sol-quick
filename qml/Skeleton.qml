pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    The shape of a page before its data is here: surface-coloured blocks
    where the rows, cards or posters will be, with a light sweeping across
    them. Nothing jumps when the data lands, because the shape was already
    there. `kind` is `rows`, `cards` or `posters`.

        Skeleton { visible: !page.home; width: parent.width; kind: "posters" }
*/
Item {
    id: root

    property string kind: "rows"
    property int count: kind === "posters" ? 8 : kind === "cards" ? 4 : 6

    implicitHeight: kind === "posters" ? Math.ceil(count / columns) * (cell * 1.5 + 44) : kind === "cards" ? Math.ceil(count / (width < 420 ? 1 : 2)) * 180 : count * 52
    readonly property int columns: Math.max(2, Math.floor((width + Theme.s3) / (150 + Theme.s3)))
    readonly property real cell: (width - Theme.s3 * (columns - 1)) / columns

    component Block: Rectangle {
        color: Theme.surface
        radius: 1
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.tint(Theme.ink, 0.03) }
    }

    // Rows: a line of text and a shorter one under it, a hairline between.
    Column {
        visible: root.kind === "rows"
        width: parent.width
        Repeater {
            model: root.kind === "rows" ? root.count : 0
            delegate: Item {
                id: row
                required property int index
                width: parent.width
                height: 52
                Block { y: 14; width: parent.width * (0.35 + (row.index % 3) * 0.12); height: 12 }
                Block { y: 32; width: parent.width * 0.2; height: 8; opacity: 0.6 }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
        }
    }
    // Cards: a title line and a few rows of facts, in the grid.
    Flow {
        visible: root.kind === "cards"
        width: parent.width
        spacing: Theme.s4
        Repeater {
            model: root.kind === "cards" ? root.count : 0
            delegate: Item {
                required property int index
                width: root.width < 420 ? root.width : (root.width - Theme.s4) / 2
                height: 156
                // A card's own panel, so the real one takes its place without a jump.
                Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.raised; border.width: 1; border.color: Theme.line }
                Block { x: 20; y: 22; width: 90; height: 10 }
                Block { x: 20; y: 56; width: parent.width * 0.6; height: 10; opacity: 0.7 }
                Block { x: 20; y: 80; width: parent.width * 0.45; height: 10; opacity: 0.7 }
                Block { x: 20; y: 104; width: parent.width * 0.5; height: 10; opacity: 0.7 }
            }
        }
    }
    // Posters: 2:3 frames with a name under each.
    Flow {
        visible: root.kind === "posters"
        width: parent.width
        spacing: Theme.s3
        Repeater {
            model: root.kind === "posters" ? root.count : 0
            delegate: Column {
                id: poster
                required property int index
                width: root.cell
                spacing: Theme.s2
                Block { width: parent.width; height: parent.width * 1.5 }
                Block { width: parent.width * (0.5 + (poster.index % 2) * 0.3); height: 10 }
            }
        }
    }

    // The light sweeping across, while the window is awake.
    Rectangle {
        id: sweep
        width: parent.width * 0.35
        height: parent.height
        opacity: 0.6
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.5; color: Theme.tint(Theme.ink, 0.035) } GradientStop { position: 1; color: "transparent" } }
        NumberAnimation on x { running: root.visible && Theme.alive; loops: Animation.Infinite; from: -sweep.width; to: root.width; duration: 1600; easing.type: Easing.InOutSine }
    }
}

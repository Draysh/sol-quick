import QtQuick

/*
    Cards in an auto-fit grid: as many columns of at least `min` as fit,
    24 px apart, each row as tall as its tallest card and every card
    starting at the top of its row. Put it in a Screen; give the cards
    nothing but their content.

        Grid { Card { title: "Log"; … } Card { title: "Sol"; … } }
*/
Item {
    id: grid

    property real min: 300
    property real gap: Theme.s4
    default property alias cards: slot.data

    implicitHeight: slot.childrenRect.height
    width: parent ? parent.width : 600

    readonly property int columns: Math.max(1, Math.floor((width + gap) / (min + gap)))
    readonly property real cell: (width - gap * (columns - 1)) / columns

    onWidthChanged: place()
    onColumnsChanged: place()
    Component.onCompleted: place()

    Item {
        id: slot
        width: grid.width
        onChildrenChanged: grid.watch()
    }

    property var watched: []
    /** A Repeater among the cards is not a card. */
    function isRepeater(c) { return c.hasOwnProperty("delegate") && c.hasOwnProperty("model") && c.hasOwnProperty("count") }
    function watch() {
        if (!grid || !slot) return
        let n = 0
        for (const c of slot.children) {
            if (!c || !c.hasOwnProperty("implicitHeight") || isRepeater(c)) continue
            // Its place among the cards (a Repeater among them is not one).
            if (watched.indexOf(c) < 0) {
                watched.push(c)
                c.implicitHeightChanged.connect(grid.place)
                c.visibleChanged.connect(grid.place)
            }
            if (c.hasOwnProperty("index") && c.index !== n) c.index = n
            n++
        }
        place()
    }

    function place() {
        // A card can still report a height while the grid is going away.
        if (!grid || grid.width <= 0) return
        let col = 0, y = 0, rowHeight = 0, i = 0
        for (const c of slot.children) {
            if (!c || !c.visible || isRepeater(c)) continue
            c.width = grid.cell
            c.x = col * (grid.cell + grid.gap)
            c.y = y
            rowHeight = Math.max(rowHeight, c.implicitHeight)
            col++
            i++
            if (col === grid.columns) {
                col = 0
                y += rowHeight + grid.gap
                rowHeight = 0
            }
        }
    }
}

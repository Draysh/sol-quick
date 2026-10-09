import QtQuick

/*
    Cards in an auto-fit grid: as many columns of at least `min` as fit
    (never more than there are cards showing, so a short set fills the row),
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

    // Set by place(), from the cards that show.
    implicitHeight: 0
    width: parent ? parent.width : 600

    /** How many columns of at least `min` the width holds. */
    readonly property int fit: Math.max(1, Math.floor((width + gap) / (min + gap)))
    /** The cards that show (set by place()): a short set fills the row instead of leaving empty columns. */
    property int shown: 0
    readonly property int columns: Math.max(1, Math.min(fit, shown > 0 ? shown : fit))
    readonly property real cell: (width - gap * (columns - 1)) / columns

    onCellChanged: place()
    onGapChanged: place()
    Component.onCompleted: place()

    Item {
        id: slot
        width: grid.width
        onChildrenChanged: grid.watch()
    }

    /** The cards now in the grid, each placed again when it grows or hides. */
    property var watched: []
    /** A Repeater among the cards is not a card. */
    function isRepeater(c) { return c.hasOwnProperty("delegate") && c.hasOwnProperty("model") && c.hasOwnProperty("count") }
    function watch() {
        if (!grid || !slot) return
        const cards = []
        for (const c of slot.children) if (c && c.hasOwnProperty("implicitHeight") && !isRepeater(c)) cards.push(c)
        for (const c of cards) {
            if (watched.indexOf(c) >= 0) continue
            c.implicitHeightChanged.connect(grid.place)
            c.visibleChanged.connect(grid.place)
        }
        // Cards gone with a Repeater's reload are let go.
        watched = cards
        // Its place among the cards, for the stagger.
        cards.forEach((c, n) => { if (c.hasOwnProperty("index") && c.index !== n) c.index = n })
        place()
    }

    property bool placing: false
    property bool again: false
    function place() {
        // A card can still report a height while the grid is going away.
        if (!grid || grid.width <= 0) return
        // Asked again while placing (a card grew as it was given its width): once more, after.
        if (placing) { again = true; return }
        placing = true
        // Counted first: a card showing or hiding can change the columns, and with them the cell.
        let n = 0
        for (const c of slot.children) if (c && c.visible && !isRepeater(c)) n++
        shown = n
        let col = 0, y = 0, rowHeight = 0, bottom = 0
        for (const c of slot.children) {
            if (!c || !c.visible || isRepeater(c)) continue
            c.width = grid.cell
            c.x = col * (grid.cell + grid.gap)
            c.y = y
            rowHeight = Math.max(rowHeight, c.implicitHeight)
            bottom = y + rowHeight
            if (++col === grid.columns) {
                col = 0
                y += rowHeight + grid.gap
                rowHeight = 0
            }
        }
        grid.implicitHeight = bottom
        placing = false
        if (again) { again = false; Qt.callLater(grid.place) }
    }
}

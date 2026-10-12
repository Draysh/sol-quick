import QtQuick

/*
    Cards in an auto-fit grid: as many columns of at least `min` as fit
    (never more than there are cards showing, so a short set fills the row),
    24 px apart, each row as tall as its tallest card and every card
    starting at the top of its row. Put it in a Screen; give the cards
    nothing but their content. A card may take two columns or the whole
    row (`Card.span`). With `masonry`, each card goes into the shortest
    column instead, so cards of very different heights leave no holes.
    When the grid places them again (a card grows, hides or shows), cards
    glide to their new place.

        Grid { Card { title: "Log"; … } Card { title: "Sol"; … } }
        Grid { masonry: true; Card { title: "Today"; span: 2; … } Card { … } }
*/
Item {
    id: grid

    property real min: 300
    property real gap: Theme.s4
    /** Each card into the shortest column, not row by row: for pages of cards of very different heights. */
    property bool masonry: false
    default property alias cards: slot.data

    // Set by place(), from the cards that show.
    implicitHeight: 0
    width: parent ? parent.width : 600

    /** How many columns of at least `min` the width holds. */
    readonly property int fit: Math.max(1, Math.floor((width + gap) / (min + gap)))
    /** The columns the cards that show would take side by side (set by place()): a short set fills the row instead of leaving empty columns. */
    property int shown: 0
    readonly property int columns: Math.max(1, Math.min(fit, shown > 0 ? shown : fit))
    readonly property real cell: (width - gap * (columns - 1)) / columns

    onCellChanged: place()
    onGapChanged: place()
    onMasonryChanged: place()
    Component.onCompleted: place()

    Item {
        id: slot
        width: grid.width
        onChildrenChanged: grid.watch()
    }

    /** The cards now in the grid, each placed again when it grows or hides. */
    property var watched: []
    /** A Repeater among the cards is not a card. */
    function watch() {
        if (!grid || !slot) return
        const cards = []
        for (const c of slot.children) if (c && c.hasOwnProperty("implicitHeight") && !Theme.isRepeater(c)) cards.push(c)
        for (const c of cards) {
            if (watched.indexOf(c) >= 0) continue
            c.implicitHeightChanged.connect(grid.place)
            c.visibleChanged.connect(grid.place)
            if (c.hasOwnProperty("span")) c.spanChanged.connect(grid.place)
        }
        // Cards gone with a Repeater's reload are let go.
        watched = cards
        // Its place among the cards, for the stagger.
        cards.forEach((c, n) => { if (c.hasOwnProperty("index") && c.index !== n) c.index = n })
        place()
    }

    // Let go of the cards first, so one going away with the grid doesn't ask a grid already gone to place it.
    Component.onDestruction: {
        for (const c of watched) {
            if (!c) continue
            c.implicitHeightChanged.disconnect(grid.place)
            c.visibleChanged.disconnect(grid.place)
            if (c.hasOwnProperty("span")) c.spanChanged.disconnect(grid.place)
        }
    }

    /** The cards placed last time, and the width they were placed at: only those glide, and not while the width changes. */
    property var placed: []
    property real placedWidth: 0

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
        const cards = []
        for (const c of slot.children) {
            if (!c || !c.visible || Theme.isRepeater(c)) continue
            cards.push(c)
            n += c.span === "row" ? 1 : Math.max(1, Math.round(Number(c.span) || 1))
        }
        shown = n
        const glide = placedWidth === grid.width
        const step = grid.cell + grid.gap
        const across = s => s * grid.cell + (s - 1) * grid.gap
        // How many columns a card takes: its `span` (1, 2, or "row" for all), never more than there are.
        const spanOf = c => c.span === "row" ? grid.columns : Math.max(1, Math.min(grid.columns, Math.round(Number(c.span) || 1)))
        // Placed again somewhere else, a card glides there (Card.glide); not the first time, nor while the width changes.
        const put = (c, x, y, w) => {
            if (glide && placed.indexOf(c) >= 0 && typeof c.glide === "function" && (c.x !== x || c.y !== y)) c.glide(c.x - x, c.y - y)
            c.width = w
            c.x = x
            c.y = y
        }
        let bottom = 0
        if (masonry) {
            // Each card where the columns it takes are lowest, the leftmost of those level.
            const heights = Array(grid.columns).fill(0)
            for (const c of cards) {
                const s = spanOf(c)
                let at = 0, top = Infinity
                for (let k = 0; k + s <= grid.columns; k++) {
                    const t = Math.max(...heights.slice(k, k + s))
                    if (t < top - 0.5) { at = k; top = t }
                }
                put(c, at * step, top, across(s))
                for (let k = at; k < at + s; k++) heights[k] = top + c.implicitHeight + grid.gap
                bottom = Math.max(bottom, top + c.implicitHeight)
            }
        } else {
            let col = 0, y = 0, rowHeight = 0
            for (const c of cards) {
                const s = spanOf(c)
                // A card wider than what is left of the row starts the next.
                if (col > 0 && col + s > grid.columns) {
                    col = 0
                    y += rowHeight + grid.gap
                    rowHeight = 0
                }
                put(c, col * step, y, across(s))
                rowHeight = Math.max(rowHeight, c.implicitHeight)
                bottom = y + rowHeight
                col += s
                if (col >= grid.columns) {
                    col = 0
                    y += rowHeight + grid.gap
                    rowHeight = 0
                }
            }
        }
        placed = cards
        placedWidth = grid.width
        grid.implicitHeight = bottom
        placing = false
        if (again) { again = false; Qt.callLater(grid.place) }
    }
}

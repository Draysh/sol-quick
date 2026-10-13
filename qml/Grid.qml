import QtQuick

/*
    Cards in an auto-fit grid: as many columns of at least `min` as fit
    (never more than there are cards showing, so a short set fills the row),
    24 px apart, each row as tall as its tallest card and every card
    starting at the top of its row. Put it in a Screen; give the cards
    nothing but their content. A card may take two columns or the whole
    row (`Card.span`). With `masonry`, each card goes into the shortest
    column instead, so cards of very different heights leave no holes.
    A pair (a card across two columns beside the cards that fill the rest
    of its band) ends level: the shorter ones are drawn as tall as the
    tallest, so their feet meet on one line.
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
    /** The cards drawn taller than their own height last time, to end level with their pair. */
    property var stretched: []
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
        const put = (c, x, y, w, h) => {
            if (glide && placed.indexOf(c) >= 0 && typeof c.glide === "function" && (c.x !== x || c.y !== y)) c.glide(c.x - x, c.y - y)
            c.width = w
            c.x = x
            c.y = y
            // Drawn taller to end level with its pair, or back to its own height; a card that can
            // centres what it holds in the room (`spare`).
            if (h > c.implicitHeight + 0.5) c.height = h
            else if (stretched.indexOf(c) >= 0) c.height = Qt.binding(() => c.implicitHeight)
            if (c.hasOwnProperty("spare")) c.spare = Math.max(0, h - c.implicitHeight)
        }
        // Where each card goes, `tall` holding the heights of the cards drawn taller than their own.
        const lay = tall => {
            const out = []
            const heightOf = c => tall.has(c) ? tall.get(c) : c.implicitHeight
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
                    out.push({ c: c, x: at * step, y: top, s: s })
                    for (let k = at; k < at + s; k++) heights[k] = top + heightOf(c) + grid.gap
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
                    out.push({ c: c, x: col * step, y: y, s: s })
                    rowHeight = Math.max(rowHeight, c.implicitHeight)
                    col += s
                    if (col >= grid.columns) {
                        col = 0
                        y += rowHeight + grid.gap
                        rowHeight = 0
                    }
                }
            }
            return out
        }
        // A pair: cards starting on one line that fill every column between them, one across
        // more than one. They end level, as tall as the tallest; masonry then places the rest
        // under them again (twice at most: a band found the second time is rare).
        const pairs = spots => {
            const tall = new Map()
            const bands = {}
            for (const p of spots) (bands[Math.round(p.y)] = bands[Math.round(p.y)] || []).push(p)
            for (const key in bands) {
                const band = bands[key]
                if (band.length < 2 || !band.some(p => p.s > 1 && p.s < grid.columns)) continue
                if (band.reduce((n, p) => n + p.s, 0) !== grid.columns) continue
                const h = Math.max(...band.map(p => p.c.implicitHeight))
                for (const p of band) if (p.c.implicitHeight < h - 0.5) tall.set(p.c, h)
            }
            return tall
        }
        let tall = new Map()
        let spots = lay(tall)
        for (let pass = 0; pass < 2; pass++) {
            const next = pairs(spots)
            if (next.size === tall.size && [...next].every(([c, h]) => tall.get(c) === h)) break
            tall = next
            spots = lay(tall)
        }
        let bottom = 0
        for (const p of spots) {
            const h = tall.has(p.c) ? tall.get(p.c) : p.c.implicitHeight
            put(p.c, p.x, p.y, across(p.s), h)
            bottom = Math.max(bottom, p.y + h)
        }
        stretched = [...tall.keys()]
        placed = cards
        placedWidth = grid.width
        grid.implicitHeight = bottom
        placing = false
        if (again) { again = false; Qt.callLater(grid.place) }
    }
}

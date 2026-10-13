import QtQuick

/*
    Cards in an auto-fit grid: as many columns of at least `min` as fit
    (never more than the cards beside each other need, so a short set fills
    the row; a card across the whole row doesn't count), 24 px apart, each
    row as tall as its tallest card and every card starting at the top of
    its row. Put it in a Screen; give the cards nothing but their content.
    A card may take two columns or the whole row (`Card.span`). With
    `masonry`, each card goes into the shortest column instead, so cards of
    very different heights leave no holes.
    Cards side by side end level where it reads as one band: a pair (a card
    across two columns beside the cards that fill the rest of its band)
    always, and any cards starting on one line whose feet nearly meet
    (`level`): the shorter are drawn as tall as the tallest among them, so
    their feet meet on one line (in a pair what a card holds sits in the middle of the
    room, else at its top). A card much shorter than its neighbour keeps
    its own height rather than a stretch of empty glass.
    When the grid places them again (a card grows, hides or shows), cards
    glide to their new place. They arrive in the world's beat, a stagger
    apart, and the first (the lead) lights its brackets as it lands.

        Grid { Card { title: "Log"; … } Card { title: "Sol"; … } }
        Grid { masonry: true; Card { title: "Today"; span: 2; … } Card { … } }
        Grid { even: true; Repeater { model: stations; delegate: StationCard { … } } }
*/
Item {
    id: grid

    property real min: 300
    property real gap: Theme.s4
    /** Each card into the shortest column, not row by row: for pages of cards of very different heights. */
    property bool masonry: false
    /** How far apart the feet of cards starting on one line may be and still be drawn level (never more than a quarter of the taller's height); 0 keeps each its own height, but for a pair. */
    property real level: Theme.s6 * 2
    default property alias cards: slot.data

    // Set by place(), from the cards that show.
    implicitHeight: 0
    width: parent ? parent.width : 600

    /** How many columns of at least `min` the width holds. */
    readonly property int fit: Math.max(1, Math.floor((width + gap) / (min + gap)))
    /** The columns the cards that show would take side by side, those across the whole row left out (set by place()): a short set fills the row instead of leaving empty columns. */
    property int shown: 0
    /** As many cards in every row as it can: four that would go three and one go two and two, each a little wider (for a few cards of one kind, not a wall of posters). */
    property bool even: false
    readonly property int columns: Math.max(1, even && shown > 0 ? Math.ceil(shown / Math.ceil(shown / fit)) : Math.min(fit, shown > 0 ? shown : fit))
    readonly property real cell: (width - gap * (columns - 1)) / columns

    onCellChanged: place()
    onGapChanged: place()
    onMasonryChanged: place()
    onLevelChanged: place()
    onEvenChanged: place()
    // Its page draws its columns as hairlines (a flavour's `grid`) from the widest grid on it.
    Component.onCompleted: { place(); const page = Theme.ruled ? Theme.screenOf(grid) : null; if (page) page.offerRuler(grid) }

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
        // Its place among the cards, for the stagger; the first is the lead, lit as it lands.
        cards.forEach((c, n) => {
            if (c.hasOwnProperty("index") && c.index !== n) c.index = n
            if (c.hasOwnProperty("lead") && c.lead !== (n === 0)) c.lead = n === 0
        })
        place()
    }

    // Let go of the cards first, so one going away with the grid doesn't ask a grid already gone to place it.
    Component.onDestruction: {
        const page = Theme.ruled ? Theme.screenOf(grid) : null
        if (page) page.dropRuler(grid)
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
        // One across the whole row takes whatever there is, so only the others count.
        let n = 0
        const cards = []
        for (const c of slot.children) {
            if (!c || !c.visible || Theme.isRepeater(c)) continue
            cards.push(c)
            if (c.span !== "row") n += Math.max(1, Math.round(Number(c.span) || 1))
        }
        shown = n
        const glide = placedWidth === grid.width
        const step = grid.cell + grid.gap
        const across = s => s * grid.cell + (s - 1) * grid.gap
        // How many columns a card takes: its `span` (1, 2, or "row" for all), never more than there are.
        const spanOf = c => c.span === "row" ? grid.columns : Math.max(1, Math.min(grid.columns, Math.round(Number(c.span) || 1)))
        // Placed again somewhere else, a card glides there (Card.glide); not the first time, nor while the width changes.
        const put = (c, x, y, w, h, middle) => {
            if (glide && placed.indexOf(c) >= 0 && typeof c.glide === "function" && (c.x !== x || c.y !== y)) c.glide(c.x - x, c.y - y)
            c.width = w
            c.x = x
            c.y = y
            // Drawn taller to end level, or back to its own height. Beside its pair a card that can
            // centres what it holds in the room (`spare`); a card a little shorter than its
            // neighbours keeps what it holds at the top, under its title like theirs.
            if (h > c.implicitHeight + 0.5) c.height = h
            else if (stretched.indexOf(c) >= 0) c.height = Qt.binding(() => c.implicitHeight)
            if (c.hasOwnProperty("spare")) c.spare = middle ? Math.max(0, h - c.implicitHeight) : 0
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
        // Cards starting on one line end level, as tall as the tallest: a pair (they fill every
        // column between them, one across more than one) always, others when their feet nearly
        // meet. Masonry then places the rest under them again (a few times at most: a band
        // found later is rare).
        // Which of them are in a pair, to centre what they hold.
        let paired = new Set()
        const pairs = spots => {
            const tall = new Map()
            paired = new Set()
            const bands = {}
            for (const p of spots) (bands[Math.round(p.y)] = bands[Math.round(p.y)] || []).push(p)
            for (const key in bands) {
                const band = bands[key]
                if (band.length < 2) continue
                const pair = band.some(p => p.s > 1 && p.s < grid.columns) && band.reduce((n, p) => n + p.s, 0) === grid.columns
                const h = Math.max(...band.map(p => p.c.implicitHeight))
                for (const p of band) {
                    const own = p.c.implicitHeight
                    // In a pair, the tallest; else the tallest beside it whose foot is near its own.
                    let to = own
                    if (pair) { to = h; paired.add(p.c) }
                    else for (const q of band) { const t = q.c.implicitHeight; if (t > to && t - own <= Math.min(grid.level, t / 4)) to = t }
                    if (to > own + 0.5) tall.set(p.c, to)
                }
            }
            return tall
        }
        let tall = new Map()
        let spots = lay(tall)
        for (let pass = 0; pass < 3; pass++) {
            const next = pairs(spots)
            if (next.size === tall.size && [...next].every(([c, h]) => tall.get(c) === h)) break
            tall = next
            spots = lay(tall)
        }
        let bottom = 0
        for (const p of spots) {
            const h = tall.has(p.c) ? tall.get(p.c) : p.c.implicitHeight
            put(p.c, p.x, p.y, across(p.s), h, paired.has(p.c))
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

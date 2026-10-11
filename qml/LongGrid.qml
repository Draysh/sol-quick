import QtQuick

/*
    Tiles in a grid as long as a library: as many columns of at least `min`
    as fit, every tile `tileHeight` tall, and only the tiles in sight (and a
    screen either side) made, each made once and used again as the page
    scrolls. The page scrolls it like anything else on it: it is as tall as
    all its rows. The delegate gets `modelData` and `index` and is `cell`
    wide and `tileHeight` tall; a tile that is a Settle arrives with
    `animated: grid.arrives(index)`, so the first screenful settles in and
    the rest is simply there.

        LongGrid { id: wall; model: page.shown; tileHeight: cell + 40
            delegate: Settle { required property var modelData; required property int index
                width: wall.cell; height: wall.tileHeight; animated: wall.arrives(index); … } }
*/
Item {
    id: grid

    /** The rows: an array (or any model a GridView takes). */
    property var model: []
    property Component delegate: null
    property real min: 150
    property real gapX: Theme.s4
    property real gapY: Theme.s5
    /** How tall a tile is (bind it to `cell`, the tile's width, for a square cover over two lines). */
    property real tileHeight: cell
    /** Whole rows only, at most this many (0: every row). */
    property int rows: 0

    readonly property int columns: Math.max(1, Math.floor((width + gapX) / (min + gapX)))
    /** A tile's width. */
    readonly property real cell: (width - gapX * (columns - 1)) / columns
    readonly property int count: view.count
    /** Whether the tile at `index` settles in: only on the first screenful, while the grid first fills. */
    function arrives(index) { return !settled && index < firstScreen }

    readonly property int lines: Math.ceil(view.count / columns)
    implicitHeight: lines > 0 ? lines * (tileHeight + gapY) - gapY : 0
    width: parent ? parent.width : 600

    property bool settled: false
    readonly property int firstScreen: columns * (Math.ceil(Math.max(view.height, 600) / (tileHeight + gapY)) + 1)
    Timer { id: settling; interval: Theme.delay(grid.firstScreen) + Theme.settle; onTriggered: grid.settled = true }
    onCountChanged: if (count > 0 && !settled && !settling.running) settling.start()

    property var letGo: null
    Component.onCompleted: letGo = Theme.scrollWith(grid, view)
    Component.onDestruction: if (letGo) letGo()

    GridView {
        id: view
        width: grid.width + grid.gapX + 0.5
        interactive: false
        reuseItems: true
        currentIndex: -1
        cacheBuffer: Math.max(0, height)
        cellWidth: grid.cell + grid.gapX
        cellHeight: grid.tileHeight + grid.gapY
        model: grid.rows > 0 && Array.isArray(grid.model) ? grid.model.slice(0, grid.columns * grid.rows) : grid.model
        delegate: grid.delegate
    }
}

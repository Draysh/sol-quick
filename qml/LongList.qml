import QtQuick

/*
    Rows in a list as long as a library, each as tall as it is: only the
    rows in sight (and a screen either side) are made, each used again for
    another row as the page scrolls. The page scrolls it like anything else
    on it: it is as tall as all its rows, those not made yet reckoned at
    the height of the ones made so far (a row made later that turns out
    taller or shorter moves what is below it, and the page keeps what
    shows in place). The delegate gets `modelData` and `index` and is
    `width` wide, as tall as it says; a row that is a Settle arrives with
    `animated: list.arrives(index)`, so the first screenful settles in and
    the rest is simply there.

        LongList { id: rows; model: page.tracks
            delegate: Settle { required property var modelData; required property int index
                width: rows.width; height: 46; animated: rows.arrives(index); … } }
*/
Item {
    id: list

    /** The rows: an array. */
    property var model: []
    property Component delegate: null
    property real spacing: 0
    /** How tall a row not made yet is reckoned, until some are. */
    property real estimate: 48

    readonly property int count: rows.length
    /** Whether the row at `index` settles in: only on the first screenful, while the list first fills. */
    function arrives(index) { return !settled && index < firstScreen }

    width: parent ? parent.width : 600
    implicitHeight: total

    // ---- The rows' places ------------------------------------------------------
    readonly property var rows: Array.isArray(model) ? model : []
    /** Each row's height once made (undefined before). */
    property var heights: []
    /** Where each row starts, and the whole height: kept in step with `heights`. */
    property var tops: []
    property real total: 0
    function reckon() {
        let made = 0, sum = 0
        for (let i = 0; i < rows.length; i++) if (heights[i] !== undefined) { made++; sum += heights[i] }
        const guess = made > 0 ? sum / made : estimate
        const t = new Array(rows.length)
        let y = 0
        for (let i = 0; i < rows.length; i++) { t[i] = y; y += (heights[i] !== undefined ? heights[i] : guess) + (i < rows.length - 1 ? spacing : 0) }
        tops = t
        total = rows.length > 0 ? y : 0
    }
    /** The first row whose bottom is below `y`. */
    function rowAt(y) {
        let lo = 0, hi = rows.length - 1
        while (lo < hi) { const mid = (lo + hi) >> 1; if (tops[mid + 1] <= y) lo = mid + 1; else hi = mid }
        return lo
    }

    // ---- The rows made -----------------------------------------------------------
    property var shown: ({})      // index → item
    property var spare: []        // items put by, for another row
    property var flick: null
    property bool settled: false
    /** About a screenful of rows. */
    readonly property int firstScreen: Math.ceil(Math.max(flick ? flick.height : 0, 600) / Math.max(24, estimate))
    Timer { id: settling; interval: Theme.delay(list.firstScreen) + Theme.settle; onTriggered: list.settled = true }

    function fill() {
        if (!delegate) return
        let from = 0, to = rows.length - 1
        if (flick && flick.height > 0 && rows.length > 0) {
            const top = list.mapToItem(flick.contentItem, 0, 0).y
            const seenTop = flick.contentY - top - flick.height, seenBottom = flick.contentY - top + 2 * flick.height
            if (seenBottom < 0 || seenTop > total) { from = 0; to = -1 }
            else { from = rowAt(Math.max(0, seenTop)); to = rowAt(Math.min(total, seenBottom)) }
        }
        // Rows gone out of sight are put by.
        const keep = {}
        for (const k in shown) {
            const i = Number(k), item = shown[k]
            if (i >= from && i <= to && i < rows.length) keep[k] = item
            else { item.visible = false; spare.push(item) }
        }
        shown = keep
        for (let i = from; i <= to; i++) {
            let item = shown[i]
            if (!item) {
                item = spare.pop()
                if (item) { item.index = i; item.modelData = rows[i]; item.visible = true }
                else {
                    item = delegate.createObject(list, { index: i, modelData: rows[i] })
                    if (!item) return
                    item.heightChanged.connect(() => list.measured(item))
                }
                shown[i] = item
            } else if (item.modelData !== rows[i]) item.modelData = rows[i]
            item.y = tops[i]
            list.measured(item)
        }
    }
    /** A row's height is known (or changed): what is below it moves; what shows stays in place. */
    function measured(item) {
        if (!item.visible) return
        const i = item.index
        if (heights[i] === item.height) return
        const before = heights[i] !== undefined ? heights[i] : null
        heights[i] = item.height
        if (flick && before !== null && list.mapToItem(flick.contentItem, 0, tops[i] + before).y <= flick.contentY) flick.contentY += item.height - before
        Qt.callLater(list.relayout)
    }
    function relayout() {
        reckon()
        for (const k in shown) shown[k].y = tops[Number(k)]
        fill()
    }
    function restart() {
        heights = []
        reckon()
        fill()
        if (rows.length > 0 && !settled && !settling.running) settling.start()
    }
    onRowsChanged: restart()
    onWidthChanged: Qt.callLater(list.restart)
    onSpacingChanged: Qt.callLater(list.relayout)

    Component.onCompleted: {
        flick = Theme.flickableOf(list)
        if (flick) for (const s of [flick.contentYChanged, flick.heightChanged, flick.contentHeightChanged, list.yChanged]) s.connect(list.fill)
        restart()
    }
    Component.onDestruction: if (flick) for (const s of [flick.contentYChanged, flick.heightChanged, flick.contentHeightChanged, list.yChanged]) s.disconnect(list.fill)
}

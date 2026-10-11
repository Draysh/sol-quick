import QtQuick

/*
    A list sorted and filtered for a page, once per change rather than on
    every binding that reads it: sorted again only when the rows or the
    order change, filtered again a moment after the typing stops. `shown`
    is the result, for a LongGrid or a LongList.

        Sift { id: sift; rows: page.albums; order: (a, b) => a.name.localeCompare(b.name)
            words: filterField.text; text: a => a.name + "\n" + a.artist }
        LongGrid { model: sift.shown; … }
*/
QtObject {
    id: sift

    /** Every row. */
    property var rows: []
    /** How two rows compare, as for `Array.sort`; null keeps them as they come. */
    property var order: null
    /** What a row is found by, as words (`a => a.name + "\n" + a.artist`); matched without case. */
    property var text: row => String(row)
    /**
        The page's own choices (a status, a genre): `row => bool`, true to
        keep it. Filtered again when it changes, so bind it to a new
        function naming what it reads: `keep: { const s = page.status; return i => s === "all" || i.status === s }`.
    */
    property var keep: null
    /** The words typed: rows whose text holds them show. */
    property string words: ""
    /** How long the typing rests before the rows are filtered again, in ms. */
    property int pause: 120

    /** The rows that show, sorted. */
    property var shown: []
    /** The words `shown` was filtered by. */
    property string shownFor: ""

    // Sorted, with each row's words in lower case beside it, once per change of rows or order.
    property var sorted: []
    property var haystacks: []
    function sort() {
        const list = (rows || []).slice()
        if (order) list.sort(order)
        sorted = list
        haystacks = list.map(r => String(text(r)).toLowerCase())
        filter()
    }
    function filter() {
        const q = words.trim().toLowerCase()
        const out = []
        for (let i = 0; i < sorted.length; i++) {
            const r = sorted[i]
            if ((q === "" || haystacks[i].indexOf(q) >= 0) && (!keep || keep(r))) out.push(r)
        }
        shownFor = words.trim()
        shown = out
    }

    onRowsChanged: Qt.callLater(sift.sort)
    onOrderChanged: Qt.callLater(sift.sort)
    onTextChanged: Qt.callLater(sift.sort)
    onKeepChanged: Qt.callLater(sift.filter)
    // Filtered again once the typing rests.
    onWordsChanged: rest.restart()
    property Timer rest: Timer { interval: sift.pause; onTriggered: sift.filter() }
    Component.onCompleted: sort()
}

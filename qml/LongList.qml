import QtQuick

/*
    Rows in a list as long as a library, each as tall as it is: only the
    rows in sight (and a screen either side) are made, each made once and
    used again as the page scrolls. The page scrolls it like anything else
    on it: it is as tall as all its rows (reckoned from the rows made so
    far while it is long). The delegate gets `modelData` and `index` and
    is `width` wide; a row that is a Settle arrives with `animated:
    list.arrives(index)`, so the first screenful settles in and the rest is
    simply there.

        LongList { id: rows; model: page.tracks
            delegate: Settle { required property var modelData; required property int index
                width: rows.width; height: 46; animated: rows.arrives(index); … } }
*/
Item {
    id: list

    /** The rows: an array (or any model a ListView takes). */
    property var model: []
    property Component delegate: null
    property real spacing: 0

    readonly property int count: view.count
    /** Whether the row at `index` settles in: only on the first screenful, while the list first fills. */
    function arrives(index) { return !settled && index < firstScreen }

    implicitHeight: view.count > 0 ? view.contentHeight : 0
    width: parent ? parent.width : 600

    property bool settled: false
    /** About a screenful of rows: as many as fit at 40 px each. */
    readonly property int firstScreen: Math.ceil(Math.max(view.height, 600) / 40)
    Timer { id: settling; interval: Theme.delay(list.firstScreen) + Theme.settle; onTriggered: list.settled = true }
    onCountChanged: if (count > 0 && !settled && !settling.running) settling.start()

    property var letGo: null
    Component.onCompleted: letGo = Theme.scrollWith(list, view)
    Component.onDestruction: if (letGo) letGo()

    ListView {
        id: view
        width: list.width
        interactive: false
        reuseItems: true
        currentIndex: -1
        cacheBuffer: Math.max(0, height)
        spacing: list.spacing
        model: list.model
        delegate: list.delegate
    }
}

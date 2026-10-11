import QtQuick
import Sol.Design

/*
    A picture (a poster, a cover, a backdrop, a logo), `ratio` wide over
    high, from an address (`url`) or fetched once to disk through a world's
    PictureStore (`key` in `store`). A quiet panel and the name sit in its
    place while it comes or when there is none. One already on disk shows
    at once, quickly; one that has to be fetched fades in slowly. A file
    known from an earlier run that has gone since is fetched again, once.
    Its corners are `Theme.radiusM`, cut in a shader (Rounded), so a wall
    of them costs no more to scroll than square ones.

        Picture { url: Titan.art(pick.poster); name: pick.name; width: 92 }
        Picture { store: Saturn.pictures; key: Saturn.artPath(entry.poster); name: entry.name; width: 148 }
        Picture { store: Neptune.covers; key: album.cover; ratio: 1; outline: true; animated: big }
*/
Item {
    id: root

    /** The address to show, when there is no store: `https://…` or `file://…`. */
    property string url: ""
    /** What to ask `store` for: the picture's key there. */
    property string key: ""
    property PictureStore store: null
    /** The name, in its place while it comes or when there is none. */
    property string name: ""
    /** How many lines of the name show, at most. */
    property int nameLines: 4
    /** Width over height: 2:3 for a poster, 1 for an album, 16:9 for a still. */
    property real ratio: 2 / 3
    /** Fills its place, cut to fit; off, it shows whole (a logo), with no panel behind it once here. */
    property bool crop: true
    /** A hairline around it (brighter while `hovered`). */
    property bool outline: false
    /** Its corners; 0 for a square picture (one that fills a panel shaped by something else). */
    property real radius: Theme.radiusM
    /** Lifts a touch while `hovered`; the caller says when it is. */
    property bool lift: false
    property bool hovered: false
    /** Dimmed and grey, for something already seen. */
    property bool dim: false
    /** Moving pictures move (an animated cover): only where one picture fills the view. */
    property bool animated: false
    /** How wide it is decoded, in pixels: twice its width, within reason. */
    property real sourceWidth: Math.min(1280, Math.max(342, Math.ceil(width * 2)))
    property bool mipmap: true
    /** How long it takes to fade in: slowly when it had to be fetched, quickly from disk. */
    property int fadeIn: fetched ? Theme.rise : Theme.lock

    readonly property Image image: animated ? moving : still
    readonly property bool ready: image.status === Image.Ready
    /** Drawn through Rounded: a cropped picture with corners (one that only fits, a logo, has no ground to round). */
    readonly property bool rounded: radius > 0 && crop
    /** The address being shown: `url`, or what the store gave for `key`; "" while it comes. */
    property string shown: ""
    /** It had to be fetched (from the store, or from the network): it fades in slowly. */
    property bool fetched: false
    /** Asked of the store, and not answered yet. */
    property bool coming: false

    implicitWidth: 100
    implicitHeight: width / ratio
    height: width / ratio
    // A square picture's lift stays inside it; a rounded one zooms inside its own shape.
    clip: !rounded

    onUrlChanged: fetch()
    onKeyChanged: fetch()
    onStoreChanged: fetch()
    Component.onCompleted: fetch()
    function fetch() {
        retried = ""
        coming = false
        if (!store) {
            shown = url
            fetched = /^https?:/.test(url)
            return
        }
        const k = key, from = store
        shown = from.known(k)
        fetched = shown === "" && k !== ""
        // Only the answer to what is asked now, not to a key asked before.
        coming = fetched
        if (fetched) from.get(k).then(u => { if (k === root.key && from === root.store) { root.shown = u; root.coming = false } })
    }
    /** A file known from an earlier run may have gone since: asked for again, once. */
    property string retried: ""
    function missing() {
        if (image.status !== Image.Error || !store || shown === "" || retried === key) return
        const k = key, from = store
        retried = k
        from.lost(k)
        shown = ""
        coming = true
        from.get(k).then(u => { if (root.retried === k && k === root.key) { root.shown = u; root.coming = false } })
    }

    // The quiet panel while it comes, and under a photograph; never behind a logo's
    // clear ground (a picture that isn't cropped), where it would show as a box.
    Rectangle {
        anchors.fill: parent
        visible: root.crop || !root.ready
        radius: root.radius
        color: Theme.surface
        border.width: root.outline ? 1 : 0
        border.color: root.hovered ? Theme.lineStrong : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }
    Text {
        anchors.fill: parent
        anchors.margins: Theme.s2
        // While a file on disk loads (a moment), the panel alone: no name flashing by.
        visible: !root.ready && (root.shown === "" || root.image.status === Image.Error || /^https?:/.test(root.shown))
        text: root.name
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: root.nameLines
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue
        color: Theme.textQuiet
    }
    Image {
        id: still
        anchors.fill: parent
        visible: !root.animated && !root.rounded
        source: root.animated ? "" : root.shown
        onStatusChanged: root.missing()
        fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        cache: true
        sourceSize.width: root.sourceWidth
        smooth: true
        mipmap: root.mipmap
        opacity: status === Image.Ready ? (root.dim ? 0.45 : 1) : 0
        Behavior on opacity { NumberAnimation { id: stillIn; duration: root.fadeIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        scale: root.lift && root.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }
    AnimatedImage {
        id: moving
        anchors.fill: parent
        visible: root.animated && !root.rounded
        source: root.animated ? root.shown : ""
        onStatusChanged: root.missing()
        fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: root.sourceWidth
        smooth: true
        opacity: status === Image.Ready ? (root.dim ? 0.45 : 1) : 0
        Behavior on opacity { NumberAnimation { id: movingIn; duration: root.fadeIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        scale: root.lift && root.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }
    // On its way: asked of the store, loading, or fading in.
    Settling { when: root.coming || root.image.status === Image.Loading || stillIn.running || movingIn.running }
    // The picture itself, with its corners: the image above stays hidden and lends it its
    // texture, fade and lift.
    Rounded {
        anchors.fill: parent
        visible: root.rounded
        image: root.image
        radius: root.radius
        zoom: root.image.scale
        opacity: root.image.opacity
    }
}

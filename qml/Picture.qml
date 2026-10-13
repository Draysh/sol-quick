import QtQuick
import Sol.Design

/*
    A picture (a poster, a cover, a backdrop, a logo), `ratio` wide over
    high, from an address (`url`) or fetched once to disk through a world's
    PictureStore (`key` in `store`). A quiet panel and the name sit in its
    place while it comes; when there is none, a poster of its own, laid
    out by the name. One already on disk shows
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
    /** The character on the card shown when there is no picture; "" for the name's or the flavour's. */
    property string glyph: ""
    /** What chooses that character and its light when the name is not given (it shows beside the picture): an album's name. */
    property string seed: ""
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
    /** There is no picture to show (none given, or it couldn't be had): the card stands in. */
    readonly property bool absent: !ready && !coming && (shown === "" || image.status === Image.Error)
    /** Each flavour's characters for a card without its picture. */
    readonly property var glyphs: ({ dusk: "映夜星夢空光", shrine: "字言詩心花道", neon: "音雨夜光声街", summer: "空夏雲風日緑" })
    readonly property int nameHash: { let h = 0; for (const ch of (name !== "" ? name : seed)) h = (h * 31 + ch.charCodeAt(0)) % 9973; return h }
    readonly property string cardGlyph: {
        if (glyph !== "") return glyph
        const jp = /[\u3040-\u30ff\u3400-\u9fff]/.exec(name !== "" ? name : seed)
        if (jp) return jp[0]
        const set = glyphs[Theme.hud.motif] || glyphs.dusk
        return set.charAt(nameHash % set.length)
    }
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
    // No picture: a poster of its own in the world's colours, laid out by the name (`seed`), so a
    // wall of them reads as designed rather than broken: its character set one of four ways (large
    // and cropped off an edge, standing in the middle, huge and faint behind, or high in a corner),
    // now and then a second one, the name's initials in the title face, a tone of its own within the
    // flavour's two lights, and the name at its foot.
    Item {
        id: poster
        anchors.fill: parent
        // Not for a logo (one shown whole): its page says the name instead.
        visible: root.absent && root.crop
        clip: true
        readonly property int h: root.nameHash
        readonly property int layout: h % 4
        readonly property real side: Math.min(root.width, root.height)
        /** How far between the two lights its tone is, and how strong. */
        readonly property real mix: (h % 7) / 6
        readonly property color light: Qt.tint(Theme.artAccent, Theme.tint(Theme.artSecond, poster.mix))
        readonly property bool big: root.width >= 80
        /** The name's initials (Latin), two at most: "Signal Fires" → "SF". */
        readonly property string initials: {
            const name = root.name !== "" ? root.name : root.seed
            if (Theme.hasJp(name)) return ""
            return name.split(/[\s\-:·]+/).filter(w => /^[A-Za-z0-9]/.test(w)).slice(0, 2).map(w => w.charAt(0).toUpperCase()).join("")
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: poster.h % 3 === 0 ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0; color: Theme.tint(poster.light, 0.1 + 0.12 * ((poster.h >> 3) % 3) / 2) }
                GradientStop { position: 1; color: Theme.tint(Theme.hud.dim || Theme.hud.ground, 0.9) }
            }
            border.width: 1
            border.color: root.hovered ? Theme.lineStrong : Theme.line
        }
        // The character: its size, place and strength by the layout.
        Text {
            id: glyphText
            text: root.cardGlyph
            readonly property real size: Math.max(12, poster.side * [1.05, 0.5, 1.5, 0.42][poster.layout])
            font.family: Theme.titleFace(size); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(size)
            font.pixelSize: size
            color: Theme.tint(poster.layout === 2 ? Theme.artBright : poster.light, [0.5, 0.85, 0.16, 0.9][poster.layout])
            x: [root.width - width * 0.78, (root.width - width) / 2, -width * 0.18, root.width - width - Theme.s2][poster.layout]
            y: [root.height - height * 0.86, (root.height - height) / 2 - (cardName.visible ? cardName.height / 2 : 0), -height * 0.12, Theme.s2][poster.layout]
        }
        // Now and then a second, small and solid, where the first leaves room.
        Text {
            visible: poster.big && poster.h % 5 === 0 && poster.layout !== 1
            readonly property string set: root.glyphs[Theme.hud.motif] || root.glyphs.dusk
            text: set.charAt((poster.h >> 2) % set.length) === root.cardGlyph ? set.charAt(((poster.h >> 2) + 1) % set.length) : set.charAt((poster.h >> 2) % set.length)
            readonly property real size: Math.max(12, poster.side * 0.22)
            font.family: Theme.titleFace(size); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(size)
            font.pixelSize: size
            color: Theme.tint(Theme.artSecond, 0.75)
            x: poster.layout === 3 ? Theme.s2 : root.width - width - Theme.s2
            y: poster.layout === 3 ? root.height * 0.42 : Theme.s2
        }
        // The initials, in the title face where they are large enough for it.
        Text {
            visible: poster.big && poster.initials !== "" && poster.layout !== 1
            text: poster.initials
            // Never small: two letters in a corner read as a mark only from about 24 px.
            readonly property real size: Math.max(24, Math.round(poster.side * 0.2))
            font.family: Theme.titleFace(size); font.features: Theme.titleFeatures; font.weight: Theme.titleWeight(size)
            font.pixelSize: size
            color: Theme.tint(Theme.artBright, 0.9)
            x: Theme.s2
            y: poster.layout === 3 ? root.height - height - (cardName.visible ? cardName.height + Theme.s2 : Theme.s2) : Theme.s2
        }
        // A thin rule in the light under the middle character (the plain layout's own mark).
        Rectangle {
            visible: poster.layout === 1 && poster.big
            width: poster.side * 0.18; height: 2
            x: (root.width - width) / 2
            y: glyphText.y + glyphText.height + Theme.s1
            color: Theme.tint(poster.light, 0.8)
        }
        Text {
            id: cardName
            // On a poster or a cover; a wide still has its title over it already.
            visible: root.width >= 80 && root.name !== "" && root.ratio <= 1
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: Theme.s2
            text: root.name
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: Math.min(2, root.nameLines)
            horizontalAlignment: poster.layout === 1 ? Text.AlignHCenter : Text.AlignLeft
            font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightName
            color: Theme.tint(Theme.artBright, 0.78)
            style: Text.Raised; styleColor: Theme.tint(Theme.hud.dim || Theme.hud.ground, 0.6)
        }
    }
    Text {
        anchors.fill: parent
        anchors.margins: Theme.s2
        // Coming from the network, the name in its place; while a file on disk loads (a moment),
        // the panel alone: no name flashing by.
        visible: !root.ready && (root.absent ? !root.crop : /^https?:/.test(root.shown))
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
        Behavior on opacity { NumberAnimation { id: stillIn; duration: root.fadeIn; easing: Theme.easeOut } }
        scale: root.lift && root.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.rise; easing: Theme.easeOut } }
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
        Behavior on opacity { NumberAnimation { id: movingIn; duration: root.fadeIn; easing: Theme.easeOut } }
        scale: root.lift && root.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.rise; easing: Theme.easeOut } }
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

import QtQuick

/*
    The colour of a picture: its average, pushed towards its most
    saturated side, so a cover or a backdrop can tint what sits near it.
    Reads a small copy of the image through a canvas; `color` settles when
    it is known, `Theme.world` until then.

        Tone { id: tone; source: cover.url }   …   color: Theme.tint(tone.color, 0.3)
*/
Item {
    id: tone

    property string source: ""
    property color color: Theme.world
    /** Up to four colours from the picture, by hue, the most present first. */
    property var picks: []
    /** The picture being read; let go once its colour is known. */
    property string reading: ""

    width: 24; height: 24
    visible: false

    onSourceChanged: read()
    Component.onCompleted: read()
    function read() {
        // Already on its way.
        if (reading !== "" && reading === source) return
        if (reading !== "") canvas.unloadImage(reading)
        if (source === "") { reading = ""; color = Theme.world; picks = []; return }
        reading = source
        canvas.loadImage(source)
        // Already decoded (here, or by an Image elsewhere): no imageLoaded comes.
        if (canvas.isImageLoaded(source)) canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Immediate
        onImageLoaded: requestPaint()
        onPaint: {
            const src = tone.reading
            if (src === "" || !isImageLoaded(src)) return
            const g = getContext("2d")
            g.clearRect(0, 0, width, height)
            g.drawImage(src, 0, 0, width, height)
            const px = g.getImageData(0, 0, width, height).data
            let r = 0, g2 = 0, b = 0, n = 0, best = 0, br = 0, bg = 0, bb = 0
            const buckets = []
            for (let i = 0; i < px.length; i += 4) {
                const cr = px[i], cg = px[i + 1], cb = px[i + 2]
                if (px[i + 3] < 128) continue
                const max = Math.max(cr, cg, cb), min = Math.min(cr, cg, cb)
                const sat = max === 0 ? 0 : (max - min) / max
                const light = max / 255
                // The most saturated pixel that is neither black nor white.
                const s = sat * (light > 0.2 && light < 0.95 ? 1 : 0.2)
                if (s > best) { best = s; br = cr; bg = cg; bb = cb }
                r += cr; g2 += cg; b += cb; n++
                // By hue, for the picks: the most saturated pixel of each hue, and how much of it there is.
                if (sat > 0.25 && light > 0.25) {
                    const c = Qt.rgba(cr / 255, cg / 255, cb / 255, 1)
                    const h = Math.floor(c.hsvHue * 12) % 12
                    if (!buckets[h] || sat > buckets[h].sat) buckets[h] = { sat: sat, color: c, n: (buckets[h] ? buckets[h].n : 0) + 1 }
                    else buckets[h].n++
                }
            }
            if (!n) { unloadImage(src); tone.reading = ""; return }
            tone.picks = buckets.filter(Boolean).sort((a, b) => b.n * b.sat - a.n * a.sat).slice(0, 4).map(x => Qt.lighter(x.color, 1.1))
            const avg = Qt.rgba(r / n / 255, g2 / n / 255, b / n / 255, 1)
            const vivid = Qt.rgba(br / 255, bg / 255, bb / 255, 1)
            // Halfway between: the picture's own colour, not its brightest speck.
            const mix = Qt.rgba((avg.r + vivid.r) / 2, (avg.g + vivid.g) / 2, (avg.b + vivid.b) / 2, 1)
            tone.color = Qt.lighter(mix, 1.15)
            unloadImage(src)
            tone.reading = ""
        }
    }
}

import QtQuick
import QtQuick.Effects

/*
    Real glass: whatever is behind this item (the app's pages), blurred and
    darkened, bending a little at the edges, for a menu, a notice, a hint
    or a dialog to sit on. It reads the window's `backdrop` (AppWindow
    sets it to the frame the pages live in), so it must sit outside it, on
    the window; without one it is just a dark panel. Put it first, under
    the content, filling the panel; with `radius`, it rounds with it (the
    shader cuts the corners, so nothing frosted shows past them).

        Rectangle { radius: Theme.radius; Glass { anchors.fill: parent; radius: Theme.radius } … }
*/
Item {
    id: glass

    property real blur: 0.7
    property color tint: Theme.tint(Theme.frost, Theme.light ? 0.86 : 0.74)
    /** How far in from the edge the picture bends, in pixels; 0 for flat glass. */
    property real bend: 14
    /** Its corners. */
    property real radius: 0
    /** What it blurs, when not the window's backdrop (pairing's scene). */
    property Item from: null
    readonly property Item behind: { if (from) return from; const w = Window.window as AppWindow; return w ? w.backdrop : null }

    /** The part of the backdrop right under the glass, however it got there. */
    function place() {
        if (!behind) return
        const a = glass.mapToItem(behind, 0, 0), b = glass.mapToItem(behind, glass.width, glass.height)
        picture.sourceRect = Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y))
    }
    // Anything above it moving, sliding or scaling (a notice in its stack,
    // a menu finding its place, a list dropping open) moves what it shows.
    property var watched: []
    function watch() {
        forget()
        const changes = []
        for (let it = glass; it; it = it.parent) {
            changes.push(it.xChanged, it.yChanged, it.scaleChanged)
            for (let i = 0; i < it.transform.length; i++) {
                const t = it.transform[i]
                for (const name of ["xChanged", "yChanged", "xScaleChanged", "yScaleChanged"]) if (t[name]) changes.push(t[name])
            }
        }
        for (const s of changes) s.connect(place)
        watched = changes
        Qt.callLater(place)
    }
    function forget() { for (const s of watched) s.disconnect(place); watched = [] }
    Component.onCompleted: watch()
    Component.onDestruction: forget()
    onBehindChanged: watch()
    onWidthChanged: place()
    onHeightChanged: place()

    ShaderEffectSource {
        id: picture
        anchors.fill: parent
        visible: false
        live: true
        sourceItem: glass.behind
        sourceRect: Qt.rect(0, 0, 0, 0)
    }
    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        source: picture
        blurEnabled: true
        blur: glass.blur
        blurMax: 32
        autoPaddingEnabled: false
        layer.enabled: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: !!glass.behind
        property variant source: blurred
        property vector2d size: Qt.vector2d(glass.width, glass.height)
        property real edge: glass.bend
        property real radius: glass.radius
        fragmentShader: "../shaders/glass.frag.qsb"
    }
    Rectangle { anchors.fill: parent; radius: glass.radius; color: glass.tint }
}

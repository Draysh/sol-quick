import QtQuick
import QtQuick.Effects

/*
    Real glass: whatever is behind this item (the app's pages), blurred and
    darkened, bending a little at the edges, for a menu, a notice, a hint
    or a dialog to sit on. It reads the window's `backdrop` (AppWindow
    sets it to the frame the pages live in); without one it is just a dark
    panel. Put it first, under the content, filling the panel.

        Rectangle { Glass { anchors.fill: parent } … }
*/
Item {
    id: glass

    property real blur: 0.7
    property color tint: Qt.rgba(0, 0, 0, 0.74)
    /** How far in from the edge the picture bends, in pixels; 0 for flat glass. */
    property real bend: 14
    readonly property Item behind: Window.window && Window.window.hasOwnProperty("backdrop") ? Window.window.backdrop : null

    function place() {
        if (!behind) return
        const p = glass.mapToItem(behind, 0, 0)
        source.sourceRect = Qt.rect(p.x, p.y, glass.width, glass.height)
    }
    // Anything above it moving (a notice in its stack, a menu finding its
    // place) moves what it shows.
    Component.onCompleted: {
        for (let it = glass; it && it !== behind; it = it.parent) { it.xChanged.connect(place); it.yChanged.connect(place) }
        Qt.callLater(place)
    }
    onWidthChanged: place()
    onHeightChanged: place()

    ShaderEffectSource {
        id: source
        anchors.fill: parent
        visible: false
        live: true
        recursive: true
        sourceItem: glass.behind
        sourceRect: Qt.rect(0, 0, 0, 0)
    }
    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        source: source
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
        fragmentShader: "../shaders/glass.frag.qsb"
    }
    Rectangle { anchors.fill: parent; color: glass.tint }
}

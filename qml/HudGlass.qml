import QtQuick
import QtQuick.Effects

/*
    Glass: the window's ground (the still behind the pages, `Shell.ground`)
    blurred under a panel, tinted in the world's dark (thinner at the top,
    so the art shows through), a sheen and a 1 px highlight along its top
    edge, a hairline just inside its edge, and corners cut away at 45°
    instead of rounded. The blur is the Shell's one (`groundBlur`, made
    once for the whole window), so a page may hold many panels for the cost
    of one: each only reads the part under it, found by its shader from
    where the panel is drawn on the window (`hud.vert`), so a page of
    panels scrolls, slides and settles without a line of script per panel
    or per frame. (It must be drawn straight into the window, not inside a
    `layer`.) The world's motif rides on it
    (`Theme.flavour`: Mercury's waves in the corners, Neptune's neon edge
    and scanlines, Terra's daylight), drawn by the same shader. A flavour
    with `surface: "panel"` has panels instead: the tint near-opaque and
    even, no sheen, a hairline in the light.

    Put it first, under the content, filling the panel; HudPanel, Card and
    the sidebar's rail stand on it. Without a ground (the art not here
    yet) it is the tint alone. `from` blurs another item live instead
    (a menu over the pages blurs the window's `backdrop`): for overlays
    that come and go, never for what sits on a page.

        Item { HudGlass { anchors.fill: parent; cuts: [0, Theme.hudCut, 0, 0] } … }
*/
Item {
    id: glass

    /** How much each corner loses, in pixels: top-left, top-right, bottom-right, bottom-left. */
    property var cuts: [0, Theme.hudCut, 0, 0]
    property color tint: Theme.hudGlass
    property color line: Theme.hudLine
    /** The world's motif on it ("dusk", "shrine", "neon", "summer"), "washi" for a sheet of paper (give it a paper `tint`), "panel" for a flat panel with a hairline in the light (the flavour's `surface: "panel"`), or "" for plain glass. */
    property string motif: Theme.panels ? "panel" : Theme.hud.motif
    /** The motif's light. */
    property color accent: Theme.hudAccent
    /** How lit its edge is, 0 to 1 (Neptune's neon brightens under the pointer). */
    property real glow: 0
    /** How much a live blur blurs (with `from`). */
    property real blur: 0.8
    /** Blurred live instead of the Shell's ground: another item (the window's `backdrop` under an overlay). */
    property Item from: null
    readonly property bool live: !!from
    readonly property Item shell: { const w = Window.window as AppWindow; return w ? w.shell : null }
    /** What it shows a part of: the item it blurs live, or the Shell's ground (whose blur is shared). */
    readonly property Item behind: live ? from : shell ? shell.ground : null
    readonly property Item blurred: live ? liveBlur : shell ? shell.groundBlur : null

    /** Live only: the part of what it blurs right under the glass, however it got there. */
    function place() {
        const b = behind
        if (!live || !b || b.width <= 0 || b.height <= 0) return
        const p = glass.mapToItem(b, 0, 0), q = glass.mapToItem(b, glass.width, glass.height)
        picture.sourceRect = Qt.rect(Math.min(p.x, q.x), Math.min(p.y, q.y), Math.abs(q.x - p.x), Math.abs(q.y - p.y))
    }
    // Live, anything above it moving (the menu it sits on sliding in) moves what it shows, as
    // Glass does. On the ground the shader finds its place itself: nothing to watch.
    property var watched: []
    function watch() {
        forget()
        if (!live) return
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
    onLiveChanged: watch()
    onParentChanged: watch()
    onWidthChanged: place()
    onHeightChanged: place()
    Connections { target: glass.live ? glass.behind : null; function onWidthChanged() { glass.place() } function onHeightChanged() { glass.place() } }

    // A live blur of its own, only for an overlay over something that moves (`from`).
    ShaderEffectSource {
        id: picture
        anchors.fill: parent
        visible: false
        live: true
        sourceItem: glass.live ? glass.from : null
        sourceRect: Qt.rect(0, 0, 0, 0)
    }
    MultiEffect {
        id: liveBlur
        anchors.fill: parent
        visible: false
        source: glass.live ? picture : null
        blurEnabled: true
        blur: glass.blur
        blurMax: 48
        autoPaddingEnabled: false
        layer.enabled: glass.live
    }
    ShaderEffect {
        id: effect
        anchors.fill: parent
        property variant source: glass.blurred ? glass.blurred : picture
        property vector2d size: Qt.vector2d(glass.width, glass.height)
        property vector4d cuts: Qt.vector4d(glass.cuts[0] || 0, glass.cuts[1] || 0, glass.cuts[2] || 0, glass.cuts[3] || 0)
        property color tint: Qt.rgba(glass.tint.r, glass.tint.g, glass.tint.b, 1)
        property real tintAlpha: glass.tint.a
        property color line: Qt.rgba(glass.line.r, glass.line.g, glass.line.b, 1)
        property real lineAlpha: glass.line.a
        property real glassy: glass.blurred ? 1 : 0
        // Live, the picture is the part under it already, all of it; on the ground, the shader finds
        // its part from where it is drawn on the window (the Shell's ground fills the window).
        property vector4d rect: Qt.vector4d(0, 0, 1, 1)
        property real screen: glass.live ? 0 : 1
        property real yUp: GraphicsInfo.api === GraphicsInfo.OpenGL ? 1 : 0
        property vector4d ground: Qt.vector4d(0, 0, 1, 1)
        property color accent: glass.accent
        property real motif: ({ shrine: 1, neon: 2, summer: 3, washi: 4, panel: 5 })[glass.motif] || 0
        property real glow: glass.glow
        vertexShader: "../shaders/hud.vert.qsb"
        fragmentShader: "../shaders/hud.frag.qsb"
    }
}

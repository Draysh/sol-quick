import QtQuick

/*
    A world, lit from one side, drawn on the GPU: the photograph clipped to
    a disc, a soft terminator opposite the light, and the limb glowing in
    the world's colour on the lit side. `disc` is the disc's diameter; the
    item is wider than that (the glow needs room) and centred on it.

        Body { world: "terra"; disc: 300; x: cx - disc / 2; y: cy - disc / 2 }
*/
Item {
    id: root

    property string world: "terra"
    property real disc: 200
    /** Where the light comes from, degrees clockwise from the top: the real sky's for the worlds that follow it, else the world's own. */
    property real light: sky ? sky.light : w.hero.light
    /** 0 is new, 1 is full; as `light`. */
    property real phase: sky ? sky.phase : w.hero.phase
    readonly property var sky: Worlds.skyOf(world)
    property bool animated: true

    readonly property var w: Worlds.get(world)
    readonly property real away_x: -Math.sin(light * Math.PI / 180)
    readonly property real away_y: Math.cos(light * Math.PI / 180)

    width: disc
    height: disc

    Image {
        id: photo
        source: root.w.image
        visible: false
        asynchronous: true
        mipmap: true
        sourceSize.width: 1200
    }

    ShaderEffect {
        id: shade
        width: root.disc * 1.7
        height: root.disc * 1.7
        x: -root.disc * 0.35
        y: -root.disc * 0.35
        fragmentShader: "../shaders/body.frag.qsb"
        property variant source: photo
        property vector2d away: Qt.vector2d(root.away_x, root.away_y)
        property real phase: Math.min(1, Math.max(0, root.phase))
        Behavior on phase { NumberAnimation { duration: Theme.rise; easing.type: Easing.InOutSine } }
        property color world: root.w.color
        property int mode: root.w.render === "star" ? 1 : root.w.render === "photo" ? 2 : 0
        property int effect: root.w.effect === "haze" ? 1 : root.w.effect === "split-rim" ? 2 : 0
        property real aspect: photo.status === Image.Ready && photo.implicitWidth > 0 ? photo.implicitHeight / photo.implicitWidth : 0.484
        property real time: 0
        property int live: root.w.live === "clouds" ? 1 : root.w.live === "corona" ? 2 : 0
        property real day: Theme.day ? 1 : 0
        supportsAtlasTextures: false
        // Alive: a second a second, while the window is awake and the body is
        // big enough to see it; it picks up where it stopped.
        // Only for a world that moves (clouds, a corona): a still one never asks for a frame.
        FrameAnimation { running: shade.live !== 0 && root.animated && root.disc >= 120 && Theme.alive && shade.visible; onTriggered: shade.time = (shade.time + frameTime) % 3600 }

        // A body comes up out of the dark, a touch closer as it brightens.
        opacity: root.animated ? 0 : 1
        scale: root.animated ? 0.97 : 1
        Component.onCompleted: if (root.animated) rise.start()
        ParallelAnimation {
            id: rise
            NumberAnimation { target: shade; property: "opacity"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shade; property: "scale"; to: 1; duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }
}

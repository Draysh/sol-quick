import QtQuick

/*
    A world, lit from one side, drawn on the GPU: the photograph on a
    sphere lit by a distant sun, a terminator opposite the light (soft where
    there is air), a night side nearly black, and, for
    a world with an atmosphere, a thin rim of it lit on the sunny limb.
    `disc` is the disc's diameter; the item is wider than that (the glow
    needs room) and centred on it.

        Body { world: "terra"; disc: 300; x: cx - disc / 2; y: cy - disc / 2 }
*/
Item {
    id: root

    property string world: "terra"
    property real disc: 200
    /** Where the light comes from, degrees clockwise from the top: the real sky's for the worlds that follow it, else the world's own. */
    property real light: sky ? sky.light : w.icon.light
    /** 0 is new, 1 is full; as `light`. */
    property real phase: sky ? sky.phase : w.icon.phase
    readonly property var sky: Worlds.skyOf(world)
    property bool animated: true
    /** How green the land is, 0 dry … 0.5 the photograph … 1 lush: a world with clouds only (Terra). `Worlds.setSurface` sets it for every body of a world. */
    property real green: surface ? surface.green : 0.5
    /** How much cloud, 0 clear … 0.5 the usual … 1 overcast; as `green`. */
    property real cloudy: surface ? surface.cloudy : 0.5
    readonly property var surface: Worlds.surfaces[world] || null
    /** How fast its clouds or corona move, 1 the usual, 0 still (no frames asked for): Neptune's storms speed up to the beat in vinyl mode. */
    property real pace: 1

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
        // Small (the sidebar, the bar), a body keeps at least a crescent, so a new moon still shows.
        property real phase: Math.min(1, Math.max(root.disc < 48 ? 0.2 : 0, root.phase))
        Behavior on phase { NumberAnimation { duration: Theme.rise; easing: Theme.easeInOut } }
        property color world: root.w.color
        property int mode: root.w.render === "star" ? 1 : root.w.render === "photo" ? 2 : 0
        property int effect: root.w.effect === "haze" ? 1 : 0
        // Where the disc is in the photograph, and the turn that brings the photograph's own
        // light (`fit.lit`, for a photograph that shows a terminator) round to this one.
        readonly property var fitted: root.w.fit || ({ x: 0.5, y: 0.5, r: 0.5 })
        property vector4d fit: Qt.vector4d(fitted.x, fitted.y, fitted.r, fitted.lit === undefined ? 0 : (root.light - fitted.lit) * Math.PI / 180)
        property real air: root.w.air || 0
        property real green: root.green
        property real cloudy: root.cloudy
        Behavior on green { NumberAnimation { duration: Theme.calm ? 0 : Theme.wash; easing: Theme.easeInOut } }
        Behavior on cloudy { NumberAnimation { duration: Theme.calm ? 0 : Theme.wash; easing: Theme.easeInOut } }
        property real aspect: photo.status === Image.Ready && photo.implicitWidth > 0 ? photo.implicitHeight / photo.implicitWidth : 0.484
        property real time: 0
        property int live: root.w.live === "clouds" ? 1 : root.w.live === "corona" ? 2 : 0
        // The shader's daylight (a see-through night side): never, now that every sky is a night's.
        property real day: 0
        supportsAtlasTextures: false
        // Alive: a second a second, while the window is awake and the body is
        // big enough to see it; it picks up where it stopped.
        // Only for a world that moves (clouds, a corona): a still one never asks for a frame.
        FrameAnimation { running: shade.live !== 0 && root.animated && root.pace > 0 && root.disc >= 120 && Theme.alive && shade.visible; onTriggered: shade.time = (shade.time + frameTime * root.pace) % 3600 }

        // A body comes up out of the dark, a touch closer as it brightens.
        opacity: root.animated ? 0 : 1
        scale: root.animated ? 0.97 : 1
        Component.onCompleted: if (root.animated) rise.start()
        ParallelAnimation {
            id: rise
            NumberAnimation { target: shade; property: "opacity"; to: 1; duration: Theme.rise; easing: Theme.easeOut }
            NumberAnimation { target: shade; property: "scale"; to: 1; duration: Theme.rise; easing: Theme.easeOut }
        }
    }
}

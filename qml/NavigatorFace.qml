pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    The navigator's portrait (`Theme.mascotOf`, a picture on this computer
    only) in a glass frame with its top-right corner cut: cropped, never
    stretched, read at the size it is drawn (never enlarged past the
    picture's own pixels), with a light along its left edge in the world's
    light and the foot fading into the ground. The world's motif frames
    it: Saturn's brackets, Mercury's sheet of washi behind it, Neptune's
    neon edge with a second, cyan one, Terra's daylight. `diamond` cuts it
    into a diamond, close on the face (the head chip).

    It reacts, never on a loop, all of it on the motion tokens: `bob()`
    when a line arrives, `lean()` towards a page that has just opened,
    `cheer()` (a hop on the beat, a warm light and a burst of sparks from
    its cut corner; `Sol.cheer()` calls it on every navigator in the
    window now and then, and only `glow()`, the warm light, in between);
    late at night (23:00 to 5:00) it is a little dimmer, sleepy. With less
    motion only the warm light shows.

    Its frame belongs to the rail: the outline and its second light run
    along the top, the cut and the edge that breaks out into the page,
    and fade down it, and the portrait's foot dissolves into the glass.

        NavigatorFace { width: 96; height: 124 }
        NavigatorFace { width: 40; height: 40; diamond: true }
*/
Item {
    id: face

    /** Whose navigator: the window's world (a moon's is its planet's). */
    property string world: Sol.world
    readonly property var flavour: Theme.yozoraOf(world)
    readonly property string portrait: Theme.mascotOf(world)
    /** Whether there is one to show: the portrait is here. */
    readonly property bool here: portrait !== "" && picture.status !== Image.Error
    /** A diamond close on the face instead of head and shoulders under a cut corner. */
    property bool diamond: false
    /** The pointer is over it: the edge lights a little. */
    property bool lit: false
    /** The motif round the frame (Mercury's washi, Neptune's second edge, Saturn's brackets); off where it would crowd. */
    property bool motifs: !diamond

    /** Its hour: the clock's, or a picture's staged one (`_hour`). */
    readonly property int hour: { const w = Window.window as AppWindow; return w && w.stagedHour >= 0 ? w.stagedHour : Theme.hour }
    readonly property bool sleepy: hour >= 23 || hour < 5

    /** A little hop: a line has arrived. */
    function bob() { if (Theme.calm || !here) return; hop.restart() }
    /** A lean towards the pane and back: a page has opened. */
    function lean() { if (Theme.calm || !here) return; tilt.restart() }
    /** Pleased: a warm light over the portrait. */
    function glow() { if (here) glowing.restart() }
    /** Delighted, the big one: it jumps on the beat (up on a hit, held, down with the spring), a warm light, and a burst of sparks from its cut corner. */
    function cheer() {
        if (!here) return
        glowing.restart()
        if (Theme.calm) return
        hop.stop()
        jump.restart()
        sparks.burst()
    }
    Connections { target: Sol; function onReacted(kind) { if (kind === "cheer") face.cheer(); else if (kind === "happy") face.glow() } }

    visible: here
    readonly property real cut: diamond ? width / 2 : Math.min(Theme.hudCut, width * 0.2)
    readonly property color rim: flavour.motif === "summer" ? flavour.second : flavour.accent
    /** The warm light, 0 to 1 while it cheers. */
    property real warm: 0
    property real bobY: 0
    property real tiltAngle: 0

    SequentialAnimation {
        id: hop
        NumberAnimation { target: face; property: "bobY"; to: -5; duration: Theme.lock; easing: Theme.easeOut }
        NumberAnimation { target: face; property: "bobY"; to: 0; duration: Theme.settle; easing: Theme.spring }
    }
    SequentialAnimation {
        id: tilt
        NumberAnimation { target: face; property: "tiltAngle"; to: 2.5; duration: Theme.lock; easing: Theme.easeOut }
        NumberAnimation { target: face; property: "tiltAngle"; to: 0; duration: Theme.settle; easing: Theme.easeInOut }
    }
    SequentialAnimation {
        id: jump
        NumberAnimation { target: face; property: "bobY"; to: -14; duration: Theme.hit; easing: Theme.easeOut }
        PauseAnimation { duration: Theme.hold }
        NumberAnimation { target: face; property: "bobY"; to: 0; duration: Theme.settle; easing: Theme.spring }
    }
    SequentialAnimation {
        id: glowing
        NumberAnimation { target: face; property: "warm"; to: 1; duration: Theme.lock; easing: Theme.easeOut }
        PauseAnimation { duration: Theme.fade }
        NumberAnimation { target: face; property: "warm"; to: 0; duration: Theme.rise; easing: Theme.easeInOut }
    }
    Settling { when: hop.running || jump.running || tilt.running || glowing.running || picture.status === Image.Loading }

    // Everything that moves with it: the frame, its motif and its light.
    Item {
        id: body
        width: face.width; height: face.height
        transform: Translate { y: face.bobY }
        rotation: face.tiltAngle
        transformOrigin: Item.Bottom

        // Mercury: a sheet of washi behind the portrait, a little lower and to the left, as if pasted on.
        HudGlass {
            visible: face.motifs && face.flavour.motif === "shrine"
            x: -Theme.s1 - 1; y: Theme.s1 + 1
            width: parent.width; height: parent.height
            cuts: [0, face.cut, 0, 0]
            motif: "washi"
            tint: face.flavour.washi || "transparent"
            line: Theme.tint(face.flavour.seal, 0.5)
            accent: face.flavour.seal
        }
        // Neptune: a second edge in the ice cyan, offset, as neon doubles in the rain: along the
        // top, the cut and down the outer edge, fading as it goes down into the rail.
        Item {
            visible: face.motifs && face.flavour.motif === "neon"
            x: 3; y: 3
            width: parent.width; height: parent.height
            readonly property color tube: Theme.tint(face.flavour.second, 0.55)
            Rectangle {
                width: parent.width - face.cut; height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.4; color: Theme.tint(face.flavour.second, 0.55) }
                }
            }
            Rectangle {
                x: parent.width - face.cut; y: 0
                width: Math.SQRT2 * face.cut; height: 1
                transformOrigin: Item.TopLeft
                rotation: 45
                antialiasing: true
                color: Theme.tint(face.flavour.second, 0.55)
            }
            Rectangle {
                x: parent.width - 1; y: face.cut
                width: 1; height: parent.height - face.cut
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.tint(face.flavour.second, 0.55) }
                    GradientStop { position: 0.7; color: "transparent" }
                }
            }
        }

        // The picture, read at the size it is drawn (a picture is never enlarged past its own pixels).
        Image {
            id: picture
            visible: false
            source: face.portrait
            asynchronous: true
            smooth: true
            // Its shape, taken once it is read (the size it is read at follows from it, so not a binding).
            property real aspect: 2 / 3
            onStatusChanged: if (status === Image.Ready && implicitHeight > 0 && Math.abs(implicitWidth / implicitHeight - aspect) > 0.02) aspect = implicitWidth / implicitHeight
            sourceSize.height: Math.max(1, Math.ceil(face.height / crop.h * Screen.devicePixelRatio))
        }
        // The part of the picture in the frame: as much as fills it, round the face when close.
        // The flavour's `face` is where the face is in its portrait, and how close the frame
        // comes ([x, y, zoom]: a whole figure, a cut-out, wants more than a close crop).
        QtObject {
            id: crop
            readonly property real frame: face.width / Math.max(1, face.height)
            readonly property var at: face.flavour.face || [0.5, 0.4]
            readonly property real zoom: (at[2] || 1) * (face.diamond ? 1.3 : 1)
            readonly property real w: (frame < picture.aspect ? frame / picture.aspect : 1) / zoom
            readonly property real h: (frame < picture.aspect ? 1 : picture.aspect / frame) / zoom
            // Head and shoulders: the face a little above the frame's middle, the hair in; the chip centres it.
            readonly property real x: Math.max(0, Math.min(1 - w, at[0] - w / 2))
            readonly property real y: Math.max(0, Math.min(1 - h, face.diamond ? at[1] - h / 2 : at[1] - h * 0.45))
        }
        // Cut like the panels: the picture shows through the glass shader's shape, with the
        // world's motif (Neptune's neon edge and scanlines, Terra's daylight).
        ShaderEffect {
            anchors.fill: parent
            property variant source: picture
            property vector2d size: Qt.vector2d(width, height)
            property vector4d cuts: face.diamond ? Qt.vector4d(face.cut, face.cut, face.cut, face.cut) : Qt.vector4d(0, face.cut, 0, 0)
            // Dimmer when sleepy, warm when it cheers.
            property color tint: Qt.tint(face.flavour.ground, Theme.tint(face.flavour.blush, face.warm))
            property real tintAlpha: (face.sleepy ? 0.4 : 0) * (1 - face.warm) + 0.22 * face.warm
            property color line: face.rim
            property real lineAlpha: face.lit ? 1 : 0.8
            property real glassy: picture.status === Image.Ready ? 1 : 0
            property vector4d rect: Qt.vector4d(crop.x, crop.y, crop.w, crop.h)
            property color accent: face.flavour.accent
            property real motif: face.flavour.motif === "neon" ? 2 : face.flavour.motif === "summer" ? 3 : 0
            property real glow: face.lit ? 1 : 0.2
            // The portrait itself, not a part of the ground: no place on the window to find.
            property real screen: 0
            property real yUp: 0
            property vector4d ground: Qt.vector4d(0, 0, 1, 1)
            vertexShader: "../shaders/hud.vert.qsb"
            fragmentShader: "../shaders/hud.frag.qsb"
        }
        // The edge light: the world's light along the left side, the foot fading into the ground.
        Rectangle {
            visible: !face.diamond && picture.status === Image.Ready
            x: 1; y: 1
            width: Math.min(14, parent.width * 0.16); height: parent.height - 2
            opacity: face.sleepy ? 0.4 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(face.rim, face.lit ? 0.42 : 0.3) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // The foot dissolves into the rail's glass, its outline with it.
        Rectangle {
            visible: !face.diamond && picture.status === Image.Ready
            x: -1; y: parent.height * 0.55
            width: parent.width + 2; height: parent.height * 0.45 + 1
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.55; color: Theme.tint(face.flavour.ground, 0.55) }
                GradientStop { position: 1; color: Theme.tint(face.flavour.ground, 0.96) }
            }
        }
        // Saturn: the panels' brackets on the frame's three uncut corners.
        HudBrackets {
            visible: face.motifs && face.flavour.motif === "dusk"
            anchors.fill: parent
            anchors.margins: -3
            color: Theme.tint(face.flavour.accent, face.lit ? 1 : 0.75)
            cuts: [0, 1, 0, 0]
        }
        Spark {
            id: sparks
            x: parent.width - face.cut / 2; y: face.cut / 2
            color: face.flavour.accent
            count: 28
        }
    }
}

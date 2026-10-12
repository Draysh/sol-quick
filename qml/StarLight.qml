pragma ComponentBehavior: Bound
import QtQuick

/*
    A star's light on a `StarField`: brightest at its heart, gone by `r`, in
    `tone`, and with `cross` a cross of light that long through it. One
    small shader draws the light, so a sky of hundreds of stars stays light
    to move. It is centred on its own x, y.

        StarLight { x: map.sx(s.x); y: map.sy(s.y); tone: map.warm; r: 26; strength: 0.38; cross: 28 }
*/
Item {
    id: light

    /** The light's colour, how far it reaches in pixels and how bright its heart is (0–1; 0 draws none). */
    property color tone: "white"
    property real r: 10
    property real strength: 0.35
    /** How it falls off: at `x` of the way out `y` of the heart is left, at `z` `w` of it, at the edge none. */
    property vector4d falloff: Qt.vector4d(0.2, 0.4, 0.5, 0.1)
    /** A cross of light this many pixels long through the heart (0: none), and how bright its middle is. */
    property real cross: 0
    property real crossStrength: 0.5

    ShaderEffect {
        visible: light.r > 0 && light.strength > 0
        x: -light.r
        y: -light.r
        width: light.r * 2
        height: light.r * 2
        // The colour opaque and its alpha apart, however Qt hands colours to shaders.
        property color tone: Qt.rgba(light.tone.r, light.tone.g, light.tone.b, 1)
        property real alpha: light.tone.a
        property real strength: light.strength
        property vector4d falloff: light.falloff
        fragmentShader: "../shaders/light.frag.qsb"
    }

    Repeater {
        model: light.cross > 0 ? [0, 90] : []
        delegate: Rectangle {
            required property int modelData
            anchors.centerIn: parent
            width: light.cross
            height: 1
            rotation: modelData
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(light.tone, 0) }
                GradientStop { position: 0.5; color: Theme.tint(light.tone, light.crossStrength) }
                GradientStop { position: 1; color: Theme.tint(light.tone, 0) }
            }
        }
    }
}

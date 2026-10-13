import QtQuick
import QtQuick.Effects

/*
    A picture graded in one colour, as SSS by applibot grades the room
    behind each member: its light and dark kept, its colours gone, black
    into the flavour's light (a `duotone` flavour's stills, Neptune's red, Saturn's amber).
    Use it as a layer's effect; the picture is graded once, as it is drawn
    into its layer, so a still picture costs nothing more while it rests.

        Image { source: still; layer.enabled: Theme.hud.duotone; layer.effect: Duotone { } }
*/
MultiEffect {
    /** The colour it is graded into. */
    property color tone: Theme.hudAccent

    colorization: 1
    colorizationColor: tone
    // A little deeper and harder than the picture, so the red lies in the light and black in the shade.
    contrast: 0.12
    brightness: -0.08
}

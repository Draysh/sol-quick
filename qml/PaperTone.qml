import QtQuick

/*
    A picture graded in one colour on a light ground, as Duotone grades one
    on a dark: its colours gone, its light kept, the shadows in the deep of
    the flavour's light and the highlights in paper (Terra's ramune blue on
    paper white). A light flavour's stills, and a picture standing on them.
    Use it as a layer's effect; the picture is graded once, as it is drawn
    into its layer, so a still picture costs nothing more while it rests.

        Image { source: still; layer.enabled: true; layer.effect: PaperTone { } }
*/
ShaderEffect {
    /** The shadows' colour: the flavour's light. */
    property color shadow: Theme.hudAccent
    /** The highlights' colour: the paper the light flavour stands on. */
    property color highlight: Theme.paper
    /** How steep the ramp is round its middle, and how far it is lifted (-1 to 1). */
    property real contrast: 0.1
    property real brightness: 0.12

    // Resolved here, beside the kit's shaders, wherever the effect is made.
    fragmentShader: Qt.resolvedUrl("../shaders/tone.frag.qsb")
}

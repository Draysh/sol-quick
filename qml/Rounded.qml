import QtQuick

/*
    An image with rounded corners, cut in a shader: the Image (or
    AnimatedImage) it is given stays hidden, and this draws its picture,
    placed as the image's own fill mode and alignment place it, `zoom`ed
    about the centre, inside a rounded rect with a smoothed edge. One quad,
    no layer and no extra pass, so a wall of them scrolls as cheaply as
    plain images. Picture uses it; so does the Shell's flying hero.

        Image { id: still; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectCrop; … }
        Rounded { anchors.fill: parent; image: still; radius: Theme.radiusM }
*/
ShaderEffect {
    id: root

    /** The picture to draw: hidden, and the same size as this. */
    property Image image: null
    /** The corners, in pixels. */
    property real radius: Theme.radiusM
    /** Over 1 magnifies the picture inside its shape, which stays put (a lift). */
    property real zoom: 1

    // What the shader reads.
    property variant source: image
    property vector2d size: Qt.vector2d(width, height)
    /** Where the image paints, in this item's 0–1 space: its offset, then its size. */
    property vector4d frame: {
        const i = image
        if (!i || i.implicitWidth <= 0 || i.implicitHeight <= 0 || width <= 0 || height <= 0) return Qt.vector4d(0, 0, 1, 1)
        let w = 1, h = 1
        if (i.fillMode === Image.PreserveAspectCrop || i.fillMode === Image.PreserveAspectFit) {
            const sx = width / i.implicitWidth, sy = height / i.implicitHeight
            const s = i.fillMode === Image.PreserveAspectCrop ? Math.max(sx, sy) : Math.min(sx, sy)
            w = i.implicitWidth * s / width
            h = i.implicitHeight * s / height
        }
        const ax = i.horizontalAlignment === Image.AlignLeft ? 0 : i.horizontalAlignment === Image.AlignRight ? 1 : 0.5
        const ay = i.verticalAlignment === Image.AlignTop ? 0 : i.verticalAlignment === Image.AlignBottom ? 1 : 0.5
        return Qt.vector4d((1 - w) * ax, (1 - h) * ay, w, h)
    }

    fragmentShader: "../shaders/picture.frag.qsb"
}

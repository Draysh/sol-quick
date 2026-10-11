import QtQuick

/*
    Faint rings round a body, drawn over it: each an ellipse (a circle,
    face on) about the body's centre, the half behind the body hidden where
    the body is. Mercury gains one for each week of reviews in a row;
    Saturn's own rings glow when a series is finished. Drawn once (a
    Canvas), so it costs nothing while still; fade it with `opacity`.

        Rings { cx: body.x + body.disc / 2; cy: body.y + body.disc / 2; body: body.disc / 2; radii: [1.06, 1.1, 1.14]; color: Theme.world }
*/
Item {
    id: root

    /** The body's centre, in the parent's coordinates. */
    property real cx: 0
    property real cy: 0
    /** The body's radius: a ring's back half is hidden inside it. */
    property real body: 100
    /** Each ring's radius across, in body radii. */
    property var radii: [1.08]
    /** How round each ring looks: its height over its width (1 face on, 0.09 Saturn's from the side). */
    property real aspect: 1
    /** The rings' turn, in degrees clockwise. */
    property real tilt: 0
    property color color: Theme.world
    /** Each ring's alpha; the outer ones fainter. */
    property real alpha: 0.22
    /** The line's width; with `soft`, a glow rather than a line. */
    property real line: 1
    property bool soft: false

    readonly property real span: Math.max.apply(null, radii.concat([1])) * body
    x: cx - span - 20
    y: cy - span - 20
    width: span * 2 + 40
    height: span * 2 + 40

    onRadiiChanged: canvas.requestPaint()
    onBodyChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onAspectChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const g = getContext("2d")
            g.reset()
            g.clearRect(0, 0, width, height)
            g.translate(width / 2, height / 2)
            g.rotate(root.tilt * Math.PI / 180)
            const steps = 220
            root.radii.forEach((k, n) => {
                const rx = k * root.body, ry = rx * root.aspect
                const fade = root.alpha * (1 - n / (root.radii.length + 2))
                const passes = root.soft ? [[root.line * 6, 0.18], [root.line * 3, 0.35], [root.line, 1]] : [[root.line, 1]]
                passes.forEach(p => {
                    g.lineWidth = p[0]
                    g.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, fade * p[1])
                    g.beginPath()
                    let down = false
                    for (let i = 0; i <= steps; i++) {
                        const t = i / steps * Math.PI * 2
                        const px = rx * Math.cos(t), py = ry * Math.sin(t)
                        // The far half (above the centre) passes behind the body.
                        const hidden = py < 0 && px * px + py * py < root.body * root.body * 0.98
                        if (hidden) { down = false; continue }
                        if (!down) { g.moveTo(px, py); down = true } else g.lineTo(px, py)
                    }
                    g.stroke()
                })
            })
        }
    }
}

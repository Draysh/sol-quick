pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

/*
    Hairlines and capitals. `primary` is the only filled shape on a screen:
    use it once, for the screen's main action; it carries the world's glow.
    `ghost` otherwise, `quiet` for low-stakes actions, `round` for icon-only
    controls (give it an `icon`); any other may lead with an `icon` too, a
    hairline glyph before its label (`Icon` names), for the few actions a
    glyph makes quicker to find. Its corners are `Theme.radiusM` (a round
    one is a circle). Focus locks two corner ticks on; a press gives a
    little; while busy, a hairline sweeps along the bottom. In the Yozora
    look the words are in the mono face, the primary is a parallelogram
    in the world's light and a round one a diamond.

        Button { text: "Log it"; variant: "primary"; busy: saving; onClicked: save() }
*/
Item {
    id: root

    property string text: ""
    property string variant: "ghost"
    /** An `Icon` name: the glyph before the label (alone, on a `round` one). */
    property string icon: ""
    property bool busy: false
    /** A line about it, shown on hover. */
    property string hint: ""
    signal clicked()

    readonly property bool primary: variant === "primary"
    readonly property bool quiet: variant === "quiet"
    readonly property bool round: variant === "round"
    readonly property bool live: enabled && !busy
    readonly property bool hovered: mouse.containsMouse && live
    readonly property bool pressed: mouse.pressed && live

    /** Its padding either side of the label, both together. */
    readonly property real pad: quiet ? 20 : 32
    /** The Yozora look's primary: a parallelogram, its top leaning this far past its foot. */
    readonly property bool angled: Theme.yozora && primary
    readonly property real lean: angled ? Math.round(Theme.control * 0.36) : 0
    readonly property real iconRoom: icon !== "" ? glyph.size + (text !== "" ? Theme.s2 : 0) : 0
    readonly property real natural: round ? Theme.control : iconRoom + (text !== "" ? label.implicitWidth : 0) + pad + lean
    // The property a container gives its children's room in (see `room`). Read by name,
    // since it is on that container, not on every Item.
    readonly property string roomKey: "childRoom"
    /**
        The room it really has: the width of the first thing around it that sets one. A Row,
        a Column, a Grid or a layout is passed over (it is as wide as what it holds, so
        measuring against it would hold a button that shows up later to the width the others
        left it); a Flow counts (it wraps at its width), as does any plain item, card or page.
        A container that places its children itself and sizes itself from them says how much
        room they have with `childRoom` (the Sheet's line under the name does).
    */
    readonly property real room: {
        for (let p = parent; p; p = p.parent) {
            const given = p[root.roomKey]
            if (given !== undefined) return given
            const flow = p.hasOwnProperty("flow") && !p.hasOwnProperty("columns")
            const positions = p.hasOwnProperty("populate") || p.hasOwnProperty("layoutDirection") || p.hasOwnProperty("columnSpacing")
            if (positions && !flow) continue
            return p.width > 0 ? p.width : Infinity
        }
        return Infinity
    }
    // Never wider than that room: a label too long for it elides instead of running out;
    // with room to spare, it is always its natural width.
    implicitWidth: round ? natural : Math.min(natural, room)
    implicitHeight: Theme.control
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text !== "" ? text : hint
    Accessible.description: hint
    Accessible.onPressAction: if (live) clicked()

    // One click per press: holding the key doesn't repeat it.
    Keys.onPressed: event => {
        if (!live) return
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            if (!event.isAutoRepeat) root.clicked()
        }
    }

    // The press gives, like a real key.
    transform: Translate { y: root.pressed ? 1 : 0; Behavior on y { NumberAnimation { duration: 40 } } }

    // The world's light behind the main action; it breathes three slow breaths when the button
    // comes (or the window does), then rests, so nothing is drawn while nothing happens.
    property real breath: 0
    SequentialAnimation { running: root.primary && root.enabled && root.visible && Theme.alive && !Theme.calm; loops: 3
        NumberAnimation { target: root; property: "breath"; to: 1; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "breath"; to: 0; duration: 2600; easing.type: Easing.InOutSine } }
    RectangularShadow {
        anchors.fill: face
        radius: face.radius
        visible: root.primary && root.enabled && !root.angled
        blur: (root.hovered ? 56 : 40) + root.breath * 8
        spread: 0
        color: Theme.tint(Theme.world, (root.hovered ? 0.5 : 0.3) + root.breath * 0.06)
        Behavior on blur { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }

    Rectangle {
        id: face
        anchors.fill: parent
        visible: !root.angled && !root.diamond
        radius: root.round ? height / 2 : Theme.radiusM
        // The main action keeps its fill while it works, a little dimmed.
        color: root.primary && root.busy && root.enabled ? Theme.tint(Theme.text, 0.55)
            : !root.live ? "transparent"
            : root.primary ? (root.hovered ? Theme.textBright : Theme.text)
            : root.quiet ? "transparent"
            : root.hovered ? Theme.surfaceHover : "transparent"
        border.width: root.quiet ? 0 : 1
        border.color: !root.enabled ? Theme.lineMid
            : root.primary ? face.color
            : root.hovered ? Theme.text
            : root.round ? Theme.tint(Theme.ink, 0.35) : Theme.tint(Theme.ink, 0.4)
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }

    // A round one is a diamond in the Yozora look.
    readonly property bool diamond: Theme.yozora && round
    Rectangle {
        visible: root.diamond
        anchors.fill: parent
        rotation: 45
        scale: 0.72
        antialiasing: true
        color: face.color
        border.width: face.border.width
        border.color: face.border.color
    }

    // The Yozora look's primary: a parallelogram in the world's light.
    Shape {
        visible: root.angled
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.activeFocus ? 1 : 0
            strokeColor: root.activeFocus ? Theme.hudText : "transparent"
            fillColor: !root.live ? Theme.tint(Theme.hudAccent, root.busy && root.enabled ? 0.55 : 0.25) : root.hovered ? Qt.lighter(Theme.hudAccent, 1.1) : Theme.hudAccent
            startX: root.lean; startY: 0.5
            PathLine { x: root.width - 0.5; y: 0.5 }
            PathLine { x: root.width - root.lean; y: root.height - 0.5 }
            PathLine { x: 0.5; y: root.height - 0.5 }
            PathLine { x: root.lean; y: 0.5 }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s2

        Icon {
            id: glyph
            visible: root.icon !== ""
            name: root.icon
            // Lucide's glyphs keep a margin of their own, so they take a little more room.
            size: grid === 24 ? 14 : 12
            color: label.color
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: label
            visible: root.text !== ""
            text: root.text
            width: Math.max(0, Math.min(implicitWidth, root.width - root.pad - root.iconRoom - root.lean))
            elide: Text.ElideRight
            font.family: Theme.fontCaps
            font.weight: Theme.yozora ? Font.Bold : Theme.weightLabel
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(0.16, Theme.textXs)
            font.capitalization: Font.AllUppercase
            color: !root.enabled ? Theme.textFaint
                : root.primary ? (root.angled && !root.live ? Theme.hudText : Theme.space)
                : root.busy ? Theme.textQuiet
                : root.quiet ? (root.hovered ? Theme.textBright : Theme.textQuiet)
                : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }

    // Busy: a hairline sweeps along the bottom edge until the work is done,
    // between the corners.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: face.radius
        anchors.rightMargin: face.radius
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        height: 1
        clip: true
        visible: root.busy
        Rectangle {
            id: sweep
            width: parent.width * 0.4
            height: 1
            color: Theme.textBright
            NumberAnimation on x {
                running: root.busy && root.visible && Theme.alive
                loops: Animation.Infinite
                from: -sweep.width
                to: sweep.parent.width
                duration: 1100
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.ease
            }
        }
    }

    // Focus: two ticks lock onto the control, like a reticle finding its target.
    Ticks { on: root.activeFocus; radius: face.radius }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.live) { root.forceActiveFocus(); root.clicked() }
    }

    Hint { text: root.hint; when: mouse.containsMouse }
}

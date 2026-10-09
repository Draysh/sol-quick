pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

/*
    Hairlines and capitals. `primary` is the only filled shape on a screen:
    use it once, for the screen's main action; it carries the world's glow.
    `ghost` otherwise, `quiet` for low-stakes actions, `round` for icon-only
    controls (give it an `icon`). Focus locks two corner ticks on; a press
    gives a little; while busy, a hairline sweeps along the bottom.

        Button { text: "Log it"; variant: "primary"; busy: saving; onClicked: save() }
*/
Item {
    id: root

    property string text: ""
    property string variant: "ghost"
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
    readonly property real iconRoom: icon !== "" ? 12 + (text !== "" ? Theme.s2 : 0) : 0
    readonly property real natural: round ? Theme.control : iconRoom + (text !== "" ? label.implicitWidth : 0) + pad
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

    // The world's light behind the main action; it breathes, slowly, while the button waits.
    property real breath: 0
    SequentialAnimation { running: root.primary && root.enabled && root.visible && Theme.alive; loops: Animation.Infinite
        NumberAnimation { target: root; property: "breath"; to: 1; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "breath"; to: 0; duration: 2600; easing.type: Easing.InOutSine } }
    RectangularShadow {
        anchors.fill: face
        visible: root.primary && root.enabled
        blur: (root.hovered ? 56 : 40) + root.breath * 8
        spread: 0
        color: Theme.tint(Theme.world, (root.hovered ? 0.5 : 0.3) + root.breath * 0.06)
        Behavior on blur { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.round ? height / 2 : 0
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

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s2

        Icon {
            visible: root.icon !== ""
            name: root.icon
            size: 12
            color: label.color
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: label
            visible: root.text !== ""
            text: root.text
            width: Math.max(0, Math.min(implicitWidth, root.width - root.pad - root.iconRoom))
            elide: Text.ElideRight
            font.family: Theme.font
            font.weight: Theme.weightLabel
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(0.16, Theme.textXs)
            font.capitalization: Font.AllUppercase
            color: !root.enabled ? Theme.textFaint
                : root.primary ? Theme.space
                : root.busy ? Theme.textQuiet
                : root.quiet ? (root.hovered ? Theme.textBright : Theme.textQuiet)
                : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }

    // Busy: a hairline sweeps along the bottom edge until the work is done.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
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
                to: root.width
                duration: 1100
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.ease
            }
        }
    }

    // Focus: two ticks lock onto the control, like a reticle finding its target.
    Ticks { on: root.activeFocus }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.live) { root.forceActiveFocus(); root.clicked() }
    }

    Hint { text: root.hint; when: mouse.containsMouse }
}

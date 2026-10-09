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

    implicitWidth: round ? Theme.control : row.implicitWidth + (quiet ? 20 : 32)
    implicitHeight: Theme.control
    activeFocusOnTab: true

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
        color: !root.live ? "transparent"
            : root.primary ? (root.hovered ? Theme.textBright : Theme.text)
            : root.quiet ? "transparent"
            : root.hovered ? Theme.surfaceHover : "transparent"
        border.width: root.quiet ? 0 : 1
        border.color: !root.enabled ? Theme.lineMid
            : root.primary ? Theme.text
            : root.hovered ? Theme.text
            : root.round ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.4)
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
            font.family: Theme.font
            font.weight: Theme.weightLabel
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(0.16, Theme.textXs)
            font.capitalization: Font.AllUppercase
            color: !root.enabled ? Theme.textFaint
                : root.busy ? Theme.textQuiet
                : root.primary ? Theme.space
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
    Tick { at: "tl"; on: root.activeFocus }
    Tick { at: "br"; on: root.activeFocus }

    component Tick: Item {
        id: tick
        property string at: "tl"
        property bool on: false
        readonly property bool tl: at === "tl"
        readonly property real out: on ? 6 : 10
        width: 10; height: 10
        opacity: on ? 1 : 0
        x: tl ? -out : root.width + out - width
        y: tl ? -out : root.height + out - height
        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
        Behavior on x { NumberAnimation { duration: Theme.lock } }
        Behavior on y { NumberAnimation { duration: Theme.lock } }
        Rectangle { width: tick.tl ? parent.width : 1; height: 1; color: Theme.textBright; x: 0; y: tick.tl ? 0 : parent.height - 1 }
        Rectangle { width: 1; height: tick.tl ? parent.height : 1; color: Theme.textBright; x: tick.tl ? 0 : parent.width - 1; y: 0 }
        Rectangle { visible: !tick.tl; width: parent.width; height: 1; color: Theme.textBright; y: parent.height - 1 }
        Rectangle { visible: !tick.tl; width: 1; height: parent.height; color: Theme.textBright; x: parent.width - 1 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.live) { root.forceActiveFocus(); root.clicked() }
    }

    Hint { text: root.hint; when: mouse.containsMouse }
}

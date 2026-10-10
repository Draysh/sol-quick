import QtQuick
import QtQuick.Shapes

/* One checklist row: a box (`Theme.radiusS` corners), the label, and a short note on the right. The tick draws itself in. */
Item {
    id: root

    property string label: ""
    property bool checked: false
    property string meta: ""
    property bool busy: false
    property bool last: false
    signal toggled(bool checked)

    readonly property bool live: enabled && !busy
    /** What the box shows: the click first, the data when it comes. */
    property bool shown: checked
    onCheckedChanged: shown = checked
    /** The write didn't take: the box goes back, with a shake. */
    function fail() { shown = checked; shake.restart(); Sounds.off() }
    implicitWidth: parent ? parent.width : 240
    implicitHeight: 46
    function flip() { if (!live) return; shown = !shown; Sounds.tick(); toggled(shown) }
    activeFocusOnTab: true
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) flip() }
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: shown
    Accessible.onToggleAction: flip()
    Accessible.onPressAction: flip()
    transform: Translate { id: nudge; x: 0 }
    SequentialAnimation { id: shake; NumberAnimation { target: nudge; property: "x"; to: -4; duration: 40 } NumberAnimation { target: nudge; property: "x"; to: 4; duration: 60 } NumberAnimation { target: nudge; property: "x"; to: -2; duration: 50 } NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50 } }

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line; visible: !root.last }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 14

        Rectangle {
            id: box
            width: 16; height: 16
            radius: Theme.radiusS
            anchors.verticalCenter: parent.verticalCenter
            color: root.shown ? (root.enabled ? Theme.text : Theme.textFaint) : "transparent"
            border.width: 1
            border.color: !root.enabled ? Theme.lineMid : root.shown ? Theme.text : (mouse.containsMouse && root.live) || root.activeFocus ? Theme.textBright : Theme.tint(Theme.ink, 0.6)
            scale: mouse.pressed && root.live ? 0.85 : 1
            Behavior on color { ColorAnimation { duration: Theme.lock } }
            Behavior on border.color { ColorAnimation { duration: Theme.lock } }
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
            Ticks { on: root.activeFocus; out: 5; radius: box.radius }
            // Lock: the box swells for a moment as the tick goes in.
            transform: Scale { id: swell; origin.x: 8; origin.y: 8; xScale: 1; yScale: 1 }
            SequentialAnimation {
                id: lockIn
                NumberAnimation { target: swell; properties: "xScale,yScale"; to: 1.18; duration: Theme.settle * 0.3; easing.type: Easing.OutCubic }
                NumberAnimation { target: swell; properties: "xScale,yScale"; to: 1; duration: Theme.settle * 0.7; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }

            Shape {
                anchors.centerIn: parent
                width: 10; height: 10
                visible: root.shown
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true
                ShapePath {
                    strokeColor: Theme.space; strokeWidth: 2; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    trim.start: 0
                    trim.end: root.shown ? 1 : 0
                    Behavior on trim.end { enabled: root.shown; SequentialAnimation { PauseAnimation { duration: Theme.lock } NumberAnimation { duration: Theme.lock * 2; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
                    startX: 1.5; startY: 5.5
                    PathLine { x: 4.2; y: 8.2 }
                    PathLine { x: 9; y: 2 }
                }
            }
        }
        Text {
            width: parent.width - 30 - (metaText.visible ? metaText.implicitWidth + 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.font
            font.pixelSize: Theme.textM
            font.weight: Theme.weightValue
            color: !root.enabled ? Theme.textFaint : root.shown ? Theme.textQuiet : Theme.text
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Quiet {
            id: metaText
            visible: root.meta !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.meta
            onTextChanged: fadeIn.restart()
            NumberAnimation on opacity { id: fadeIn; from: 0; to: 1; duration: Theme.fade; running: false }
        }
    }

    onShownChanged: if (shown) lockIn.restart()

    // Busy (its change on the way): a hairline sweeps along the bottom, as on a busy Button.
    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 1
        clip: true
        visible: root.busy
        Rectangle {
            id: sweep
            width: parent.width * 0.3
            height: 1
            color: Theme.textQuiet
            NumberAnimation on x {
                running: root.busy && root.visible && Theme.alive
                loops: Animation.Infinite
                from: -sweep.width; to: root.width
                duration: 1400
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.flip()
    }
}

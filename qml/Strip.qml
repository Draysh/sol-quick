pragma ComponentBehavior: Bound
import QtQuick

/*
    A row that scrolls sideways when it is wider than its room: posters,
    episodes, tabs. A sideways wheel, a touchpad's sideways swipe, or Shift
    with the wheel moves it; an up-and-down wheel over it scrolls the page
    it is on (`Theme.screenOf`), as anywhere else. While it overflows, a
    hairline under it shows where in the row you are, and with `fades` its
    ends fade into the page while there is more past them.

        Strip { width: parent.width; Repeater { model: titles; delegate: Cover { … } } }
*/
Item {
    id: strip

    default property alias content: row.data
    property real spacing: Theme.s3
    /** How far one notch of a mouse wheel moves the row. */
    property real notch: 140
    /** The hairline under the row, while it overflows. */
    property bool line: true
    /** The ends fade into `ground` while there is more past them. */
    property bool fades: false
    property color ground: Theme.space
    readonly property bool overflows: flick.contentWidth > flick.width + 0.5
    /** How far along the row is scrolled. */
    property alias contentX: flick.contentX
    readonly property alias flickable: flick

    implicitWidth: row.implicitWidth
    implicitHeight: flick.height + (line && overflows ? Theme.s3 : 0)

    Flickable {
        id: flick
        width: parent.width
        height: row.implicitHeight
        contentWidth: row.implicitWidth
        contentHeight: height
        clip: true
        interactive: strip.overflows
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        Row { id: row; spacing: strip.spacing }

        // Sideways only for a sideways wheel, a touchpad's sideways swipe or Shift; an
        // up-and-down wheel over the row scrolls the page, as anywhere else.
        WheelHandler {
            onWheel: event => {
                const w = Theme.wheel(event, strip.notch)
                const shift = (event.modifiers & Qt.ShiftModifier) !== 0
                const across = w.x || (shift ? w.y : 0)
                if (across !== 0 && (Math.abs(w.x) > Math.abs(w.y) || shift)) {
                    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - across))
                    return
                }
                const page = Theme.screenOf(strip)
                if (page) page.wheel(event)
                else event.accepted = false
            }
        }
    }

    // More beyond an edge: the row fades into the page there.
    Rectangle {
        visible: strip.fades && strip.overflows && flick.contentX < flick.contentWidth - flick.width - 1
        anchors.right: flick.right; width: 28; height: flick.height
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.tint(strip.ground, 0) } GradientStop { position: 1; color: strip.ground } }
    }
    Rectangle {
        visible: strip.fades && strip.overflows && flick.contentX > 1
        width: 28; height: flick.height
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: strip.ground } GradientStop { position: 1; color: Theme.tint(strip.ground, 0) } }
    }

    // Where in the row you are: the part in sight, brighter, along a hairline.
    Rectangle {
        visible: strip.line && strip.overflows
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: Theme.line
        Rectangle {
            x: flick.contentWidth > 0 ? flick.contentX / flick.contentWidth * parent.width : 0
            width: flick.contentWidth > 0 ? flick.width / flick.contentWidth * parent.width : 0
            height: 1
            color: Theme.lineStrong
        }
    }
}

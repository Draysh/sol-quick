pragma ComponentBehavior: Bound
import QtQuick

/*
    A dotted leader and a short list: what comes next in this world. The
    leader draws itself towards the text, then the lines come one by one.
    `flip` puts the leader on the right, pointing at a body to the right.
*/
Row {
    id: root

    property var lines: []
    property bool flip: false

    layoutDirection: flip ? Qt.RightToLeft : Qt.LeftToRight
    spacing: 0

    component Dot: Rectangle {
        id: dot
        property int wait: 0
        radius: width / 2
        color: Theme.textBright
        opacity: 0
        scale: 0.6
        SequentialAnimation {
            running: true
            PauseAnimation { duration: dot.wait }
            ParallelAnimation {
                NumberAnimation { target: dot; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
                NumberAnimation { target: dot; property: "scale"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
        }
    }

    Item {
        id: leader
        width: 72; height: 12
        y: 4
        transform: Scale { origin.x: 36; xScale: root.flip ? -1 : 1 }
        Dot { x: 1; y: 3; width: 6; height: 6 }
        Dot { x: 15.6; y: 3.6; width: 4.8; height: 4.8; wait: Theme.stagger * 3 }
        Rectangle {
            x: 26; y: 6; width: 46; height: 1
            color: Theme.tint(Theme.textBright, 0.6)
            transform: Scale { id: line; origin.x: 0; xScale: 0 }
            SequentialAnimation { running: true; PauseAnimation { duration: Theme.stagger * 4 } NumberAnimation { target: line; property: "xScale"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        }
    }
    Item { width: 10; height: 1 }
    Rectangle { width: 1; height: text.implicitHeight; color: Theme.lineStrong }
    Item { width: 10; height: 1 }
    Column {
        id: text
        Repeater {
            model: root.lines
            delegate: Settle {
                id: entry
                required property string modelData
                required property int index
                place: index + 3
                width: words.implicitWidth
                height: words.implicitHeight
                Text {
                    id: words
                    text: entry.modelData
                    font.family: Theme.font
                    font.weight: Theme.weightValue
                    font.pixelSize: 11
                    font.letterSpacing: Theme.track(Theme.trackRows, 11)
                    font.capitalization: Font.AllUppercase
                    lineHeight: 1.6; lineHeightMode: Text.ProportionalHeight
                    color: Theme.text
                    horizontalAlignment: root.flip ? Text.AlignRight : Text.AlignLeft
                }
            }
        }
    }
}

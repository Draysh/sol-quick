import QtQuick

/*
    A group in the Yozora look (`Theme.look`): a panel of glass over the
    key art (HudGlass) with its top-right corner cut, its title as a HUD
    label in the mono face ("ON AIR TONIGHT · 今夜"), and, on a few, thin
    corner brackets in a light. It settles in as a Card does and fits a
    Grid the same way (`span`, `index`). Give it a width; it is as tall as
    what it holds.

        HudPanel { title: "Continue watching"; jp: "続きから"; brackets: Theme.hudAccent; Column { … } }
*/
Item {
    id: root

    /** Its title, set in upper case. */
    property string title: ""
    /** Japanese after the title, in its own light: "今夜". */
    property string jp: ""
    /** Something at the head's other end: a count, "06". */
    property string aside: ""
    /** The brackets' light (Theme.hudAccent, Theme.hudSecond); transparent for none. */
    property color brackets: "transparent"
    /** How much each corner loses: top-left, top-right, bottom-right, bottom-left. */
    property var cuts: [0, Theme.hudCut, 0, 0]
    /** Its place in a grid, for the stagger. */
    property int index: 0
    /** How many of a Grid's columns it takes: 1, 2, or "row". */
    property var span: 1
    property real gap: Theme.s3
    /** The room between its edge and what it holds. */
    property real pad: 20
    default property alias content: body.data

    implicitWidth: 300
    implicitHeight: body.y + body.implicitHeight + pad

    // It settles into place when it comes into view.
    opacity: 0
    transform: Translate { id: shift; y: 8 }
    property bool late: false
    property var forget: null
    Component.onCompleted: forget = Theme.whenSeen(root, waited => { late = waited; arrive.start() })
    Component.onDestruction: if (forget) forget()
    Settling { when: arrive.running }
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.late ? 0 : Theme.delay(root.index + 2) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }

    HoverHandler { id: over }
    HudGlass { anchors.fill: parent; cuts: root.cuts; glow: over.hovered ? 1 : 0 }
    HudBrackets { anchors.fill: parent; color: root.brackets; cuts: root.cuts }

    Item {
        id: head
        x: root.pad; y: 16
        width: parent.width - root.pad * 2 - (root.cuts[1] || 0) / 2
        height: visible ? 22 : 0
        visible: root.title !== ""
        HudLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            jp: root.jp
            light: root.brackets.a > 0 ? root.brackets : Theme.hudAccent
            room: head.width - (asideText.visible ? asideText.implicitWidth + Theme.s3 : 0)
        }
        Text {
            id: asideText
            visible: root.aside !== ""
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.aside
            font.family: Theme.fontMono; font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.hudFaint
        }
    }
    Rectangle { visible: head.visible; x: root.pad; y: head.y + head.height + 10; width: head.width; height: 1; color: Theme.hudLine }

    Column {
        id: body
        x: root.pad
        y: head.visible ? head.y + head.height + 10 + Math.max(root.gap, Theme.s3) : root.pad
        width: parent.width - root.pad * 2
        spacing: root.gap
    }
}

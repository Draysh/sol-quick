import QtQuick

/*
    A group: a panel of glass over the key art (HudGlass) with its
    top-right corner cut, its title as a HUD label ("ON AIR TONIGHT ·
    今夜"), and, on a few, thin
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
    /** The room its Grid gives it past its own height, to end level with the card beside it (set by the Grid). */
    property real spare: 0

    // It settles into place when it comes into view, a little past it and back, and leans towards the pointer.
    opacity: 0
    property Translate shift: Translate { y: Theme.calm ? 0 : 12 }
    // Grows from its top a little as it settles; a tall one hardly at all, so its top stays where it is.
    property Scale pop: Scale { origin.x: root.width / 2; origin.y: 0; xScale: Theme.calm ? 1 : 0.97; yScale: 1 - (1 - xScale) * Math.min(1, 400 / Math.max(1, root.height)) }
    transform: [shift, pop, lean.shift]
    property bool late: false
    property var forget: null
    /** It has come into view: its glass is made then, not before. */
    property bool seen: false
    Component.onCompleted: forget = Theme.whenSeen(root, waited => { late = waited; seen = true; arrive.start() })
    Component.onDestruction: if (forget) forget()
    Settling { when: arrive.running }
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: root.late ? 0 : Theme.delay(root.index + 2) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.settle; easing: Theme.easeOut }
            NumberAnimation { target: root.shift; property: "y"; to: 0; duration: Theme.settle; easing: Theme.spring }
            NumberAnimation { target: root.pop; property: "xScale"; to: 1; duration: Theme.settle; easing: Theme.spring }
        }
    }

    /** The pointer is on it: its glass's edge and brackets light. */
    readonly property bool pointed: lean.hovered
    Loader {
        anchors.fill: parent
        active: root.seen
        sourceComponent: HudGlass { }
        onLoaded: { const g = item as HudGlass; if (!g) return; g.cuts = Qt.binding(() => root.cuts); g.glow = Qt.binding(() => root.pointed ? 1 : 0) }
    }
    // Its brackets, or under the pointer the world's light's.
    HudBrackets {
        anchors.fill: parent
        cuts: root.cuts
        color: root.brackets.a > 0 ? root.brackets : Theme.tint(Theme.hudAccent, root.pointed ? 0.9 : 0)
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }

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
            font.family: Theme.fontHud; font.pixelSize: Theme.textXs + 1; font.weight: Font.Medium
            font.letterSpacing: Theme.track(0.06, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.hudQuiet
        }
    }
    Rectangle { visible: head.visible; x: root.pad; y: head.y + head.height + 10; width: head.width; height: 1; color: Theme.hudLine }

    Column {
        id: body
        // Drawn taller to end level with its pair (Grid), what it holds sits in the middle.
        transform: Translate { y: root.spare / 2 }
        x: root.pad
        y: head.visible ? head.y + head.height + 10 + Math.max(root.gap, Theme.s3) : root.pad
        width: parent.width - root.pad * 2
        spacing: root.gap
    }

    Lean { id: lean; anchors.fill: parent }
}

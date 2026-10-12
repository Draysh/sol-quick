import QtQuick

/*
    The line under a field (Field, TextArea, Select, Editable): a resting
    hairline that brightens under the pointer, and a light that comes in
    from the left while the field has the keys. Red while `invalid`. Lay
    it along the bottom of the field's line.

        Underline { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; lit: input.activeFocus; hovered: hover.hovered }
*/
Item {
    id: line

    /** The light is on: the field has the keys (or its list is open). */
    property bool lit: false
    property bool hovered: false
    property bool invalid: false
    /** The resting hairline; off for a field that shows only while it is edited. */
    property bool resting: true

    height: 1

    Rectangle {
        visible: line.resting
        anchors.fill: parent
        color: line.invalid ? Theme.danger : !line.enabled ? Theme.lineMid : line.hovered ? Theme.tint(Theme.ink, 0.7) : Theme.lineStrong
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    Rectangle {
        anchors.fill: parent
        color: line.invalid ? Theme.danger : Theme.yozora ? Theme.hudAccent : Theme.textBright
        transform: Scale { origin.x: 0; xScale: line.lit ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
    }
}

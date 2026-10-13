import QtQuick

/*
    The bracketed well a field's text sits in (Field, Select): a faint
    fill between two square brackets, [ and ], their arms short ticks. The
    brackets take the world's light under the pointer and while the field
    has the keys, when a light also runs in along its foot; vermilion while
    `invalid`. Fill the field's line with it and inset the text by `pad`.

        FieldFrame { anchors.fill: parent; lit: input.activeFocus; hovered: hover.hovered }
*/
Item {
    id: frame

    property bool lit: false
    property bool hovered: false
    property bool invalid: false
    /** How far the text sits in from either bracket. */
    readonly property int pad: Theme.s3

    readonly property color tone: invalid ? Theme.danger : !frame.enabled ? Theme.lineMid
        : lit || hovered ? Theme.hudAccent : Theme.lineStrong
    Rectangle {
        anchors.fill: parent
        color: frame.lit ? Theme.tint(Theme.hudAccent, 0.07) : frame.hovered ? Theme.surfaceHover : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    Bracket { x: 0; height: frame.height; tone: frame.tone }
    Bracket { x: frame.width - width; height: frame.height; tone: frame.tone; atEnd: true }
    Underline { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; resting: false; lit: frame.lit; invalid: frame.invalid }

    component Bracket: Item {
        id: bracket
        property bool atEnd: false
        property color tone: Theme.lineStrong
        width: 6
        Behavior on tone { ColorAnimation { duration: Theme.fade } }
        Rectangle { x: bracket.atEnd ? bracket.width - 1 : 0; width: 1; height: bracket.height; color: bracket.tone }
        Rectangle { width: bracket.width; height: 1; color: bracket.tone }
        Rectangle { y: bracket.height - 1; width: bracket.width; height: 1; color: bracket.tone }
    }
}

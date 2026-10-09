pragma ComponentBehavior: Bound
import QtQuick

/* Writing more than a line, e.g. a diary; grows as you type. A label, an underline that lights on focus. */
FocusScope {
    id: root

    property string label: ""
    property alias text: edit.text
    property string placeholder: ""
    property string hint: ""
    property int minLines: 3
    property bool jp: false
    property alias edit: edit

    implicitWidth: 240
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Label { visible: root.label !== ""; text: root.label; width: parent.width }

        Item {
            width: parent.width
            height: Math.max(root.minLines * Theme.textM * 1.6, edit.implicitHeight) + 12

            TextEdit {
                id: edit
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.topMargin: 4
                font.family: root.jp ? Theme.fontJp : Theme.font
                font.pixelSize: Theme.textM
                font.weight: Theme.weightValue
                color: Theme.text
                selectionColor: Theme.text
                selectedTextColor: Theme.space
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                focus: true
                cursorDelegate: Rectangle { width: 1; color: Theme.textBright; visible: edit.cursorVisible }
            }
            Text {
                anchors.fill: edit
                text: root.placeholder
                visible: edit.text === "" && !edit.inputMethodComposing
                font: edit.font
                color: Theme.textFaint
                wrapMode: Text.Wrap
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: hover.hovered ? Qt.rgba(1, 1, 1, 0.7) : Theme.lineStrong
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: Theme.textBright
                transform: Scale { origin.x: 0; xScale: edit.activeFocus ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            }
            HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
        }

        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width }
    }
}

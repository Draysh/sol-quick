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
    activeFocusOnTab: true
    Accessible.role: Accessible.EditableText
    Accessible.name: label !== "" ? label : placeholder

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Label { visible: root.label !== ""; text: root.label; width: parent.width; color: root.enabled ? Theme.textBright : Theme.textQuiet }

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
                color: root.enabled ? Theme.text : Theme.textFaint
                selectionColor: Theme.text
                selectedTextColor: Theme.space
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                focus: true
                // Tab moves on, as in every other field; plain text has no use for a tab.
                Keys.onTabPressed: event => { const n = edit.nextItemInFocusChain(true); if (n) n.forceActiveFocus(Qt.TabFocusReason); event.accepted = true }
                Keys.onBacktabPressed: event => { const n = root.nextItemInFocusChain(false); if (n) n.forceActiveFocus(Qt.BacktabFocusReason); event.accepted = true }
                cursorDelegate: Caret { cursorVisible: edit.cursorVisible; at: edit.cursorPosition }
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
                color: !root.enabled ? Theme.lineMid : hover.hovered ? Theme.tint(Theme.ink, 0.7) : Theme.lineStrong
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: Theme.textBright
                transform: Scale { origin.x: 0; xScale: edit.activeFocus ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            }
            HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.IBeamCursor }
        }

        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width }
    }
}

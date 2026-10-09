import QtQuick

/*
    A label and an underlined input. Errors say what to do, in sentence
    case. Focus lights the line from the left.

        Field { label: "New line"; placeholder: "What happened?"; onAccepted: add() }
*/
FocusScope {
    id: root

    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    property string hint: ""
    property string error: ""
    property int maxLength: 32767
    property bool password: false
    property bool jp: false
    /** `HH:MM`, with a validator to match. */
    property bool time: false
    /** A number, with a validator to match. */
    property bool numeric: false
    property alias readOnly: input.readOnly
    property alias input: input
    signal accepted()
    /** The field was left, or Enter pressed, with its text changed. */
    signal edited()

    readonly property bool invalid: error !== ""

    implicitWidth: 240
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Label { visible: root.label !== ""; text: root.label; width: parent.width }

        Item {
            width: parent.width
            height: Theme.control

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                font.family: root.jp ? Theme.fontJp : Theme.font
                font.pixelSize: Theme.textM
                font.weight: Theme.weightValue
                color: root.enabled ? Theme.text : Theme.textFaint
                selectionColor: Theme.text
                selectedTextColor: Theme.space
                maximumLength: root.maxLength
                echoMode: root.password ? TextInput.Password : TextInput.Normal
                clip: true
                focus: true
                validator: root.time ? timeRule : root.numeric ? numberRule : null
                inputMethodHints: root.numeric ? Qt.ImhFormattedNumbersOnly : root.time ? Qt.ImhDigitsOnly : Qt.ImhNone
                onAccepted: root.accepted()
                onEditingFinished: root.edited()
                RegularExpressionValidator { id: timeRule; regularExpression: /^([01]?\d|2[0-3]):[0-5]\d$/ }
                RegularExpressionValidator { id: numberRule; regularExpression: /^\d*([.,]\d*)?$/ }
                cursorDelegate: Rectangle { width: 1; color: Theme.textBright; SequentialAnimation on opacity { loops: Animation.Infinite; running: input.activeFocus; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
            }
            Text {
                anchors.fill: input
                verticalAlignment: Text.AlignVCenter
                text: root.placeholder
                visible: input.text === "" && !input.inputMethodComposing
                font: input.font
                color: Theme.textFaint
            }
            // The resting line.
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: root.invalid ? Theme.danger : hover.hovered ? Qt.rgba(1, 1, 1, 0.7) : Theme.lineStrong
                Behavior on color { ColorAnimation { duration: Theme.fade } }
            }
            // The light: a line that comes in from the left on focus.
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: root.invalid ? Theme.danger : Theme.textBright
                transform: Scale { origin.x: 0; xScale: input.activeFocus ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            }
            HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
        }

        Words {
            visible: root.error !== "" || root.hint !== ""
            width: parent.width
            small: true
            text: root.error !== "" ? root.error : root.hint
            color: root.error !== "" ? Theme.dangerText : Theme.textQuiet
        }
    }
}

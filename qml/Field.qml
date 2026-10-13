pragma ComponentBehavior: Bound
import QtQuick

/*
    A label and an input in a bracketed well (FieldFrame): the brackets
    take the world's light under the pointer and with the keys, when a light
    runs in along its foot. `bare` leaves the well out, for a field that
    sits in a panel of its own (the palette's). Errors say what to do, in
    sentence case.

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
    /** No well: only the text, for a field in a panel of its own. */
    property bool bare: false
    property alias readOnly: input.readOnly
    /** The colour of what is typed (its placeholder the same, faint): the words' on glass, or the ink on a panel of the light (the palette's drawer). */
    property color ink: Theme.text
    /** Its placeholder's colour: the words' faint, or the ink held back. */
    property color faintInk: ink === Theme.text ? Theme.textFaint : Theme.tint(ink, 0.62)
    property alias input: input
    signal accepted()
    /** The field was left, or Enter pressed, with its text changed since it was entered. */
    signal edited()
    property string entered: ""

    readonly property bool invalid: error !== ""

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
            height: Theme.control

            FieldFrame { id: well; visible: !root.bare; anchors.fill: parent; lit: input.activeFocus; hovered: hover.hovered; invalid: root.invalid }
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: root.bare ? 0 : well.pad
                anchors.rightMargin: root.bare ? 0 : well.pad
                verticalAlignment: TextInput.AlignVCenter
                font.family: root.jp ? Theme.fontJp : Theme.font
                font.pixelSize: Theme.textM
                font.weight: Theme.weightValue
                color: root.enabled ? root.ink : Theme.textFaint
                selectionColor: root.ink
                selectedTextColor: Theme.textInverse
                maximumLength: root.maxLength
                echoMode: root.password ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                clip: true
                focus: true
                validator: root.time ? timeRule : root.numeric ? numberRule : null
                inputMethodHints: root.numeric ? Qt.ImhFormattedNumbersOnly : root.time ? Qt.ImhDigitsOnly : Qt.ImhNone
                onAccepted: root.accepted()
                // Left alone, it shows how the text starts; given the keys, the cursor waits at
                // the end (a click puts it where it lands, after this).
                onActiveFocusChanged: { if (activeFocus) { root.entered = text; cursorPosition = text.length } else cursorPosition = 0 }
                onTextChanged: if (!activeFocus) cursorPosition = 0
                onEditingFinished: if (text !== root.entered) { root.entered = text; root.edited() }
                // A time, or nothing (an emptied time field is a change like any other).
                RegularExpressionValidator { id: timeRule; regularExpression: /^(([01]?\d|2[0-3]):[0-5]\d)?$/ }
                RegularExpressionValidator { id: numberRule; regularExpression: /^\d*([.,]\d*)?$/ }
                // Blinks while the field has the keys, in steps (on, off), so a focused field asks for
                // two frames a second, not every one; gone (not frozen off) when it hasn't the keys.
                cursorDelegate: Caret { cursorVisible: input.cursorVisible; at: input.cursorPosition }
            }
            Text {
                anchors.fill: input
                verticalAlignment: Text.AlignVCenter
                text: root.placeholder
                visible: input.text === "" && !input.inputMethodComposing
                font: input.font
                color: root.faintInk
                elide: Text.ElideRight
            }
            // A bare field keeps only its foot's light.
            Underline { visible: root.bare && root.ink === Theme.text; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; resting: false; lit: input.activeFocus; invalid: root.invalid }
            HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.IBeamCursor }
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

pragma ComponentBehavior: Bound
import QtQuick

/*
    Writing more than a line, e.g. a diary; grows as you type. A label, an
    underline that lights on focus. `large` writes at reading size with no
    label, for a page of writing (Terra's Write screen); `single` takes
    Enter as the way on (`accepted`), for an answer that is one thought
    however long it runs. Escape gives the keys back to the window.

        TextArea { label: "Your notes"; hint: "Kept as you leave the field"; text: notes }
        TextArea { large: true; name: "Today"; minLines: 6; placeholder: "Write as much or as little as you like." }
*/
FocusScope {
    id: root

    property string label: ""
    property alias text: edit.text
    property string placeholder: ""
    property string hint: ""
    property int minLines: 3
    property bool jp: false
    /** Reading size, a line's height from the font, for writing at length. */
    property bool large: false
    /** Enter on its own is the way on (`accepted`); Shift or Ctrl with it is left to the window. */
    property bool single: false
    /** What it is, for a screen reader, when no label shows (the question is above it). */
    property string name: ""
    property alias edit: edit
    /** The colour of what is written: the theme's text, or ink on paper (Terra's notebook in the Yozora look). */
    property color ink: Theme.text
    /** A rule under every line, as on a notebook's page, in this colour; with one the underline gives way to it. Transparent for none. */
    property color ruled: "transparent"
    readonly property bool inked: !Qt.colorEqual(ink, Theme.text)
    signal accepted()

    implicitWidth: large ? 320 : 240
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.EditableText
    Accessible.name: label !== "" ? label : name !== "" ? name : placeholder

    /** Gives it the keys. */
    function focusIn() { edit.forceActiveFocus() }

    FontMetrics { id: metrics; font: edit.font }

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Label { visible: root.label !== ""; text: root.label; width: parent.width; color: root.enabled ? Theme.textBright : Theme.textQuiet }

        Item {
            width: parent.width
            height: root.large ? Math.max(root.minLines * metrics.lineSpacing, edit.implicitHeight) + Theme.s3
                : Math.max(root.minLines * Theme.textM * 1.6, edit.implicitHeight) + 12

            TextEdit {
                id: edit
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.topMargin: root.large ? 0 : 4
                font.family: root.jp ? Theme.fontJp : Theme.font
                font.pixelSize: root.large ? Theme.textL : Theme.textM
                font.weight: Theme.weightValue
                color: root.enabled ? root.ink : root.inked ? Theme.tint(root.ink, 0.62) : Theme.textFaint
                selectionColor: root.ink
                selectedTextColor: root.inked ? "#ffffff" : Theme.space
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                focus: true
                Keys.onReturnPressed: event => root.enter(event)
                Keys.onEnterPressed: event => root.enter(event)
                Keys.onEscapePressed: { const s = Theme.screenOf(root); if (s && s.shell) s.shell.forceActiveFocus() }
                // Tab moves on, as in every other field; plain text has no use for a tab.
                Keys.onTabPressed: event => { const n = edit.nextItemInFocusChain(true); if (n) n.forceActiveFocus(Qt.TabFocusReason); event.accepted = true }
                Keys.onBacktabPressed: event => { const n = root.nextItemInFocusChain(false); if (n) n.forceActiveFocus(Qt.BacktabFocusReason); event.accepted = true }
                cursorDelegate: Caret { cursorVisible: edit.cursorVisible; at: edit.cursorPosition; color: root.inked ? root.ink : Theme.textBright }
            }
            // The page's rules: one under each line the box holds, written or not.
            Repeater {
                model: root.ruled.a > 0 ? Math.max(1, Math.floor(parent.height / metrics.lineSpacing)) : 0
                delegate: Rectangle {
                    required property int index
                    x: 0
                    y: edit.y + (index + 1) * metrics.lineSpacing + 1
                    width: parent.width
                    height: 1
                    color: root.ruled
                }
            }
            Text {
                anchors.fill: edit
                text: root.placeholder
                visible: edit.text === "" && !edit.inputMethodComposing
                font: edit.font
                color: root.inked ? Theme.tint(root.ink, 0.62) : Theme.textFaint
                wrapMode: Text.Wrap
            }
            Underline { visible: root.ruled.a === 0; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; lit: edit.activeFocus; hovered: hover.hovered }
            HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.IBeamCursor }
        }

        Words { visible: root.hint !== ""; text: root.hint; small: true; quiet: true; width: parent.width }
    }

    // Enter on its own is the way on in a single answer; otherwise (or with a modifier) a new line, or the window's (Ctrl+Enter).
    function enter(event) {
        if (!single || (event.modifiers & ~Qt.KeypadModifier) !== Qt.NoModifier) { event.accepted = false; return }
        event.accepted = true
        accepted()
    }
}

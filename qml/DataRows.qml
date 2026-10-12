pragma ComponentBehavior: Bound
import QtQuick

/*
    Facts as `Label: value`. The label is quiet and says what it is; the
    value is bright and says what it is now, so the eye lands on it first.
    A value that changes fades to the new one.

        DataRows { rows: [{ label: "Streak", value: "12 days" }, { label: "Path", value: p, keepCase: true }] }
*/
Column {
    id: root

    property var rows: []
    /** Where each row sits across the width: `Text.AlignLeft`, `AlignHCenter` or `AlignRight`. */
    property int align: Text.AlignLeft

    readonly property int size: 12

    Repeater {
        model: root.rows
        delegate: Row {
            id: row
            required property var modelData
            x: root.align === Text.AlignRight ? root.width - implicitWidth : root.align === Text.AlignHCenter ? (root.width - implicitWidth) / 2 : 0
            spacing: 4
            Text {
                id: label
                text: row.modelData.label + ":"
                // Both fit when they can; else the value keeps up to half the row and the label elides.
                width: Math.min(implicitWidth, Math.max(root.width * 0.3, root.width - row.spacing - Math.min(value.implicitWidth, root.width * 0.5)))
                elide: Text.ElideRight
                font.family: Theme.fontCaps
                font.weight: Theme.weightLabel
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(Theme.trackRows, root.size)
                font.capitalization: Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.textQuiet
            }
            Text {
                id: value
                // Nothing to say yet: a dash, not an empty gap after the label.
                readonly property bool empty: row.modelData.value === undefined || row.modelData.value === null || String(row.modelData.value) === ""
                text: empty ? "—" : row.modelData.value
                width: Math.max(0, Math.min(implicitWidth, root.width - label.width - row.spacing))
                // A value kept in its own case is words (a name, a sentence): the body face, even in the look.
                font.family: row.modelData.keepCase ? Theme.font : Theme.fontCaps
                font.weight: Theme.weightName
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(row.modelData.keepCase ? 0.02 : Theme.trackRows, root.size)
                font.capitalization: row.modelData.keepCase ? Font.MixedCase : Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: empty ? Theme.textFaint : Theme.text
                elide: Text.ElideMiddle
                onTextChanged: fade.restart()
                NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
            }
        }
    }
}

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
                text: row.modelData.label + ":"
                font.family: Theme.font
                font.weight: Theme.weightLabel
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(Theme.trackRows, root.size)
                font.capitalization: Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.textQuiet
            }
            Text {
                id: value
                text: row.modelData.value
                width: Math.min(implicitWidth, root.width - 80)
                font.family: Theme.font
                font.weight: Theme.weightName
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(row.modelData.keepCase ? 0.02 : Theme.trackRows, root.size)
                font.capitalization: row.modelData.keepCase ? Font.MixedCase : Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.text
                elide: Text.ElideMiddle
                onTextChanged: fade.restart()
                NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
            }
        }
    }
}

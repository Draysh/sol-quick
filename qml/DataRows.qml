pragma ComponentBehavior: Bound
import QtQuick

/*
    Facts as `Label: value`. The label is quiet HUD capitals and says what
    it is; the value is bright, as written in the sans, and says what it is
    now, so the eye lands on it first. A value that changes fades to the
    new one. As a `ledger` (Settings' cards) each fact is a line of its
    own across the width, the label on the left and the value at the right
    end, a hairline between them.

        DataRows { rows: [{ label: "Streak", value: "12 days" }, { label: "Path", value: p }] }
        DataRows { ledger: true; width: parent.width; rows: … }
*/
Column {
    id: root

    property var rows: []
    /** Where each row sits across the width: `Text.AlignLeft`, `AlignHCenter` or `AlignRight`. */
    property int align: Text.AlignLeft
    /** Each fact a line across the width: the label left, the value at the right end, hairlines between. */
    property bool ledger: false

    readonly property int size: 12

    Repeater {
        model: root.rows
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property real spacing: root.ledger ? Theme.s3 : 4
            width: root.ledger ? root.width : label.width + spacing + value.width
            height: Math.max(label.height, value.height) + (root.ledger ? Theme.s1 : 0)
            x: root.ledger ? 0 : root.align === Text.AlignRight ? root.width - width : root.align === Text.AlignHCenter ? (root.width - width) / 2 : 0
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label + (root.ledger ? "" : ":")
                // Both fit when they can; else the value keeps up to half the row (more on a ledger) and the label elides.
                width: Math.min(implicitWidth, Math.max(root.width * 0.3, root.width - row.spacing - Math.min(value.implicitWidth, root.width * (root.ledger ? 0.6 : 0.5))))
                elide: Text.ElideRight
                readonly property bool caps: Theme.capsFor(row.modelData.label)
                font.family: caps ? Theme.fontCaps : Theme.font
                font.weight: Theme.weightLabel
                font.pixelSize: root.size
                font.letterSpacing: caps ? Theme.track(Theme.trackRows, root.size) : 0
                font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.textQuiet
            }
            Text {
                id: value
                anchors.verticalCenter: parent.verticalCenter
                x: root.ledger ? row.width - width : label.width + row.spacing
                // Nothing to say yet: a dash, not an empty gap after the label.
                readonly property bool empty: row.modelData.value === undefined || row.modelData.value === null || String(row.modelData.value) === ""
                text: empty ? "—" : row.modelData.value
                width: Math.max(0, Math.min(implicitWidth, root.width - label.width - row.spacing))
                horizontalAlignment: root.ledger ? Text.AlignRight : Text.AlignLeft
                // Values are words and figures as written, in the sans (`keepCase` is no longer needed).
                font.family: Theme.font
                font.weight: Theme.weightName
                font.pixelSize: root.size + 1
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: empty ? Theme.textFaint : Theme.text
                elide: Text.ElideMiddle
                onTextChanged: fade.restart()
                NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
            }
            Rectangle { visible: root.ledger && row.index < root.rows.length - 1; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
        }
    }
}

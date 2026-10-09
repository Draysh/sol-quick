import QtQuick

/*
    Facts as `Label: value`. Semibold says what it is; light says what it
    is now. A value that changes fades to the new one.

        DataRows { rows: [{ label: "Streak", value: "12 days" }, { label: "Path", value: p, keepCase: true }] }
*/
Column {
    id: root

    property var rows: []
    property int align: Text.AlignLeft
    property bool medium: false

    readonly property int size: medium ? Theme.textS : 12

    Repeater {
        model: root.rows
        delegate: Row {
            required property var modelData
            x: root.align === Text.AlignRight ? root.width - implicitWidth : root.align === Text.AlignHCenter ? (root.width - implicitWidth) / 2 : 0
            spacing: 4
            Text {
                text: modelData.label + ":"
                font.family: Theme.font
                font.weight: Theme.weightLabel
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(Theme.trackRows, root.size)
                font.capitalization: Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.textBright
            }
            Text {
                id: value
                text: modelData.value
                width: Math.min(implicitWidth, root.width - 80)
                font.family: Theme.font
                font.weight: Theme.weightValue
                font.pixelSize: root.size
                font.letterSpacing: Theme.track(modelData.keepCase ? 0.02 : Theme.trackRows, root.size)
                font.capitalization: modelData.keepCase ? Font.MixedCase : Font.AllUppercase
                lineHeight: 2; lineHeightMode: Text.ProportionalHeight
                color: Theme.textValue
                elide: Text.ElideMiddle
                onTextChanged: fade.restart()
                NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
            }
        }
    }
}

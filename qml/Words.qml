import QtQuick

/*
    Reading text, in sentence case: messages, descriptions, diary entries.
    `quiet` for a note under something, `small` for a smaller size, `jp`
    for Japanese in Mercury's face.
*/
Text {
    property bool quiet: false
    property bool small: false
    property bool jp: false

    font.family: jp ? Theme.fontJp : Theme.font
    font.weight: Theme.weightValue
    font.pixelSize: small || quiet ? Theme.textS : Theme.textM
    lineHeight: 1.5
    lineHeightMode: Text.ProportionalHeight
    color: quiet ? Theme.textQuiet : Theme.textValue
    wrapMode: Text.Wrap
}

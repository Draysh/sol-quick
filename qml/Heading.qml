import QtQuick

/* A heading in the name style: capitals, tracked. `level` 1 is a world's name size, 2 a card's, 3 a line's. */
Text {
    property int level: 2

    font.family: Theme.font
    font.weight: Theme.weightName
    readonly property int size: level === 1 ? Theme.textXl : level === 2 ? Theme.textL : Theme.textM
    font.pixelSize: size
    font.letterSpacing: Theme.track(level === 3 ? Theme.trackCaps : Theme.trackName, size)
    font.capitalization: Font.AllUppercase
    lineHeight: 1.1
    lineHeightMode: Text.ProportionalHeight
    color: Theme.text
    elide: Text.ElideRight
}

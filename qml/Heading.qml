import QtQuick

/*
    A heading in the name style: capitals, tracked. `level` 1 is a world's name size, 2 a card's, 3 a line's.
    In the Yozora look the first two are set in the title serif as written, the third in the mono face.
*/
Text {
    property int level: 2

    font.family: Theme.yozora ? (level === 3 ? Theme.fontMono : Theme.fontTitle) : Theme.font
    font.weight: Theme.yozora && level < 3 ? Font.Black : Theme.weightName
    readonly property int size: level === 1 ? Theme.textXl : level === 2 ? Theme.textL : Theme.textM
    font.pixelSize: size
    font.letterSpacing: Theme.yozora && level < 3 ? 0 : Theme.track(level === 3 ? Theme.trackCaps : Theme.trackName, size)
    font.capitalization: Theme.yozora && level < 3 ? Font.MixedCase : Font.AllUppercase
    lineHeight: 1.1
    lineHeightMode: Text.ProportionalHeight
    color: Theme.text
    elide: Text.ElideRight
}

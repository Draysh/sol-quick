import QtQuick

/*
    A heading. `level` 1 is a world's name size, 2 a card's: both in the
    title face (the display face under the face's floor, `Theme.titleFloor`), as written, its punctuation set close. 3 is a line's: HUD
    capitals, tracked (as written, in the sans, when it is more than a
    label of a few words or has Japanese in it).
*/
Text {
    property int level: 2

    property bool caps: level === 3 && Theme.capsFor(text)
    font.family: level < 3 ? Theme.titleFace(size) : caps ? Theme.fontCaps : Theme.font
    font.weight: level < 3 ? Theme.titleWeight(size) : Theme.weightName
    readonly property int size: level === 1 ? Theme.textXl : level === 2 ? Theme.textL : Theme.textM
    font.pixelSize: size
    font.letterSpacing: caps ? Theme.track(Theme.trackCaps, size) : 0
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    font.features: level < 3 ? Theme.titleFeatures : ({})
    lineHeight: 1.1
    lineHeightMode: Text.ProportionalHeight
    color: Theme.text
    elide: Text.ElideRight
}

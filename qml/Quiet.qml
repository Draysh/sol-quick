import QtQuick

/*
    Quiet words: dates, units, secondary facts. A few words are HUD
    capitals; a sentence, or anything with Japanese in it, is set as
    written in the sans, a size up (`caps: false` sets a short one so too).
*/
Text {
    /** Whether it is set in capitals: one to three words with no Japanese. */
    property bool caps: Theme.capsFor(text)
    font.family: caps ? Theme.fontCaps : Theme.font
    font.weight: Theme.weightValue
    font.pixelSize: caps ? Theme.textXs : Theme.textS
    font.letterSpacing: caps ? Theme.track(Theme.trackCaps, Theme.textXs) : 0
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    color: Theme.textQuiet
    elide: Text.ElideRight
}

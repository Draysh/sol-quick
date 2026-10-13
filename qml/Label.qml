import QtQuick

/*
    A label: what something is. Semibold HUD capitals; a longer one, or one
    with Japanese, as written in the sans (`caps: false` sets one so too).
*/
Text {
    /** Whether it is set in capitals: a label of one to three words with no Japanese. */
    property bool caps: Theme.capsFor(text)
    font.family: caps ? Theme.fontCaps : Theme.font
    font.weight: Theme.weightLabel
    font.pixelSize: Theme.textXs
    font.letterSpacing: caps ? Theme.track(Theme.trackLabel, Theme.textXs) : 0
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    color: Theme.textBright
    elide: Text.ElideRight
}

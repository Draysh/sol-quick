import QtQuick

/* Quiet capitals: dates, units, secondary facts. */
Text {
    font.family: Theme.fontCaps
    font.weight: Theme.weightValue
    font.pixelSize: Theme.textXs
    font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs)
    font.capitalization: Font.AllUppercase
    color: Theme.textQuiet
    elide: Text.ElideRight
}

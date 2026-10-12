import QtQuick

/* A label: what something is. Semibold capitals. */
Text {
    font.family: Theme.fontCaps
    font.weight: Theme.weightLabel
    font.pixelSize: Theme.textXs
    font.letterSpacing: Theme.track(Theme.trackLabel, Theme.textXs)
    font.capitalization: Font.AllUppercase
    color: Theme.textBright
    elide: Text.ElideRight
}

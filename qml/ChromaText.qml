import QtQuick

/*
    A big title that splits its colours at the edges with the flavour's
    `chroma` (Neptune's): a red ghost of the words a step to one side and a
    cyan one a step to the other, behind them, as a cheap screen in the
    rain shows them. With any other flavour it is a plain Text. For titles
    of about 40 px and more; small words would only blur.

        ChromaText { text: "Quiet Static"; font.family: Theme.fontTitle; font.pixelSize: 64 }
*/
Text {
    id: root

    /** How far each ghost stands off the words, in pixels: more on larger words. */
    property real spread: Math.max(1, Math.round(font.pixelSize / 36))

    component Ghost: Text {
        /** The words it is the ghost of. */
        required property Text words
        visible: !!Theme.hud.chroma
        z: -1
        width: words.width
        height: words.height
        text: words.text
        font: words.font
        textFormat: words.textFormat
        wrapMode: words.wrapMode
        maximumLineCount: words.maximumLineCount
        elide: words.elide
        fontSizeMode: words.fontSizeMode
        minimumPixelSize: words.minimumPixelSize
        horizontalAlignment: words.horizontalAlignment
        verticalAlignment: words.verticalAlignment
        lineHeight: words.lineHeight
        lineHeightMode: words.lineHeightMode
        opacity: 0.75
    }
    Ghost { words: root; x: root.spread; color: Theme.hudAccent }
    Ghost { words: root; x: -root.spread; color: Theme.hudSecond }
}

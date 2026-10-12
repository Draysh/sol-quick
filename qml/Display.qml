import QtQuick

/*
    A display figure: thin, big, counting up to its value as it appears, so
    a number arrives rather than being there. Follows later values the
    same way.

        Display { value: stats.ticks }
        Display { value: minutes; format: m => Math.round(m / 60) + " h" }
*/
Text {
    id: root

    property real value: 0
    /** What the text is for a value; by default the rounded number. */
    property var format: v => String(Math.round(v))
    property real shown: 0
    property bool first: true

    // In the Yozora look a figure is the HUD's: the mono face, a little heavier.
    font.family: Theme.yozora ? Theme.fontMono : Theme.font
    font.weight: Theme.yozora ? Font.Medium : Theme.weightDisplay
    property int size: 44
    font.pixelSize: size
    font.letterSpacing: Theme.track(Theme.yozora ? -0.02 : 0.04, size)
    color: Theme.text
    text: format(shown)

    onValueChanged: count()
    Component.onCompleted: count()

    function count() {
        run.stop()
        const from = first ? 0 : shown
        first = false
        run.from = from
        run.to = value
        run.start()
    }

    NumberAnimation {
        id: run
        target: root
        property: "shown"
        duration: Theme.rise
        easing.type: Easing.OutCubic
    }
}

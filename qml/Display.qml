import QtQuick

/*
    A display figure: big, in the HUD face, counting up to its value as it appears, so
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

    // A figure is the HUD's: its squared face, medium.
    font.family: Theme.fontHud
    font.weight: Font.Medium
    property int size: 44
    font.pixelSize: size
    font.letterSpacing: Theme.track(0.01, size)
    color: Theme.text
    text: format(shown)

    // It counts once it is in view (not while far down a page), and with less motion is there at once.
    property bool seen: false
    property var forget: null
    onValueChanged: if (seen) count()
    Component.onCompleted: forget = Theme.whenSeen(root, () => { seen = true; count() })
    Component.onDestruction: if (forget) forget()

    function count() {
        run.stop()
        const from = first ? 0 : shown
        first = false
        if (Theme.calm || Theme.count === 0) { shown = value; return }
        run.from = from
        run.to = value
        run.start()
    }
    Settling { when: run.running }

    NumberAnimation {
        id: run
        target: root
        property: "shown"
        duration: Theme.count
        easing: Theme.easeOut
    }
}

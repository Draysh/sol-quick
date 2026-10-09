import QtQuick

/*
    The text cursor every field draws: a hairline that blinks in steps,
    on and off about twice a second, so a field with the keys asks for two
    frames a second and no more; it shows at once again as you type or
    move it, and stops (showing nothing) when the field hasn't the keys or
    the window is asleep.

        TextInput { cursorDelegate: Caret { cursorVisible: input.cursorVisible; at: input.cursorPosition } }
*/
Rectangle {
    id: caret

    /** The field's own `cursorVisible`. */
    property bool cursorVisible: false
    /** The field's cursor position: a move shows the caret again at once. */
    property int at: 0
    property bool lit: true

    width: 1
    color: Theme.textBright
    visible: cursorVisible && lit

    onAtChanged: { lit = true; blink.restart() }
    onCursorVisibleChanged: lit = true
    Timer {
        id: blink
        interval: 530
        repeat: true
        running: caret.cursorVisible && Theme.alive
        onTriggered: caret.lit = !caret.lit
        onRunningChanged: caret.lit = true
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    Words that can be changed in place: click them and type; Enter or
    clicking away keeps the change, Escape drops it. Looks like the text it
    replaces, in any size, with the line lighting up under it while open.

        Editable { text: list.name; size: Theme.text2xl; onCommitted: name => rename(name) }
*/
Item {
    id: root

    property string text: ""
    property int size: Theme.textM
    property int weight: Theme.weightValue
    property color color: Theme.textValue
    property string placeholder: "…"
    property bool editing: false
    property string hint: "Click to change"
    /** In capitals, tracked, like a `Heading` (a page's title that can be renamed). */
    property bool caps: false
    signal committed(string text)

    implicitWidth: editing ? Math.max(120, input.implicitWidth + 24) : label.implicitWidth + 8
    implicitHeight: Math.max(label.implicitHeight, input.implicitHeight) + 8

    function open() { if (editing) return; input.text = text; editing = true; Qt.callLater(() => { input.forceActiveFocus(); input.selectAll() }) }
    function keep() { const t = input.text.trim(); editing = false; if (t !== "" && t !== text) committed(t) }
    function drop() { editing = false }

    Text {
        id: label
        visible: !root.editing
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.text !== "" ? root.text : root.placeholder
        font.family: Theme.font; font.pixelSize: root.size; font.weight: root.weight
        font.letterSpacing: root.caps ? Theme.track(Theme.trackCaps, root.size) : root.size >= Theme.textXl ? Theme.track(Theme.trackDisplay, root.size) : 0
        font.capitalization: root.caps ? Font.AllUppercase : Font.MixedCase
        color: mouse.containsMouse ? Theme.textBright : root.color
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    // The pen: a hairline under the words while pointing at them.
    Rectangle { visible: !root.editing; x: 4; anchors.bottom: parent.bottom; width: label.implicitWidth; height: 1; color: Theme.lineStrong; opacity: mouse.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fade } } }
    MouseArea { id: mouse; visible: !root.editing; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.IBeamCursor; onClicked: root.open() }
    Hint { text: root.hint; when: mouse.containsMouse && !root.editing }

    TextInput {
        id: input
        visible: root.editing
        x: 4
        width: Math.max(parent.width - 8, 100)
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font; font.pixelSize: root.size; font.weight: root.weight
        font.letterSpacing: label.font.letterSpacing
        font.capitalization: label.font.capitalization
        color: Theme.textBright
        selectionColor: Theme.text; selectedTextColor: Theme.space
        clip: true
        onAccepted: root.keep()
        onActiveFocusChanged: if (!activeFocus && root.editing) root.keep()
        Keys.onEscapePressed: root.drop()
        cursorDelegate: Rectangle { width: 1; color: Theme.textBright; visible: input.cursorVisible }
    }
    Rectangle { visible: root.editing; x: 4; anchors.bottom: parent.bottom; width: input.width; height: 1; color: Theme.textBright
        transform: Scale { origin.x: 0; xScale: root.editing ? 1 : 0; Behavior on xScale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } } }
}

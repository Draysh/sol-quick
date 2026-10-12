import QtQuick
import QtQuick.Shapes

/*
    A button cut as a parallelogram (its sides at the Yozora look's lean),
    for the one thing a card is for: "Play". Filled in a light with dark
    words, or, `outline`, a hairline in the light with the words in it.
    Words in the mono face, upper case.

        AngledButton { text: "Play"; icon: "play"; onClicked: … }
*/
Item {
    id: root

    property string text: ""
    /** An `Icon` name before the words, or "" for none. */
    property string icon: ""
    property color light: Theme.hudAccent
    /** Only its outline in the light, for a second choice beside the first. */
    property bool outline: false
    /** What the pointer's hint says. */
    property string hint: ""
    signal clicked()

    /** How far the top leans past the bottom. */
    readonly property real lean: height * 0.36
    readonly property color ink: outline ? (mouse.containsMouse ? Theme.dusk : light) : Theme.dusk

    implicitHeight: Theme.control
    implicitWidth: words.implicitWidth + lean + Theme.s4 * 2
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text || hint
    Accessible.onPressAction: clicked()
    Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { event.accepted = true; if (!event.isAutoRepeat) root.clicked() } }

    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.lock } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.outline || root.activeFocus ? 1 : 0
            strokeColor: root.outline ? root.light : root.activeFocus ? Theme.hudText : "transparent"
            fillColor: root.outline ? (mouse.containsMouse ? root.light : Qt.rgba(0, 0, 0, 0.35)) : mouse.containsMouse ? Qt.lighter(root.light, 1.08) : root.light
            startX: root.lean; startY: 0.5
            PathLine { x: root.width - 0.5; y: 0.5 }
            PathLine { x: root.width - root.lean; y: root.height - 0.5 }
            PathLine { x: 0.5; y: root.height - 0.5 }
            PathLine { x: root.lean; y: 0.5 }
        }
    }
    Row {
        id: words
        anchors.centerIn: parent
        spacing: Theme.s2
        Icon { visible: root.icon !== ""; anchors.verticalCenter: parent.verticalCenter; name: root.icon || "play"; size: 13; stroke: 2; color: root.ink }
        Text {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.fontMono; font.pixelSize: Theme.textXs; font.weight: Font.Bold
            font.letterSpacing: Theme.track(0.16, Theme.textXs); font.capitalization: Font.AllUppercase
            color: root.ink
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Hint { text: root.hint; when: mouse.containsMouse && root.hint !== ""; above: true }
}

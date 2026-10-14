import QtQuick
import QtQuick.Effects

/*
    A small choice: a word on a dark pill with a hairline round it (HUD
    capitals for a few words, else as written). Pressed, it takes the
    world's light. `tag` draws it smaller, with a # before the word. Space
    or Enter presses it from the keys.

        Chip { text: "Good"; on: mood === 4; onClicked: mood = 4 }
*/
Item {
    id: root

    property string text: ""
    property bool on: false
    property bool tag: false
    signal clicked()
    onClicked: Sounds.tick()

    implicitWidth: words.implicitWidth + (tag ? 20 : 28)
    implicitHeight: tag ? 30 : Theme.control
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: on
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            if (!event.isAutoRepeat) root.clicked()
        }
    }

    RectangularShadow {
        anchors.fill: face
        radius: face.radius
        blur: 18
        color: Theme.tint(Theme.world, root.on ? 0.25 : 0)
        Behavior on color { ColorAnimation { duration: Theme.settle } }
    }
    Rectangle {
        id: face
        anchors.fill: parent
        radius: height / 2
        color: root.on ? Theme.tint(Theme.hudAccent, 0.18) : Theme.tint(Theme.hud.ground, mouse.containsMouse ? 0.75 : 0.55)
        border.width: 1
        border.color: !root.enabled ? Theme.line : root.on ? Theme.accent : mouse.containsMouse ? Theme.lineStrong : Theme.lineMid
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
    }
    Text {
        id: words
        anchors.centerIn: parent
        text: (root.tag ? "<font color='" + Theme.textFaint + "'>#</font>" : "") + root.text
        textFormat: Text.StyledText
        // A few words are HUD capitals; a longer name, or Japanese, as written in the sans.
        readonly property bool caps: Theme.capsFor(root.text)
        font.family: caps ? Theme.fontCaps : Theme.font
        font.pixelSize: caps ? Theme.textXs : Theme.textS
        font.weight: caps ? Font.DemiBold : Theme.weightName
        font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: caps ? Theme.track(Theme.trackCaps, Theme.textXs) : 0
        color: !root.enabled ? Theme.textFaint : root.on ? Theme.hudAccentText : mouse.containsMouse ? Theme.textBright : Theme.textQuiet
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.lock } }
    Ticks { on: root.activeFocus; out: 5; radius: face.radius }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.clicked() }
}

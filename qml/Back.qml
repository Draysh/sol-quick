import QtQuick

/*
    The way back to the page this one was opened from: always the same
    words, 「← 戻る」 BACK, the chevron and the Japanese in the world's
    light under the pointer; the page it leads to (`label`) is in its hint.
    The PageHead places it at its start.

        Back { label: "Library"; onGo: shell.back() }
*/
Item {
    id: root

    /** The page it goes back to, for its hint and for a screen reader. */
    property string label: "Back"
    /** Kept for pages that set it; the way back always sits in a PageHead now. */
    property bool floating: false
    signal go()

    readonly property bool lit: mouse.containsMouse || activeFocus

    implicitWidth: row.implicitWidth + Theme.s2
    implicitHeight: 32
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Back to " + label
    Accessible.onPressAction: root.go()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            if (!event.isAutoRepeat) root.go()
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s2
        transform: Translate { x: root.lit ? -2 : 0; Behavior on x { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } } }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "「←"
            font.family: Theme.fontTitle; font.pixelSize: Theme.textM; font.weight: Font.Bold
            color: root.lit ? Theme.hudAccent : Theme.hudQuiet
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "戻る」"
            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textM; font.weight: Font.Bold
            color: root.lit ? Theme.hudAccent : Theme.hudText
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Back"
            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: root.lit ? Theme.hudText : Theme.hudQuiet
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }
    Ticks { on: root.activeFocus; out: 4; radius: Theme.radiusM }
    transform: Translate { y: mouse.pressed ? 1 : 0 }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go() }
    Hint { text: "Back to " + root.label + " (Alt+←)"; when: mouse.containsMouse }
}

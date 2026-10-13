import QtQuick

/*
    A link to one of the world's moons, under a first page's title: a small
    diamond in the second light, the moon's name in Japanese and in HUD
    capitals. A carried moon's opens its pages in this window.

        MoonLink { text: "Titan · What to watch"; jp: "タイタン"; onClicked: … }
*/
Item {
    id: root

    property string text: ""
    property string hint: ""
    /** The moon's name in Japanese: "タイタン". */
    property string jp: ""
    signal clicked()

    // From the words' own width, not the width they are given (which follows this).
    /** The diamond and the Japanese before the words. */
    readonly property real lead: 7 + 8 + (jp !== "" ? jpText.implicitWidth + 8 : 0)
    implicitWidth: lead + words.implicitWidth + 8
    implicitHeight: Theme.target
    activeFocusOnTab: true
    Accessible.role: Accessible.Link
    Accessible.name: text
    Accessible.description: hint
    Accessible.onPressAction: clicked()
    Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { event.accepted = true; if (!event.isAutoRepeat) root.clicked() } }
    readonly property bool lit: mouse.containsMouse || activeFocus

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // A small diamond in the second light, and the moon's name in Japanese.
        Rectangle {
            width: 7; height: 7
            anchors.verticalCenter: parent.verticalCenter
            rotation: 45
            antialiasing: true
            color: root.lit ? Theme.artSecond : "transparent"
            border.width: 1; border.color: Theme.artSecond
        }
        Text {
            id: jpText
            visible: root.jp !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.jp
            font.family: Theme.titleFace(Theme.textS + 1); font.features: Theme.titleFeatures; font.pixelSize: Theme.textS + 1; font.weight: Theme.titleWeight(Theme.textS + 1)
            color: Theme.artSecond
        }
        Text {
            id: words
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            // Held to less than it wants (a narrow sheet), the name elides.
            width: Math.max(0, Math.min(implicitWidth, root.width - 8 - root.lead))
            elide: Text.ElideRight
            font.family: Theme.fontCaps
            font.weight: Theme.weightValue
            font.pixelSize: Theme.textXs
            font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs)
            font.capitalization: Font.AllUppercase
            font.underline: root.lit
            color: root.lit ? Theme.artBright : Theme.artText
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
    }
    Item { anchors.centerIn: parent; width: row.width + 12; height: row.height + 12; Ticks { on: root.activeFocus; out: 2; radius: Theme.radiusS } }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Hint { text: root.hint; when: mouse.containsMouse }
}

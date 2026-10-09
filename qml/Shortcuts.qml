import QtQuick

/*
    The keys, on a sheet over the pane: what the Shell does everywhere and
    what this app adds. `?` opens it, Escape or a click outside closes it.
*/
Item {
    id: root

    /** The app's own `{ keys, does }`, shown after the Shell's. */
    property var shortcuts: []
    property bool search: false
    property int sections: 0
    signal closed()

    readonly property var everywhere: [].concat(
        sections ? [{ keys: sections > 1 ? "Ctrl+1 … " + Math.min(sections, 9) : "Ctrl+1", does: "Go to a section, in the order of the sidebar" }] : [],
        [{ keys: "Alt+←  Alt+→", does: "Back and forward, like the mouse’s own buttons" }],
        search ? [{ keys: "/", does: "Search" }] : [],
        [{ keys: "?", does: "This sheet" }])

    anchors.fill: parent
    z: 40
    focus: true
    Keys.onEscapePressed: root.closed()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Settle {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - Theme.s4 * 2)
        height: Math.min(sheet.implicitHeight, parent.height - Theme.s4 * 2)

        Rectangle {
            id: sheet
            anchors.fill: parent
            implicitHeight: body.implicitHeight + 38
            color: Theme.space
            border.width: 1; border.color: Theme.lineMid
            MouseArea { anchors.fill: parent }

            Column {
                id: body
                x: 20; y: 18
                width: parent.width - 40

                Item {
                    width: parent.width; height: Theme.control
                    Label { text: "Keys"; anchors.verticalCenter: parent.verticalCenter }
                    Button { variant: "round"; icon: "close"; anchors.right: parent.right; anchors.rightMargin: -10; anchors.verticalCenter: parent.verticalCenter; onClicked: root.closed() }
                }

                component Group: Item {
                    property string name: ""
                    width: body.width; height: 36
                    Quiet { text: parent.name; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 }
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
                }
                component KeyRow: Item {
                    property string keys: ""
                    property string does: ""
                    width: body.width; height: Math.max(keyText.implicitHeight, doesText.implicitHeight) + Theme.s2 * 2
                    Text {
                        id: keyText
                        y: Theme.s2
                        text: parent.keys
                        width: 150
                        font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textS
                        font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textS); font.capitalization: Font.AllUppercase
                        color: Theme.textBright
                    }
                    Text {
                        id: doesText
                        x: 150 + Theme.s4; y: Theme.s2
                        width: parent.width - x
                        text: parent.does
                        wrapMode: Text.Wrap
                        font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
                        color: Theme.textValue
                    }
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
                }

                Group { name: "Everywhere" }
                Repeater { model: root.everywhere; delegate: KeyRow { required property var modelData; keys: modelData.keys; does: modelData.does } }
                Group { name: "Here"; visible: root.shortcuts.length > 0 }
                Repeater { model: root.shortcuts; delegate: KeyRow { required property var modelData; keys: modelData.keys; does: modelData.does } }
            }
        }
    }
}

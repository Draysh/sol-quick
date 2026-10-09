pragma ComponentBehavior: Bound
import QtQuick

/*
    The keys, on a sheet over the pane: what the Shell does everywhere and
    what this app adds. `?` opens it, Escape (the Shell's) or a click
    outside closes it.
*/
Item {
    id: root

    /** The app's own `{ keys, does }`, shown after the Shell's. */
    property var shortcuts: []
    /** The sidebar's field is there (`/` goes to it). */
    property bool finderShown: false
    /** The app has a search page. */
    property bool search: false
    property int sections: 0
    signal closed()

    readonly property var everywhere: [].concat(
        sections ? [{ keys: sections > 1 ? "Ctrl+1 … " + Math.min(sections, 9) : "Ctrl+1", does: "Go to a section, in the order of the sidebar" }] : [],
        [{ keys: "Alt+←  Alt+→", does: "Back and forward, like the mouse’s own buttons" }],
        [{ keys: "Ctrl+K", does: "Go anywhere, do anything, find what the app holds" }],
        [{ keys: "↑ ↓  PgUp PgDn", does: "Scroll the page; Home and End go to its top and bottom" }],
        finderShown ? [{ keys: "/", does: "The field in the sidebar: it filters this page, or searches" }]
            : search ? [{ keys: "/", does: "Search" }] : [],
        [{ keys: "?", does: "This sheet" }])

    anchors.fill: parent
    z: 40

    Rectangle {
        anchors.fill: parent
        color: Theme.tint(Theme.veil, 0.6)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Settle {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - Theme.s4 * 2)
        height: Math.min(body.implicitHeight + 38, parent.height - Theme.s4 * 2)

        // A panel like the dialog's: raised off the dimmed page, lit from above.
        Rectangle {
            id: sheet
            anchors.fill: parent
            radius: Theme.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.raisedTop }
                GradientStop { position: 1; color: Theme.raised }
            }
            border.width: 1; border.color: Theme.lineMid
            MouseArea { anchors.fill: parent }

            // Taller than the window: it scrolls.
            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                contentHeight: body.implicitHeight + 36
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

            Column {
                id: body
                x: 19; y: 17
                width: sheet.width - 40
                /** The keys' column: as wide as they need, up to 150, never more than two fifths. */
                readonly property real keysWidth: Math.min(150, width * 0.4)

                Item {
                    width: parent.width; height: Theme.control
                    Label { text: "Keys"; color: Theme.textWorld; anchors.verticalCenter: parent.verticalCenter }
                    Button { variant: "round"; icon: "close"; hint: "Close (Esc)"; anchors.right: parent.right; anchors.rightMargin: -10; anchors.verticalCenter: parent.verticalCenter; onClicked: root.closed() }
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
                        width: body.keysWidth
                        wrapMode: Text.Wrap
                        font.family: Theme.font; font.weight: Theme.weightLabel; font.pixelSize: Theme.textS
                        font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textS); font.capitalization: Font.AllUppercase
                        color: Theme.textBright
                    }
                    Text {
                        id: doesText
                        x: body.keysWidth + Theme.s3; y: Theme.s2
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
}

pragma ComponentBehavior: Bound
import QtQuick
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    A world's Settings page as a system menu: its parts listed on the left
    (numbered, with their Japanese), the chosen one's cards in one panel on
    the right, as a game's system menu stands: at the start of the pane,
    the panel no wider than its rows read well, the rest of a wide window
    left to the still. The kit brings Sol (the connection and the world's settings
    as set there), Export, This device and Updates, and a part for each
    moon the app carries (its own settings, `Moon.settings`); the world adds
    its own SettingsParts as children. The part on show is in the page's
    path (`/settings?part=services`, and `/<moon>/settings` opens the
    moon's). On a narrow pane the list is a row of tabs over the panel.

        SettingsScreen {
            lead: "Saturn keeps its data and settings in your Sol; every device reads the same."
            SettingsPart { key: "services"; label: "Services"; jp: "連携"; Card { title: "TMDB"; … } }
        }
*/
Design.Screen {
    id: page

    title: "Settings"
    // The list and a panel of rows that read well, at the start: a wide window's room is the still's.
    maxWidth: 232 + Theme.s4 + 720
    /** The line beside the title. */
    property string lead: ""
    /** The parts: the kit's below, then the world's children. */
    default property alias parts: stack.data

    header: Design.PageHead { title: "Settings"; jp: "設定"; lead: page.lead }

    /** The parts on offer, in order; a world's part takes the place of the kit's with its key. */
    property var offered: []
    function refresh() {
        const all = Array.from(stack.children).filter(c => c.hasOwnProperty("key") && c.hasOwnProperty("order") && c.key !== "")
        const byKey = {}
        for (const c of all) {
            if (!c.available) continue
            byKey[c.key] = c
        }
        offered = Object.values(byKey).sort((a, b) => a.order - b.order || all.indexOf(a) - all.indexOf(b))
    }
    Component.onCompleted: Qt.callLater(refresh)
    readonly property string asked: params && params.part ? String(params.part) : ""
    readonly property var current: offered.find(p => p.key === asked) || offered[0] || null
    function choose(key) {
        if (current && current.key === key) return
        if (shell && shell.page === page) shell.retab(Object.assign({}, params, { part: key }))
        else params = Object.assign({}, params, { part: key })
        page.flickable.contentY = 0
    }

    readonly property bool narrow: contentWidth < 760
    readonly property real listWidth: narrow ? contentWidth : 232

    content: [
        Item {
            id: menu
            width: parent ? parent.width : 0
            height: Math.max(list.visible ? list.height : 0, panel.y + stack.height)

            // On a light flavour's still (Terra's noon) the list stands on glass, as the rail does,
            // so its dark words read; over a dark one it is bare. Its edges are the page's: its
            // left on the one left edge, its top level with the cards beside it.
            Design.HudGlass {
                visible: Theme.light && list.visible
                width: list.width
                height: list.height
                cuts: [0, Theme.hudCut, 0, 0]
            }
            // The parts: a numbered list, the chosen one lit.
            Column {
                id: list
                visible: !page.narrow
                width: page.listWidth
                topPadding: Theme.light ? Theme.s2 : 0
                bottomPadding: topPadding
                spacing: 2
                Repeater {
                    model: page.offered
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: page.current === modelData
                        width: list.width
                        height: Theme.control + 4
                        Rectangle {
                            anchors.fill: parent
                            opacity: row.on ? 1 : rowMouse.containsMouse ? 0.45 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.tint(Theme.hudAccent, 0.22) }
                                GradientStop { position: 1; color: Theme.tint(Theme.hudAccent, 0) }
                            }
                        }
                        Rectangle { visible: row.on; width: 3; height: parent.height; color: Theme.hudAccent }
                        // The number, the Japanese and the name on one baseline, the name's.
                        Row {
                            x: Theme.s3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.s3
                            Text {
                                anchors.baseline: rowName.baseline
                                text: (row.index + 1 < 10 ? "0" : "") + (row.index + 1)
                                font.family: Theme.fontHud; font.pixelSize: Theme.textXs + 1; font.weight: Font.DemiBold
                                color: row.on ? Theme.hudAccent : Theme.hudFaint
                            }
                            Text {
                                visible: text !== ""
                                anchors.verticalCenter: rowName.verticalCenter
                                text: row.modelData.jp
                                font.family: Theme.titleFace(Theme.textS); font.features: Theme.titleFeatures; font.pixelSize: Theme.textS; font.weight: Theme.titleWeight(Theme.textS)
                                color: row.on || rowMouse.containsMouse ? Theme.hudText : Theme.hudQuiet
                            }
                            Text {
                                id: rowName
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: row.on ? Theme.weightName : Theme.weightValue
                                color: row.on || rowMouse.containsMouse ? Theme.textBright : Theme.hudQuiet
                            }
                        }
                        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.choose(row.modelData.key) }
                    }
                }
            }
            // Narrow: the parts as tabs over the panel.
            Design.Tabs {
                id: tabs
                visible: page.narrow
                width: Math.min(implicitWidth, menu.width)
                options: page.offered.map(p => ({ id: p.key, label: p.label, jp: p.jp }))
                value: page.current ? page.current.key : ""
                onChosen: v => page.choose(v)
            }

            // The chosen part's cards.
            Item {
                id: panel
                x: page.narrow ? 0 : page.listWidth + Theme.s4
                y: page.narrow ? tabs.height + Theme.s4 : 0
                width: page.narrow ? menu.width : Math.min(720, menu.width - x)
                Item {
                    id: stack
                    width: parent.width
                    height: page.current ? page.current.height : 0
                    onChildrenChanged: Qt.callLater(page.refresh)
                    // Only the chosen part shows.
                    function place() { for (const c of stack.children) if (c.hasOwnProperty("key")) c.visible = c === page.current }
                    Component.onCompleted: stack.place()

                    // The kit's parts.
                    Design.SettingsPart { key: "sol"; label: "Sol"; jp: "ソル"; order: 0; Design.SolCard { jp: "ソル" } Design.SettingsCard { jp: "設定" } }
                    Design.SettingsPart { key: "export"; label: "Export"; jp: "書き出し"; order: 80; Design.ExportCard { jp: "書き出し" } }
                    Design.SettingsPart { key: "device"; label: "This device"; jp: "端末"; order: 85; Design.DeviceCard { jp: "端末" } }
                    Design.SettingsPart { key: "updates"; label: "Updates"; jp: "更新"; order: 90; Design.AppUpdates { jp: "更新" } }
                    // Each carried moon's own settings, under its name.
                    Repeater {
                        model: {
                            const win = page.Window.window as Design.AppWindow
                            return win ? win.moonSettings : []
                        }
                        delegate: Design.SettingsPart {
                            id: moonPart
                            required property var modelData
                            key: modelData.world
                            label: Worlds.get(modelData.world).name
                            jp: Theme.jpOf(modelData.world)
                            order: 100
                            Loader { sourceComponent: moonPart.modelData.settings }
                        }
                    }
                }
                Connections { target: page; function onCurrentChanged() { stack.place() } function onOfferedChanged() { stack.place() } }
            }
        }
    ]
}

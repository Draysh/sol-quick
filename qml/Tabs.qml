pragma ComponentBehavior: Bound
import QtQuick

/*
    Uppercase words in a row, one of them on: tabs along a hairline
    (`line`), or plain choices. Each may carry a count and a hint. Given
    less width than its words take, the row scrolls sideways. The line
    under the one that is on slides to the next as it changes. A PageHead
    with `tabs` shows one under its title, each tab part of the page's path.

        Tabs { width: Math.min(implicitWidth, parent.width); options: [{ value: "all", label: "All", count: 12 }]; value: view.status; onChosen: v => view.status = v }
*/
Item {
    id: tabs

    /** `{ value, label, count?, hint?, jp? }` (`id` in place of `value` too, as a PageHead's tabs have it); `jp` goes before the label: "道". */
    property var options: []
    property string value: ""
    property bool line: true
    /** What its ends fade into when it scrolls: the page, or the bar it sits on. */
    property color ground: Theme.space
    signal chosen(string value)
    onChosen: Sounds.tick()

    function valueOf(o) { return o.value !== undefined ? String(o.value) : String(o.id) }
    /** Where the one that is on is among the options, or -1. */
    readonly property int at: options.findIndex(o => tabs.valueOf(o) === tabs.value)

    implicitWidth: strip.implicitWidth
    implicitHeight: 30

    // Sideways when it doesn't fit, its ends fading into the page while there is more past them.
    Strip {
        id: strip
        anchors.fill: parent
        spacing: Theme.s4
        line: false
        fades: true
        ground: tabs.ground
        Repeater {
            id: tabRepeater
            model: tabs.options
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool on: tabs.at === index
                width: row.implicitWidth
                height: 30
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.onPressAction: tabs.chosen(tabs.valueOf(modelData))
                Row {
                    id: row
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text { visible: !!tab.modelData.jp; y: (row.height - height) / 2; rightPadding: 2; text: tab.modelData.jp || ""; font.family: Theme.titleFace(Theme.textXs + 2); font.weight: Theme.titleWeight(Theme.textXs + 2); font.pixelSize: Theme.textXs + 2; font.features: Theme.titleFeatures; color: tab.on ? Theme.hudAccent : Theme.textQuiet }
                    Text { y: (row.height - height) / 2; text: tab.modelData.label; readonly property bool caps: Theme.capsFor(text); font.family: caps ? Theme.fontCaps : Theme.font; font.weight: tab.on ? Font.Bold : Font.Normal; font.pixelSize: caps ? Theme.textXs : Theme.textS; font.letterSpacing: caps ? Theme.track(Theme.trackCaps, Theme.textXs) : 0; font.capitalization: caps ? Font.AllUppercase : Font.MixedCase; color: tab.on ? Theme.textBright : mouse.containsMouse ? Theme.textValue : Theme.textQuiet; Behavior on color { ColorAnimation { duration: Theme.fade } } }
                    Text { visible: tab.modelData.count !== undefined; text: tab.modelData.count === undefined ? "" : String(tab.modelData.count); font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue; color: Theme.textQuiet }
                }
                MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tabs.chosen(tabs.valueOf(tab.modelData)) }
                Hint { text: tab.modelData.hint || ""; when: mouse.containsMouse && !!tab.modelData.hint }
            }
        }
    }

    // The line under the one that is on: one line that slides and stretches to the next
    // (moved and scaled, never resized), at once with less motion.
    Item {
        anchors.fill: strip
        clip: strip.overflows
        visible: tabs.line
        // Along with the row as it scrolls sideways.
        Item {
            x: -strip.contentX
            width: parent.width
            height: parent.height
            Rectangle {
                id: underline
                readonly property Item under: tabs.at >= 0 && tabRepeater.count > tabs.at ? tabRepeater.itemAt(tabs.at) : null
                // Placed at once the first time; after that it slides.
                property bool shown: false
                onUnderChanged: if (under) Qt.callLater(() => underline.shown = true)
                // A bar in the world's light, its ends slanted.
                y: parent.height - height
                width: 100
                height: 3
                color: Theme.hudAccent
                antialiasing: true
                opacity: under ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                transform: [
                    Scale {
                        xScale: underline.under ? underline.under.width / 100 : 0
                        Behavior on xScale { enabled: underline.shown && !Theme.calm; NumberAnimation { id: stretching; duration: Theme.settle; easing: Theme.easeOut } }
                    },
                    Matrix4x4 { matrix: Qt.matrix4x4(1, -1, 0, 1.5, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) },
                    Translate {
                        x: underline.under ? underline.under.x : 0
                        Behavior on x { enabled: underline.shown && !Theme.calm; NumberAnimation { id: sliding; duration: Theme.settle; easing: Theme.easeOut } }
                    }
                ]
            }
        }
    }
    Settling { when: sliding.running || stretching.running }
}

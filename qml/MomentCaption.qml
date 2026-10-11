pragma ComponentBehavior: Bound
import QtQuick

/*
    The words of a moment's scene: a small line over a big name, a line
    under it, and a row of figures; it rises into place as the moment
    starts (still, with less motion). Put it where the scene has room.

        MomentCaption { moment: scene.moment; lead: "Finished"; title: "Frieren"; line: "Started in March"; facts: [{ label: "Episodes", value: "28" }] }
*/
Column {
    id: root

    /** The moment it is in, for its timing. */
    property var moment: null
    property string lead: ""
    property string title: ""
    property string line: ""
    /** `{ label, value }`, in a row. */
    property var facts: []
    property bool centred: true
    /** Over a picture's dark scrim: light words in either light. */
    property bool onPhoto: false
    readonly property color bright: onPhoto ? "#ffffff" : Theme.textBright
    readonly property color value: onPhoto ? Qt.rgba(1, 1, 1, 0.82) : Theme.textValue
    readonly property color quiet: onPhoto ? Qt.rgba(1, 1, 1, 0.62) : Theme.textQuiet
    readonly property real p: moment ? moment.progress : 1
    readonly property real arrive: moment && moment.calm ? 1 : Math.min(1, p * 5)

    spacing: Theme.s2
    opacity: arrive
    transform: Translate { y: (1 - root.arrive) * 18 }

    Text {
        visible: root.lead !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        text: root.lead
        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
        font.letterSpacing: Theme.track(Theme.trackLabel, Theme.textXs); font.capitalization: Font.AllUppercase
        color: root.onPhoto ? Qt.tint("#ffffff", Theme.tint(Theme.world, 0.5)) : Theme.textWorld
    }
    Text {
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        text: root.title
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: Theme.font; font.pixelSize: Theme.text2xl; font.weight: Theme.weightDisplay
        font.letterSpacing: Theme.track(0.02, Theme.text2xl)
        color: root.bright
    }
    Text {
        visible: root.line !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
        text: root.line
        font.family: Theme.font; font.pixelSize: Theme.textL; font.weight: Theme.weightValue
        color: root.value
    }
    Item { width: 1; height: Theme.s3; visible: root.facts.length > 0 }
    Row {
        x: root.centred ? (root.width - width) / 2 : 0
        spacing: Theme.s5
        Repeater {
            model: root.facts
            delegate: Column {
                id: fact
                required property var modelData
                required property int index
                spacing: 2
                // One after another, as the moment goes on.
                opacity: root.moment && root.moment.calm ? 1 : Math.max(0, Math.min(1, (root.p - 0.12 - fact.index * 0.06) * 8))
                Text {
                    text: fact.modelData.value
                    font.family: Theme.font; font.pixelSize: Theme.textXl; font.weight: Theme.weightDisplay
                    color: root.bright
                }
                Text {
                    text: fact.modelData.label
                    font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                    font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase
                    color: root.quiet
                }
            }
        }
    }
}

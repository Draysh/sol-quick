pragma ComponentBehavior: Bound
import QtQuick

/*
    The words of a moment's scene: a small line over a big name, a line
    under it, and a row of figures; it rises into place as the moment
    starts (still, with less motion). Put it where the scene has room.

        MomentCaption { moment: scene.moment; lead: "Finished"; title: "Frieren"; line: "Started in March"; facts: [{ label: "Episodes", value: "28" }] }

    In the Yozora look it is a film's title card: the lead in the mono
    face and the world's light, the Japanese (`jp`) huge in the title
    serif with the English title under it, the figures in mono, and the
    subtitle (`subtitleJp` over `subtitle`) centred at the foot of the
    moment, as a film's subtitles are. Off the look `jp` and the subtitle
    don't show.
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
    /** The title in Japanese, for the Yozora look: "百夜". */
    property string jp: ""
    /** A line said at the foot of the window in the Yozora look, Japanese over English: "百夜目の星が、灯った。" */
    property string subtitleJp: ""
    property string subtitle: ""
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

    readonly property bool film: Theme.yozora
    readonly property bool titled: film && jp !== ""
    Text {
        visible: root.lead !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        text: root.lead
        font.family: root.film ? Theme.fontMono : Theme.font; font.pixelSize: root.film ? Theme.textS : Theme.textXs; font.weight: root.film ? Font.DemiBold : Theme.weightLabel
        font.letterSpacing: Theme.track(root.film ? Theme.trackHud : Theme.trackLabel, root.film ? Theme.textS : Theme.textXs); font.capitalization: Font.AllUppercase
        color: root.film ? Theme.hudAccent : root.onPhoto ? Qt.tint("#ffffff", Theme.tint(Theme.world, 0.5)) : Theme.textWorld
    }
    // The look's Japanese title, huge, glowing faintly in the world's light.
    Text {
        visible: root.titled
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        text: root.jp
        elide: Text.ElideRight
        readonly property real size: Math.min(150, Math.max(64, root.width / Math.max(2, root.jp.length) * 0.95))
        font.family: Theme.fontTitle; font.pixelSize: size; font.weight: Font.Black
        font.letterSpacing: size * 0.04
        color: Theme.hudText
        style: Text.Raised; styleColor: Theme.tint(Theme.hudSecond, 0.35)
    }
    Text {
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        text: root.title
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: root.film ? Theme.fontTitle : Theme.font
        font.pixelSize: root.titled ? Theme.textLede : root.film ? Theme.text2xl * 1.25 : Theme.text2xl
        font.weight: root.titled ? Font.Medium : root.film ? Font.Black : Theme.weightDisplay
        font.letterSpacing: root.film ? 0 : Theme.track(0.02, Theme.text2xl)
        color: root.bright
    }
    Text {
        visible: root.line !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
        text: root.line
        font.family: root.film ? Theme.fontTitle : Theme.font; font.pixelSize: Theme.textL; font.weight: root.film ? Font.Medium : Theme.weightValue
        color: root.value
    }
    // The subtitle, at the foot of the moment (or of the caption's own parent, outside one).
    Column {
        parent: root.moment && root.moment.hasOwnProperty("bars") ? root.moment : root.parent
        visible: root.film && (root.subtitleJp !== "" || root.subtitle !== "")
        z: 3
        width: parent ? parent.width - Theme.s5 * 2 : 0
        x: Theme.s5
        y: parent ? parent.height - height - (root.moment && root.moment.barHeight ? root.moment.barHeight + Theme.s3 : Theme.s5) : 0
        spacing: Theme.s1
        // Later than the title, as a line is said after the scene opens.
        opacity: root.moment && root.moment.calm ? 1 : Math.max(0, Math.min(1, (root.p - 0.3) * 6))
        Text {
            visible: root.subtitleJp !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.subtitleJp
            font.family: Theme.fontTitle; font.pixelSize: Theme.textXl; font.weight: Font.Bold
            font.letterSpacing: Theme.textXl * 0.06
            color: "#ffffff"
            style: Text.Outline; styleColor: Theme.tint("#000000", 0.6)
        }
        Text {
            visible: root.subtitle !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.subtitle
            font.family: Theme.font; font.pixelSize: Theme.textM
            color: Qt.rgba(1, 1, 1, 0.86)
            style: Text.Outline; styleColor: Theme.tint("#000000", 0.5)
        }
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
                    font.family: root.film ? Theme.fontMono : Theme.font; font.pixelSize: root.film ? Theme.textFigure : Theme.textXl; font.weight: root.film ? Font.DemiBold : Theme.weightDisplay
                    color: root.bright
                }
                Text {
                    text: fact.modelData.label
                    font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                    font.letterSpacing: Theme.track(Theme.trackCaps, Theme.textXs); font.capitalization: Font.AllUppercase
                    color: root.quiet
                }
            }
        }
    }
}

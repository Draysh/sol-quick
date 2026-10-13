pragma ComponentBehavior: Bound
import QtQuick

/*
    The words of a moment's scene: a small line over a big name, a line
    under it, and a row of figures; it rises into place as the moment
    starts (still, with less motion). Put it where the scene has room.

        MomentCaption { moment: scene.moment; lead: "Finished"; title: "Frieren"; line: "Started in March"; facts: [{ label: "Episodes", value: "28" }] }

    It is a film's title card: the lead in HUD capitals and the world's
    light, the Japanese (`jp`) huge in the title serif with the English
    title under it, the figures in the HUD face, and the subtitle
    (`subtitleJp` over `subtitle`) centred at the foot of the moment, as a
    film's subtitles are. The world's navigator says the subtitle: it
    stands large, low on the right, on the bottom bar, and cheers as the
    line comes.
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
    /** The title in Japanese: "百夜". */
    property string jp: ""
    /** A line said at the foot of the window, Japanese over English: "百夜目の星が、灯った。" */
    property string subtitleJp: ""
    property string subtitle: ""
    property bool centred: true
    /** Over a picture's dark scrim: light words in either light. */
    property bool onPhoto: false
    readonly property color bright: onPhoto ? "#ffffff" : Theme.artBright
    readonly property color value: onPhoto ? Qt.rgba(1, 1, 1, 0.82) : Theme.light ? Theme.artQuiet : Theme.textValue
    readonly property color quiet: onPhoto ? Qt.rgba(1, 1, 1, 0.62) : Theme.artQuiet
    readonly property real p: moment ? moment.progress : 1
    readonly property real arrive: moment && moment.calm ? 1 : Math.min(1, p * 5)

    spacing: Theme.s2
    opacity: arrive
    transform: Translate { y: (1 - root.arrive) * 18 }

    readonly property bool titled: jp !== ""
    Text {
        visible: root.lead !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        text: root.lead
        readonly property bool caps: Theme.capsFor(root.lead)
        font.family: caps ? Theme.fontCaps : Theme.font; font.pixelSize: Theme.textS; font.weight: Font.DemiBold
        font.letterSpacing: caps ? Theme.track(Theme.trackHud, Theme.textS) : 0; font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
        color: Theme.artAccent
    }
    // The look's Japanese title, huge, glowing faintly in the world's light.
    Text {
        visible: root.titled
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        text: root.jp
        elide: Text.ElideRight
        readonly property real size: Math.min(150, Math.max(64, root.width / Math.max(2, root.jp.length) * 0.95))
        font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: size; font.weight: Font.Black
        color: Theme.artBright
        style: Text.Raised; styleColor: Theme.tint(Theme.artSecond, 0.35)
    }
    Text {
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        text: root.title
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: Theme.fontTitle
        font.features: Theme.titleFeatures
        font.pixelSize: root.titled ? Theme.textLede : Theme.text2xl * 1.25
        font.weight: root.titled ? Font.Medium : Font.Black
        color: root.bright
    }
    Text {
        visible: root.line !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
        text: root.line
        font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textL; font.weight: Font.Medium
        color: root.value
    }
    // The world's navigator says the subtitle: large, low on the right, standing on the bottom bar,
    // pleased as the line comes (in a moment only, and with the portrait here).
    readonly property bool inMoment: !!root.moment && root.moment.hasOwnProperty("bars")
    readonly property bool spoken: root.p >= 0.36
    onSpokenChanged: if (spoken) momentFace.cheer()
    NavigatorFace {
        id: momentFace
        parent: root.inMoment ? root.moment : root.parent
        visible: root.inMoment && here && (root.subtitleJp !== "" || root.subtitle !== "")
        z: 3
        readonly property real room: root.inMoment && parent ? parent.height - root.moment.barHeight * 2 : 0
        height: Math.round(Math.min(300, Math.max(150, room * 0.42)))
        width: Math.round(height * 0.74)
        x: parent ? parent.width - width - Theme.s5 : 0
        y: root.inMoment && parent ? parent.height - root.moment.barHeight * root.moment.bars - height : 0
        motifs: true
        opacity: root.moment && root.moment.calm ? 1 : Math.max(0, Math.min(1, (root.p - 0.3) * 6))
        transform: Translate { y: (1 - momentFace.opacity) * Theme.s3 }
    }
    // The subtitle, at the foot of the moment (or of the caption's own parent, outside one).
    Column {
        parent: root.inMoment ? root.moment : root.parent
        visible: root.subtitleJp !== "" || root.subtitle !== ""
        z: 3
        // Clear of the navigator on the right, and as far in on the left, so it stays centred.
        readonly property real inset: Theme.s5 + (momentFace.visible ? momentFace.width + Theme.s3 : 0)
        width: parent ? parent.width - inset * 2 : 0
        x: inset
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
            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.pixelSize: Theme.textXl; font.weight: Font.Bold
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
                    font.family: Theme.fontHud; font.pixelSize: Theme.textFigure; font.weight: Font.DemiBold
                    color: root.bright
                }
                Label { text: fact.modelData.label; font.weight: Theme.weightLabel; color: root.quiet }
            }
        }
    }
}

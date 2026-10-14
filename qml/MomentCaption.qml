pragma ComponentBehavior: Bound
import QtQuick

/*
    The words of a moment's scene: a small line over a big name, a line
    under it, and a row of figures. Put it where the scene has room.

        MomentCaption { moment: scene.moment; lead: "Finished"; title: "Frieren"; line: "Started in March"; facts: [{ label: "Episodes", value: "28" }] }

    It is a film's title card, in kinetic type, on the moment's clock: the
    lead in HUD capitals and the world's light comes a beat early, then the
    Japanese (`jp`, or the title when there is none) slams in huge in the
    title face as the moment's sting plays (SlamText, at `moment.slamAt`),
    the English title lands under it, the figures count up in the display
    face, a hold, and on the beat the subtitle (`subtitleJp` over
    `subtitle`) is said, centred at the foot of the moment as a film's
    subtitles are. The world's navigator says it: it stands large, low on
    the right, on the bottom bar, and cheers as the line comes. With less
    motion everything is in its place at once.

    On a title card (`Theme.impacts`) its kanji (`glyph`, the first of
    `jp`'s) slams in at about 45% of the frame's height (less in a short one) with a one-drawing
    invert and stays; the Japanese line, the English title in small
    tracked capitals and the line follow; the figures count up as on any
    moment; the subtitle is said small at the foot, without the navigator.
*/
Column {
    id: root

    /** The moment it is in, for its timing. */
    property var moment: null
    property string lead: ""
    property string title: ""
    property string line: ""
    /** `{ label, value }`, in a row; a value that starts with a number counts up to it. */
    property var facts: []
    /** The title in Japanese: "百夜". */
    property string jp: ""
    /** A line said at the foot of the window, Japanese over English: "百夜目の星が、灯った。" */
    property string subtitleJp: ""
    property string subtitle: ""
    property bool centred: true
    /** Over a picture's dark scrim: light words in either light. */
    property bool onPhoto: false
    /** How the Japanese arrives: SlamText's `way` ("slam"; a softer "bounce" or "rise"). */
    property string way: "slam"
    /** The Japanese's colour: white, or a world's own light (Luna's moon yellow). */
    property color jpColor: Theme.artBright
    /** The English title's size under a Japanese one. */
    property int titleSize: Theme.textLede
    /** A title card's one kanji: the first of `jp`'s unless given. */
    property string glyph: ""
    readonly property bool card: Theme.impacts
    readonly property string cardGlyph: {
        if (glyph !== "") return glyph
        const k = /[\u3400-\u9fff]/.exec(jp)
        return k ? k[0] : jp !== "" ? jp.charAt(0) : title.charAt(0)
    }
    /** The frame's height, for the kanji's size. */
    readonly property real frameHeight: inMoment ? root.moment.height : Theme.s7 * 4
    readonly property color bright: onPhoto ? "#ffffff" : Theme.artBright
    readonly property color value: onPhoto ? Qt.rgba(1, 1, 1, 0.82) : Theme.light ? Theme.artQuiet : Theme.textValue
    readonly property color quiet: onPhoto ? Qt.rgba(1, 1, 1, 0.62) : Theme.artQuiet
    readonly property real p: moment ? moment.progress : 1

    // ---- The beats, in ms on the moment's clock ----------------------------------
    readonly property bool still: !moment || moment.calm
    readonly property real t: still ? 1e9 : moment.elapsed || 0
    readonly property real slamAt: moment && moment.slamAt !== undefined ? moment.slamAt : 0
    /** The English title and the line land after the hit and its hold. */
    readonly property real landAt: slamAt + Theme.hit + Theme.hold
    /** The figures count up from then. */
    readonly property real countAt: landAt + Theme.hit
    /** The subtitle is said once they have counted, and a hold. */
    readonly property real sayAt: countAt + Theme.count + Theme.hold
    function ramp(from, over) { return Math.max(0, Math.min(1, (t - from) / Math.max(1, over))) }
    function soft(x) { return 1 - Math.pow(1 - x, 3) }

    spacing: Theme.s2

    readonly property bool titled: jp !== ""
    Text {
        visible: root.lead !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        text: root.lead
        readonly property bool caps: Theme.capsFor(root.lead)
        font.family: caps ? Theme.fontCaps : Theme.font; font.pixelSize: Theme.textS; font.weight: Font.DemiBold
        font.letterSpacing: caps ? Theme.track(Theme.trackHud, Theme.textS) : 0; font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
        color: Theme.artAccent
        // A beat before the slam: the anticipation.
        opacity: root.soft(root.ramp(root.slamAt - Theme.hit * 2, Theme.hit * 2))
    }
    // The hero: the Japanese, huge, or the title itself when there is none; on a title card, its one kanji.
    SlamText {
        id: hero
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        text: root.card ? root.cardGlyph : root.titled ? root.jp : root.title
        // A card's kanji is about 45% of the frame's height; in a short frame less, so what is under it keeps clear of the foot.
        size: root.card ? Math.round(Math.max(root.frameHeight * 0.3, Math.min(root.frameHeight * 0.45, root.frameHeight - 520))) : root.titled ? Math.min(150, Math.max(64, root.width / Math.max(2, root.jp.length) * 0.95)) : Theme.text2xl * 1.25
        impact: root.card
        chroma: !root.card && !!Theme.hud.chroma
        wrap: !root.titled && !root.card
        maximumLineCount: 2
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        color: root.titled ? root.jpColor : root.bright
        glint: Theme.artAccent
        way: root.way
        at: root.t - root.slamAt
    }
    // A title card's Japanese line, under its kanji.
    Text {
        visible: root.card && root.jp.length > 1
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        text: root.jp
        font.family: Theme.titleFace(Theme.textXl); font.features: Theme.titleFeatures; font.pixelSize: Theme.textXl; font.weight: Theme.titleWeight(Theme.textXl)
        color: root.bright
        opacity: root.t >= root.landAt ? 1 : 0
    }
    // Under a Japanese title, the English, in the display face, landing after the hold (a title card's
    // small, in tracked capitals).
    Text {
        visible: root.titled && root.title !== "" && !root.card
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        text: root.title
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: Theme.fontDisplay; font.pixelSize: root.titleSize; font.weight: Font.Bold
        color: root.bright
        opacity: root.ramp(root.landAt, Theme.hit)
        transform: Translate { y: (1 - root.soft(root.ramp(root.landAt, Theme.land))) * Theme.s3 }
    }
    Text {
        visible: root.card && root.title !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        text: root.title
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: Theme.fontCaps; font.pixelSize: Theme.textS; font.weight: Font.Bold
        font.letterSpacing: Theme.track(Theme.trackHud, Theme.textS); font.capitalization: Font.AllUppercase
        color: root.bright
        opacity: root.t >= root.landAt + Theme.frame ? 1 : 0
    }
    Text {
        visible: root.line !== ""
        x: root.centred ? (root.width - width) / 2 : 0
        width: Math.min(implicitWidth, root.width)
        horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
        text: root.line
        // English in the display face, as every subtitle is; Japanese in the title face where it reads.
        readonly property bool jp: Theme.hasJp(root.line)
        font.family: jp ? Theme.titleFace(Theme.textL) : Theme.fontDisplay; font.features: Theme.titleFeatures; font.pixelSize: Theme.textL
        font.weight: jp ? Theme.titleWeight(Theme.textL) : Font.Bold
        color: root.value
        opacity: root.ramp(root.landAt + Theme.hit, Theme.land)
    }
    // The world's navigator says the subtitle: large, low on the right, standing on the bottom bar,
    // pleased as the line comes (in a moment only, and with the portrait here).
    readonly property bool inMoment: !!root.moment && root.moment.hasOwnProperty("bars")
    readonly property bool spoken: root.t >= root.sayAt
    onSpokenChanged: if (spoken) momentFace.cheer()
    NavigatorFace {
        id: momentFace
        parent: root.inMoment ? root.moment : root.parent
        visible: root.inMoment && here && (root.subtitleJp !== "" || root.subtitle !== "") && !root.card
        z: 3
        readonly property real room: root.inMoment && parent ? parent.height - root.moment.barHeight * 2 : 0
        height: Math.round(Math.min(300, Math.max(150, room * 0.42)))
        width: Math.round(height * 0.74)
        x: parent ? parent.width - width - Theme.s5 : 0
        y: root.inMoment && parent ? parent.height - root.moment.barHeight * root.moment.bars - height : 0
        motifs: true
        // A beat before the line, as someone about to speak.
        opacity: root.soft(root.ramp(root.sayAt - Theme.hold, Theme.hold))
        transform: Translate { y: (1 - momentFace.opacity) * Theme.s3 }
    }
    // The subtitle, at the foot of the moment (or of the caption's own parent, outside one), said on the beat.
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
        opacity: root.ramp(root.sayAt, Theme.hit)
        Text {
            visible: root.subtitleJp !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.subtitleJp
            readonly property int px: root.card ? Theme.textL : Theme.textXl
            font.family: Theme.titleFace(px); font.features: Theme.titleFeatures; font.pixelSize: px; font.weight: Theme.titleWeight(px)
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
            opacity: root.ramp(root.sayAt + Theme.hit, Theme.hit)
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
                // One after another, a beat apart, each counting up to its value.
                readonly property real from: root.countAt + fact.index * Theme.beat.stagger * 2
                readonly property var parts: /^(\D*?)(\d[\d,]*(?:\.\d+)?)(.*)$/.exec(String(fact.modelData.value))
                readonly property real target: parts ? Number(parts[2].replace(/,/g, "")) : 0
                readonly property int decimals: parts && parts[2].indexOf(".") >= 0 ? parts[2].split(".")[1].length : 0
                readonly property real counted: root.soft(root.ramp(fact.from, Theme.count))
                opacity: root.ramp(fact.from, Theme.hit)
                Text {
                    text: !fact.parts ? String(fact.modelData.value)
                        : fact.parts[1] + (fact.parts[2].indexOf(",") >= 0 ? Math.round(fact.target * fact.counted).toLocaleString(Qt.locale("en_GB"), "f", 0)
                            : (fact.target * fact.counted).toFixed(fact.decimals)) + fact.parts[3]
                    font.family: Theme.fontDisplay; font.pixelSize: Theme.textFigure; font.weight: Font.Bold
                    color: root.bright
                }
                Label { text: fact.modelData.label; font.weight: Theme.weightLabel; color: root.quiet }
            }
        }
    }
}

import QtQuick
import QtQuick.Effects

/*
    One of a first page's big figures, under its title: the number in the
    HUD face, its label in HUD capitals and its Japanese tag in the title
    serif under it, behind a short upright rule (the first one's in the
    world's light). A Sheet shows its `figures` with these; a page that
    draws its own title card puts two or three in a Flow. The number counts
    up to its value as it comes into view.

        HeroFigure { value: "06"; label: "Watching"; jp: "視聴中"; lead: true }
*/
Item {
    id: root

    /** The figure as it reads: "06", "291", "126h". "··" while it is not known. */
    property string value: ""
    /** One to three words: "Watching". */
    property string label: ""
    /** Its tag in Japanese: "視聴中". */
    property string jp: ""
    /** The first of a row: its rule is in the world's light. */
    property bool lead: false
    /** Smaller, for a compact title card. */
    property bool compact: false

    readonly property real size: compact ? Math.round(Theme.textFigure * 0.74) : Theme.textFigure

    // The number counts up to its value as it arrives (from the one before when it changes),
    // in the room its value takes, so nothing around it moves. Less motion: there at once.
    /** The value read as a number, and what is around it: "126h" is 126 with "h" after. */
    readonly property var parts: {
        const m = /^(\D*?)(\d[\d,]*)(\D*)$/.exec(value)
        return m ? { pre: m[1], n: Number(m[2].replace(/,/g, "")), post: m[3], digits: m[2].replace(/,/g, "").length, zeros: m[2].length > 1 && m[2][0] === "0", commas: m[2].indexOf(",") >= 0 } : null
    }
    property real from: 0
    /** How far it has counted, 0 to 1. */
    property real counted: animates ? 0 : 1
    readonly property bool animates: !Theme.calm && Theme.count > 0
    readonly property string shown: {
        const p = parts
        if (!p || counted >= 1) return value
        let s = String(Math.round(from + (p.n - from) * counted))
        if (p.zeros) s = s.padStart(p.digits, "0")
        if (p.commas) s = s.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return p.pre + s + p.post
    }
    property bool arrived: false
    property real was: 0
    onPartsChanged: {
        if (!arrived) return
        from = was
        if (parts) { was = parts.n; if (animates) run.restart() }
    }
    property var forget: null
    Component.onCompleted: forget = Theme.whenSeen(root, () => { arrived = true; from = 0; if (parts) was = parts.n; if (animates) run.restart(); else counted = 1 })
    Component.onDestruction: if (forget) forget()
    NumberAnimation { id: run; target: root; property: "counted"; from: 0; to: 1; duration: Theme.count; easing: Theme.easeOut }
    Settling { when: run.running }
    TextMetrics { id: room; font: figure.font; text: root.value }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: value + " " + label

    Row {
        id: row
        // A soft dark glow behind it, so the small tags read on a bright or busy still.
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.hud.dim || Theme.hud.ground; shadowOpacity: 0.9; shadowBlur: 0.6; shadowVerticalOffset: 1 }
        spacing: Theme.s2 + 2
        Rectangle {
            width: 2
            height: figure.implicitHeight - 8
            anchors.verticalCenter: parent.verticalCenter
            color: root.lead ? Theme.artAccent : Theme.artLine
        }
        Text {
            id: figure
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(room.advanceWidth)
            text: root.shown
            font.family: Theme.fontDisplay; font.pixelSize: root.size; font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            color: Theme.artBright
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.compact ? 0 : 2
            Text {
                text: root.label
                font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Font.DemiBold
                font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
                color: Theme.artBright
            }
            Text {
                visible: root.jp !== ""
                text: root.jp
                font.family: Theme.titleFace(Theme.textXs + 2); font.features: Theme.titleFeatures; font.pixelSize: Theme.textXs + 2; font.weight: Theme.titleWeight(Theme.textXs + 2)
                color: Theme.artAccent
            }
        }
    }
}

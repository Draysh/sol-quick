pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
// For SolBackend (a C++ type of this module, which the folder alone doesn't bring).
import Sol.Design

/*
    What the navigator says, in a manga speech bubble: the world's glass
    (`bubble`: dark, or frost on a light flavour) inside a light outline
    in its `edge`, round (the one round thing in the look), with a tail
    towards the portrait and a faint hard shadow in the world's light. The
    Japanese line comes first, in the title serif; the English under it,
    in the sans. When the words change they are typed in, the Japanese
    and then the English, over `Theme.speak` (at once with less motion,
    and in a picture, which never waits for them);
    the bubble keeps its size while they type. A line that wraps is
    balanced, so no word or character is left alone on the last line: the
    Japanese breaks after its 、 when one leaves two lines that fit.

        Speech { width: 200; jp: "おかえり。"; line: "Welcome back."; tail: "down"; tailAt: 120 }
*/
Item {
    id: speech

    /** The line in Japanese, first. */
    property string jp: ""
    /** The line in English, under it: short, about 60 characters at most. */
    property string line: ""
    /** Where the tail points: "down" (a portrait under it), "left" or "right" (one beside it), "none". */
    property string tail: "down"
    /** Where along its edge the tail starts, in pixels from the left (or the top, beside). */
    property real tailAt: Theme.s4
    /** Larger words, for a bubble beside an empty page or in a moment. */
    property bool large: false
    // Glass in the window: it wears the look the window wears (Luna's indigo on her pages in Terra's).
    readonly property var flavour: Theme.hud
    readonly property bool says: jp !== "" || line !== ""

    readonly property real pad: large ? Theme.s3 : Theme.s2 + 2
    readonly property real tailLength: large ? Theme.s3 : Theme.s2 + 2
    readonly property real tailWidth: large ? Theme.s4 : Theme.s3 + 2
    /** As wide as its longest line wants, unwrapped: a bubble for a short line can be narrower. */
    readonly property real naturalWidth: Math.ceil(Math.max(jp === "" ? 0 : jpMetrics.advanceWidth(jp), lineText.implicitWidth)) + (pad + 2) * 2 + 1
    /** The bubble itself, without its tail. */
    readonly property real bodyHeight: words.implicitHeight + pad * 2
    implicitHeight: bodyHeight + (tail === "down" ? tailLength : 0)

    /** 0 → 1 while the words are typed in. */
    property real typed: 1
    readonly property string said: jp + "\n" + line
    onSaidChanged: say()
    /** Types the words in again. */
    function say() {
        typing.stop()
        // A picture shows the words whole at once: the typing is the bubble's, not the page's arrival.
        if (Theme.calm || Theme.speak === 0 || SolBackend.shot !== "") { typed = 1; return }
        typed = 0
        typing.start()
    }
    NumberAnimation { id: typing; target: speech; property: "typed"; to: 1; duration: Theme.speak }
    Settling { when: typing.running }

    /** `s` with its first `n` characters shown and the rest kept in place, unseen; broken onto a new line before `cut` when it is one. */
    function shown(s, n, cut) {
        if (cut > 0) return shown(s.slice(0, cut), n, -1) + "<br>" + shown(s.slice(cut), n - cut, -1)
        const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const k = Math.max(0, Math.min(s.length, Math.round(n)))
        return k >= s.length ? esc(s) : esc(s.slice(0, k)) + "<font color=\"transparent\">" + esc(s.slice(k)) + "</font>"
    }
    FontMetrics { id: jpMetrics; font: jpText.font }
    /**
        Where the Japanese breaks when it doesn't fit on one line: after the
        、 (or 。！？) that leaves the longer of two lines shortest, both
        fitting; -1 when it fits, or when no mark serves (then it is balanced).
    */
    readonly property int jpCut: {
        const room = words.width
        if (room <= 0 || jp === "" || jpMetrics.advanceWidth(jp) <= room) return -1
        let best = -1, shortest = Infinity
        for (let i = 1; i < jp.length - 1; i++) {
            if ("、。！？".indexOf(jp[i]) < 0) continue
            const longer = Math.max(jpMetrics.advanceWidth(jp.slice(0, i + 1)), jpMetrics.advanceWidth(jp.slice(i + 1)))
            if (longer <= room && longer < shortest) { shortest = longer; best = i + 1 }
        }
        return best
    }
    /**
        How wide words `natural` pixels long are set in `room`: as few lines
        as fit, each about as long, so the last is never one word or one
        character alone; `slack` is the longest thing that can't be broken.
    */
    function balanced(natural, room, slack) {
        if (room <= 0 || natural <= room) return room
        const lines = Math.ceil(natural / room)
        return Math.min(room, Math.ceil(natural / lines + slack))
    }
    TextMetrics {
        id: longestWord
        font: lineText.font
        text: speech.line.split(/\s+/).reduce((a, b) => b.length > a.length ? b : a, "")
    }

    // The Japanese takes the first half of the typing, the English the rest (all of it without Japanese).
    readonly property real jpPart: jp === "" ? 0 : line === "" ? 1 : 0.5

    /** The bubble's outline with its tail, as an SVG path. */
    readonly property string outline: {
        const w = width, h = bodyHeight, r = Math.min(Theme.radiusSpeech, h / 2), a = tailAt, tw = tailWidth, th = tailLength
        let p = "M " + r + " 0 H " + (w - r) + " A " + r + " " + r + " 0 0 1 " + w + " " + r
        if (tail === "right") p += " V " + a + " Q " + (w + th * 0.4) + " " + (a + tw * 0.45) + " " + (w + th) + " " + (a + tw * 0.9) + " Q " + (w + th * 0.5) + " " + (a + tw) + " " + w + " " + (a + tw)
        p += " V " + (h - r) + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + h
        if (tail === "down") p += " H " + (a + tw) + " Q " + (a + tw * 0.55) + " " + (h + th * 0.45) + " " + (a + tw * 0.15) + " " + (h + th) + " Q " + (a + tw * 0.3) + " " + (h + th * 0.4) + " " + a + " " + h
        p += " H " + r + " A " + r + " " + r + " 0 0 1 0 " + (h - r)
        if (tail === "left") p += " V " + (a + tw) + " Q " + (-th * 0.5) + " " + (a + tw) + " " + (-th) + " " + (a + tw * 0.9) + " Q " + (-th * 0.4) + " " + (a + tw * 0.45) + " 0 " + a
        p += " V " + r + " A " + r + " " + r + " 0 0 1 " + r + " 0 Z"
        return p
    }

    // A hard shadow in the world's light, as a manga panel's bubble pops off the page: faint, under glass.
    Shape {
        x: 3; y: 3
        width: speech.width; height: speech.implicitHeight
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillColor: Theme.tint(speech.flavour.accent, speech.flavour.light ? 0.4 : 0.28)
            PathSvg { path: speech.outline }
        }
    }
    // The glass, inside its outline: the edge's light on dark glass, the deep ink's hairline on frost.
    Shape {
        width: speech.width; height: speech.implicitHeight
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1; strokeColor: Theme.tint(speech.flavour.edge, speech.flavour.light ? 0.45 : 0.7)
            fillColor: speech.flavour.bubble
            PathSvg { path: speech.outline }
        }
    }

    Column {
        id: words
        x: speech.pad + 2; y: speech.pad
        width: speech.width - x * 2
        spacing: speech.large ? Theme.s1 + 2 : 3
        Text {
            id: jpText
            // Broken after a mark, or else between any two characters (a closing mark keeps to the one before it).
            width: speech.jpCut > 0 ? parent.width : speech.balanced(jpMetrics.advanceWidth(speech.jp), parent.width, font.pixelSize * 2)
            visible: speech.jp !== ""
            text: speech.shown(speech.jp, speech.jp.length * Math.min(1, speech.typed / Math.max(0.01, speech.jpPart)), speech.jpCut)
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            lineHeight: 1.1
            font.family: Theme.fontTitle; font.features: Theme.titleFeatures; font.weight: Theme.weightTitle
            font.pixelSize: speech.large ? Theme.textL : Theme.textS + 1
            color: speech.flavour.bright || speech.flavour.text
        }
        Text {
            id: lineText
            width: speech.balanced(implicitWidth, parent.width, longestWord.advanceWidth + font.pixelSize * 0.5)
            visible: speech.line !== ""
            text: speech.shown(speech.line, speech.line.length * Math.max(0, (speech.typed - speech.jpPart) / Math.max(0.01, 1 - speech.jpPart)), -1)
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            lineHeight: 1.12
            font.family: Theme.font; font.pixelSize: speech.large ? Theme.textM : Theme.textXs + 1
            color: speech.flavour.quiet
        }
    }
}

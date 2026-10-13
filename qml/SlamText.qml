pragma ComponentBehavior: Bound
import QtQuick

/*
    Words that slam in: cut across the middle, the two halves come
    together from either side as the words drop from a little larger
    (1.3) to a little smaller than their size, one frame past it, then
    rest; a glint of the world's light runs along the cut and fades over a
    hold. Neptune's (`chroma`) split a red and a cyan ghost off for the
    hit. Whoever plays it drives `at`, the milliseconds since the slam
    began (a moment's clock, the opening's), so it follows that clock and
    rests whole wherever it is not driven. The opening's kanji, a moment's
    title. Its `way` may be gentler: "bounce" (Terra's opening: it drops in
    from a little smaller, a touch past its size and back, a sun's glint
    along it) or "rise" (Luna's: it comes up out of the dark, no glint).

        SlamText { text: "海"; size: 280; at: opening.at }
        SlamText { text: "満点"; size: 150; at: moment.elapsed - 480 }
*/
Item {
    id: root

    property string text: ""
    property real size: Theme.textHero
    property string family: Theme.titleFace(size)
    property int weight: Theme.titleWeight(size)
    property color color: Theme.artBright
    /** Where the words stand in its width. */
    property int horizontalAlignment: Text.AlignLeft
    /** Wraps to its width (a long title), at most `maximumLineCount` lines. */
    property bool wrap: false
    property int maximumLineCount: 2
    /** Milliseconds since the slam began: below 0 not there yet, past the hit and its frame at rest. */
    property real at: 1e9
    /** The light along the cut. */
    property color glint: Theme.artAccent
    /** Red and cyan ghosts split off it for the hit (Neptune's flavour). */
    property bool chroma: !!Theme.hud.chroma
    /** A glitch's tear: the half above the cut pushed this many pixels right, the half below as far left (Neptune's opening jolts it twice in its hold). */
    property real tear: 0
    /** How it arrives: "slam" (cut, the halves meeting), "bounce" (a soft drop, a touch past its size) or "rise" (up out of the dark). */
    property string way: "slam"
    /** A soft shadow under the words, so they read over a still. */
    property color shadow: Theme.tint(Theme.hud.dim || Theme.hud.ground, 0.6)

    implicitWidth: upper.implicitWidth
    implicitHeight: upper.implicitHeight

    readonly property real hit: Math.max(1, Theme.hit)
    readonly property real k: Math.max(0, Math.min(1, at / hit))
    /** 0 → 1 over the hold after the hit: a bounce settling, a rise ending. */
    readonly property real held: Math.max(0, Math.min(1, (at - hit) / Math.max(1, Theme.hold)))
    readonly property real eased: 1 - Math.pow(1 - k, 3)
    /** A rise takes the hit and the hold. */
    readonly property real risen: 1 - Math.pow(1 - Math.max(0, Math.min(1, at / (hit + Math.max(1, Theme.hold)))), 3)
    /** Past the hit: one frame past its size, then at its size (a bounce: a touch past, easing back over a hold). */
    readonly property real s: way === "bounce" ? (at < 0 ? 0.82 : at < hit ? 0.82 + 0.24 * eased : 1.06 - 0.06 * (1 - Math.pow(1 - held, 2)))
        : way === "rise" ? (at < 0 ? 0.97 : 0.97 + 0.03 * risen)
        : at < 0 ? 1.3 : at < hit ? 1.3 - 0.34 * k * k : at < hit + Theme.flicker ? 0.96 : 1
    /** How far it is from its place, up or down: a bounce drops from above, a rise comes up from below. */
    readonly property real lift: way === "bounce" ? (at < hit ? -Theme.s4 * (1 - eased) : 0)
        : way === "rise" ? Theme.s3 * (1 - risen) : 0
    /** How far apart the halves are, closing over the hit. */
    readonly property real apart: way === "slam" && at < hit && at >= 0 ? Math.pow(1 - k, 2) * Math.max(24, width * 0.16) : 0
    /** The glint and the ghosts, from the hit through a hold. */
    readonly property real after: way === "rise" || at < 0 ? 0 : at < hit ? k : Math.max(0, 1 - (at - hit) / Math.max(1, Theme.hold))
    /** Where the cut runs, from the top. */
    readonly property real cut: Math.round(height * 0.54)

    opacity: at < 0 ? 0 : way === "rise" ? risen : Math.min(1, 0.4 + k)
    transform: [
        Scale { origin.x: root.width / 2; origin.y: root.height / 2; xScale: root.s; yScale: root.s },
        Translate { y: root.lift }
    ]

    component Face: Text {
        text: root.text
        width: root.width
        horizontalAlignment: root.horizontalAlignment
        wrapMode: root.wrap ? Text.Wrap : Text.NoWrap
        maximumLineCount: root.maximumLineCount
        elide: root.wrap ? Text.ElideRight : Text.ElideNone
        font.family: root.family; font.weight: root.weight; font.pixelSize: root.size; font.features: Theme.titleFeatures
        color: root.color
        style: Text.Raised; styleColor: root.shadow
    }

    // The ghosts, behind (Neptune's), split off for the hit and for each tear.
    readonly property real split: Math.max(root.after, Math.min(1, Math.abs(root.tear) / 4))
    Face { visible: root.chroma && root.split > 0; x: -5 * root.split - root.tear; color: Theme.tint(Theme.artAccent, 0.7 * root.split); style: Text.Normal }
    Face { visible: root.chroma && root.split > 0; x: 5 * root.split + root.tear; color: Theme.tint(Theme.artSecond, 0.7 * root.split); style: Text.Normal }
    // The halves, above and below the cut.
    Item {
        x: -root.apart + root.tear
        width: root.width; height: root.cut
        clip: root.apart > 0 || root.tear !== 0
        Face { id: upper }
    }
    Item {
        x: root.apart - root.tear
        y: root.cut
        width: root.width; height: root.height - root.cut
        clip: root.apart > 0 || root.tear !== 0
        Face { y: -root.cut }
    }
    // The glint along the cut, past either end.
    Rectangle {
        visible: root.after > 0
        x: -root.width * 0.12; y: root.cut - 1
        width: root.width * 1.24; height: 2
        opacity: root.after
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.tint(root.glint, 0) }
            GradientStop { position: 0.5; color: root.glint }
            GradientStop { position: 1; color: Theme.tint(root.glint, 0) }
        }
    }
}

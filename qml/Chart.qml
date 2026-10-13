pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*
    A chart: bars, or lines over a soft fill, one or more series over the
    same labels. It grows in when it comes into view and follows its data
    after; under the pointer it marks the nearest column and says the exact
    values. Colour is the world's (a series can bring its own).

        Chart { width: parent.width; labels: ["Mon", "Tue", …]; series: [{ name: "Slept", values: [7.5, 6, …], unit: " h" }] }
        Chart { kind: "line"; labels: months; series: [{ name: "Hours", values: hours }, { name: "Titles", values: titles, color: Theme.textQuiet }] }
*/
Item {
    id: root

    /** "bars" or "line". */
    property string kind: "bars"
    /** One label per column, under it. */
    property var labels: []
    /** `{ name, values: [number|null], color?, unit?, format?(v) }`; a null is a gap. */
    property var series: []
    /** The top of the scale; the largest value when 0. */
    property real max: 0
    /** About how wide the longest label is, so labels never crowd. */
    readonly property real labelRoom: Math.max(30, labels.reduce((m, l, i) => Math.max(m, labelWidth(i)), 0) + 14)
    /** Every `labelEvery`th label shows under the chart (all when they fit). */
    property int labelEvery: Math.max(1, Math.ceil(labels.length / Math.max(1, Math.floor(plot.width / labelRoom))))
    /** How a value reads, when a series doesn't say. */
    property var format: v => (Math.round(v * 10) / 10).toLocaleString(Qt.locale(), "f", Number.isInteger(Math.round(v * 10) / 10) ? 0 : 1)

    implicitWidth: 320
    implicitHeight: 192 + (legend.visible ? legend.height + 8 : 0)

    readonly property int count: labels.length
    /** Nothing to draw: no columns, or no value in any of them. */
    readonly property bool empty: count === 0 || !series.some(s => (s.values || []).some(v => v !== null && v !== undefined))
    /** What an empty chart says. */
    property string none: "Nothing yet"
    readonly property real ceiling: {
        if (max > 0) return max
        let m = 0
        for (const s of series) for (const v of s.values || []) if (v !== null && v !== undefined && v > m) m = v
        return m > 0 ? m * 1.08 : 1
    }
    /** A series' colour: its own, else the world's light, then quieter ones. */
    function colorOf(i) {
        const s = series[i]
        if (s && s.color) return s.color
        return [Theme.textWorld, Theme.textQuiet, Theme.tint(Theme.textWorld, 0.5), Theme.textFaint][i % 4]
    }
    function read(i, v) {
        const s = series[i]
        if (v === null || v === undefined) return "—"
        return (s && s.format ? s.format(v) : root.format(v)) + (s && s.unit ? s.unit : "")
    }
    // The axis labels' type, to measure them: each sits under its column, kept inside the chart.
    FontMetrics { id: axisFont; font.family: Theme.fontCaps; font.pixelSize: Theme.textXs - 1; font.letterSpacing: Theme.track(Theme.trackRows, Theme.textXs) }
    function labelWidth(i) { return Math.ceil(axisFont.advanceWidth(String(labels[i]).toUpperCase())) + 1 }
    function labelLeft(i) { const w = labelWidth(i); return Math.max(0, Math.min(plot.width - w, xOf(i) - w / 2)) }
    /**
        Which labels show: every `labelEvery`th that keeps clear of the one shown before it
        (measured where it really lands, the first and last pushed in from the edges), and
        under the pointer its column's own, which the others near it give way to.
    */
    readonly property var axisShown: {
        const gap = 10
        const out = labels.map(() => false)
        const hoverL = at >= 0 ? labelLeft(at) : 0, hoverR = at >= 0 ? hoverL + labelWidth(at) : 0
        let end = -1e9
        for (let i = 0; i < count; i += labelEvery) {
            const l = labelLeft(i), r = l + labelWidth(i)
            if (l < end + gap) continue
            if (at >= 0 && i !== at && r + gap > hoverL && l < hoverR + gap) continue
            out[i] = true
            end = r
        }
        if (at >= 0) out[at] = true
        return out
    }
    function xOf(i) { return count <= 1 ? plot.width / 2 : kind === "bars" ? (i + 0.5) * plot.width / count : i * plot.width / (count - 1) }
    function yOf(v) { return plot.height - Math.max(0, Math.min(1, v / ceiling)) * plot.height * grow }

    /** 0 → 1 as it arrives; the bars rise and the lines draw themselves. */
    property real grow: 0
    property var forget: null
    Component.onCompleted: forget = Theme.whenSeen(root, () => arrive.start())
    Component.onDestruction: if (forget) forget()
    Settling { when: arrive.running }
    NumberAnimation { id: arrive; target: root; property: "grow"; from: 0; to: 1; duration: Theme.rise; easing: Theme.easeOut }

    /** The column under the pointer, or -1. */
    property int at: -1

    // Which colour is which, when there is more than one series.
    Flow {
        id: legend
        visible: root.series.length > 1
        width: parent.width
        height: visible ? implicitHeight : 0
        spacing: Theme.s3
        Repeater {
            model: legend.visible ? root.series.length : 0
            delegate: Row {
                id: key
                required property int index
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorOf(key.index); anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.series[key.index].name || ""
                    font.family: Theme.font; font.pixelSize: Theme.textXs
                    color: Theme.textQuiet
                }
            }
        }
    }

    Item {
        id: plot
        // Room above for the scale's top, so it never sits on a bar.
        x: 0; y: (legend.visible ? legend.height + 8 : 0) + 18
        width: parent.width
        height: parent.height - y - axis.height - 6

        // Three quiet lines across, and the scale's top over them.
        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                width: plot.width; height: 1
                y: Math.round(plot.height * index / 3)
                color: Theme.line
                opacity: 0.6
            }
        }
        Rectangle { width: plot.width; height: 1; y: plot.height; color: Theme.lineMid }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.top
            anchors.bottomMargin: 3
            text: root.read(0, root.ceiling)
            visible: !root.empty
            font.family: Theme.fontCaps; font.pixelSize: Theme.textXs - 1
            color: Theme.textQuiet
        }
        // No values yet: says so, where the bars or the line would be.
        Text {
            visible: root.empty
            anchors.centerIn: parent
            text: root.none
            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
            color: Theme.textQuiet
        }

        // Bars: one group per column, the series side by side.
        Repeater {
            model: root.kind === "bars" ? root.count : 0
            delegate: Item {
                id: column
                required property int index
                readonly property real slot: plot.width / Math.max(1, root.count)
                readonly property real barW: Math.max(2, Math.min(28, slot * 0.62 / Math.max(1, root.series.length)))
                x: index * slot
                width: slot; height: plot.height
                Repeater {
                    model: root.series.length
                    delegate: Rectangle {
                        id: bar
                        required property int index
                        readonly property var v: (root.series[bar.index].values || [])[column.index]
                        readonly property bool on: root.at === column.index
                        width: column.barW
                        x: (column.slot - column.barW * root.series.length - 2 * (root.series.length - 1)) / 2 + bar.index * (column.barW + 2)
                        height: bar.v ? plot.height - root.yOf(bar.v) : 0
                        y: plot.height - height
                        radius: Math.min(Theme.radiusS, width / 2)
                        color: root.colorOf(bar.index)
                        opacity: root.at < 0 || bar.on ? 0.92 : 0.45
                        Behavior on height { enabled: root.grow === 1; NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
                        Behavior on opacity { NumberAnimation { duration: Theme.lock } }
                    }
                }
            }
        }

        // Lines: each series a hairline over a fill that fades to nothing.
        Repeater {
            model: root.kind === "line" ? root.series.length : 0
            delegate: Shape {
                id: line
                required property int index
                /** The runs of values between gaps: a null breaks the line. */
                readonly property var segments: {
                    const out = []
                    let run = []
                    const vs = root.series[line.index].values || []
                    for (let i = 0; i < root.count; i++) {
                        if (vs[i] === null || vs[i] === undefined) { if (run.length) out.push(run); run = []; continue }
                        run.push(Qt.point(root.xOf(i), root.yOf(vs[i])))
                    }
                    if (run.length) out.push(run)
                    return out
                }
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: plot.height
                        GradientStop { position: 0; color: Theme.tint(root.colorOf(line.index), line.index === 0 ? 0.22 : 0.08) }
                        GradientStop { position: 1; color: Theme.tint(root.colorOf(line.index), 0) }
                    }
                    PathMultiline { paths: line.segments.map(run => [Qt.point(run[0].x, plot.height)].concat(run).concat([Qt.point(run[run.length - 1].x, plot.height)])) }
                }
                ShapePath {
                    strokeColor: root.colorOf(line.index)
                    strokeWidth: line.index === 0 ? 1.6 : 1.2
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathMultiline { paths: line.segments }
                }
                // A value alone between gaps has no line to sit on: a dot.
                Repeater {
                    model: line.segments.filter(run => run.length === 1)
                    delegate: Rectangle {
                        required property var modelData
                        x: modelData[0].x - 2.5; y: modelData[0].y - 2.5
                        width: 5; height: 5; radius: 2.5
                        color: root.colorOf(line.index)
                    }
                }
            }
        }
        // The column under the pointer: a hairline down it, a dot on each line.
        Rectangle {
            visible: root.at >= 0 && root.kind === "line"
            x: Math.round(root.xOf(root.at)); width: 1; height: plot.height
            color: Theme.lineStrong
        }
        Repeater {
            model: root.kind === "line" && root.at >= 0 ? root.series.length : 0
            delegate: Rectangle {
                id: dot
                required property int index
                readonly property var v: (root.series[dot.index].values || [])[root.at]
                visible: dot.v !== null && dot.v !== undefined
                width: 7; height: 7; radius: 3.5
                x: root.xOf(root.at) - 3.5; y: root.yOf(dot.v || 0) - 3.5
                color: root.colorOf(dot.index)
                border.width: 1.5; border.color: Theme.raised
            }
        }

        HoverHandler {
            id: hover
            onPointChanged: {
                if (!hovered || root.count === 0) { root.at = -1; return }
                const x = point.position.x
                const i = root.kind === "bars" ? Math.floor(x / (plot.width / root.count)) : Math.round(x / (plot.width / Math.max(1, root.count - 1)))
                root.at = Math.max(0, Math.min(root.count - 1, i))
            }
            onHoveredChanged: if (!hovered) root.at = -1
        }
    }

    // The labels under the columns.
    Item {
        id: axis
        y: plot.y + plot.height + 6
        width: parent.width
        height: Theme.textXs + 4
        Repeater {
            model: root.count
            delegate: Text {
                required property int index
                // Under the pointer, the column's own label, and none crowding it.
                visible: !!root.axisShown[index]
                x: root.labelLeft(index)
                text: root.labels[index]
                font.family: Theme.fontCaps; font.pixelSize: Theme.textXs - 1
                font.letterSpacing: Theme.track(Theme.trackRows, Theme.textXs)
                font.capitalization: Font.AllUppercase
                color: root.at === index ? Theme.text : Theme.textQuiet
            }
        }
    }

    // The exact values, beside the column under the pointer.
    Rectangle {
        id: tip
        visible: root.at >= 0 && !root.empty
        readonly property real px: root.xOf(Math.max(0, root.at))
        x: Math.max(0, Math.min(root.width - width, px + 12 + width > root.width ? px - width - 12 : px + 12))
        y: plot.y + 4
        width: tipColumn.implicitWidth + 20
        height: tipColumn.implicitHeight + 14
        radius: Theme.radiusM
        color: Theme.raisedTop
        border.width: 1; border.color: Theme.lineMid
        Column {
            id: tipColumn
            x: 10; y: 7
            spacing: 3
            Text {
                text: root.at >= 0 ? root.labels[root.at] : ""
                font.family: Theme.fontCaps; font.pixelSize: Theme.textXs; font.weight: Theme.weightLabel
                font.letterSpacing: Theme.track(Theme.trackRows, Theme.textXs); font.capitalization: Font.AllUppercase
                color: Theme.textQuiet
            }
            Repeater {
                model: root.series.length
                delegate: Row {
                    id: entry
                    required property int index
                    spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: root.colorOf(entry.index); anchors.verticalCenter: parent.verticalCenter; visible: root.series.length > 1 }
                    Text {
                        text: (root.series.length > 1 ? (root.series[entry.index].name || "") + "  " : "") + (root.at >= 0 ? root.read(entry.index, (root.series[entry.index].values || [])[root.at]) : "")
                        font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightName
                        color: Theme.text
                    }
                }
            }
        }
    }
}

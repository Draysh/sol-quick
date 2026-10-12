pragma ComponentBehavior: Bound
import QtQuick

/*
    A world's sky drawn as a night of its own: each milestone a star, the
    stars of a constellation joined in the order they light, the lines lit
    where both ends are. Lit stars shine in the world's light with a cross;
    the ones still to come are faint points. A star under the pointer (or
    chosen) says what it is and when it was lit. The night, the view and
    the pointer are the kit's `StarField`. `SkyPage` shows it with the sky
    command's view.

        SkyMap { view: page.sky; chosen: page.chosen; onChoose: key => page.chosen = key }
*/
StarField {
    id: map

    /** What `sol_quick::sky::view` gives: `{ constellations, stars, lines, lit, total }`. */
    property var view: null

    stars: view ? view.stars : []
    readonly property var lines: view ? view.lines : []
    readonly property var constellations: view ? view.constellations : []

    readonly property string lit: hover !== "" ? hover : chosen
    readonly property var litStar: find(lit)

    readonly property color warm: Qt.tint("#fff2df", Theme.tint(Theme.world, 0.45))
    readonly property color dim: "#5d6577"
    readonly property color words: "#d4d8e0"

    // The constellations' names, over each, brighter when any of it is lit.
    Repeater {
        model: map.constellations
        delegate: Text {
            required property var modelData
            x: map.sx(modelData.x) - width / 2
            y: map.sy(modelData.y) - height
            text: modelData.title
            font.family: Theme.font
            font.pixelSize: Theme.textXs
            font.weight: Theme.weightName
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.6
            color: map.words
            opacity: modelData.lit > 0 ? 0.62 : 0.3
        }
    }

    Repeater {
        model: map.lines
        delegate: StarLine {
            required property var modelData
            readonly property var a: map.find(modelData.a)
            readonly property var b: map.find(modelData.b)
            visible: !!a && !!b
            x: a ? map.sx(a.x) : 0
            y: a ? map.sy(a.y) : 0
            x2: b ? map.sx(b.x) : 0
            y2: b ? map.sy(b.y) : 0
            color: Theme.tint(modelData.lit ? map.warm : map.words, modelData.lit ? 0.45 : 0.08)
        }
    }

    Repeater {
        model: map.stars
        delegate: Item {
            id: star
            required property var modelData
            readonly property bool on: modelData.lit
            readonly property bool held: map.lit === modelData.key
            readonly property real size: on ? 4 : 2.2
            readonly property color tone: on ? map.warm : map.dim
            x: map.sx(modelData.x)
            y: map.sy(modelData.y)

            StarLight {
                tone: star.on ? map.warm : map.words
                r: star.size * (star.on ? 6.5 : 5)
                strength: star.on || star.held ? (star.held ? 0.5 : 0.38) : 0
                cross: star.on ? star.size * 7 : 0
            }
            Rectangle {
                anchors.centerIn: parent
                width: star.size * 1.5; height: width; radius: width / 2
                color: star.tone
                opacity: star.on ? 1 : 0.8
            }
            Rectangle {
                visible: star.held
                anchors.centerIn: parent
                width: star.size * 2 + 16; height: width; radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.tint(star.on ? map.warm : map.words, 0.7)
            }
        }
    }

    // What the star in hand is: its name, its story, when it was lit.
    above: Column {
        id: about
        visible: !!map.litStar
        x: Theme.s4
        width: Math.min(map.width - Theme.s4 * 2, 420)
        y: map.height - height - Theme.s4
        spacing: 2
        Text {
            width: parent.width
            text: map.litStar ? map.litStar.title : ""
            font.family: Theme.font
            font.pixelSize: Theme.textS
            font.weight: Theme.weightName
            color: map.litStar && map.litStar.lit ? map.warm : map.words
            elide: Text.ElideRight
            style: Text.Outline; styleColor: Qt.rgba(0.02, 0.024, 0.04, 0.9)
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: map.litStar ? map.litStar.story : ""
            font.family: Theme.font
            font.pixelSize: Theme.textXs + 1
            color: map.words
            opacity: 0.8
            wrapMode: Text.WordWrap
            style: Text.Outline; styleColor: Qt.rgba(0.02, 0.024, 0.04, 0.9)
        }
        Text {
            text: !map.litStar ? "" : map.litStar.lit ? "Lit " + Format.date(map.litStar.at) : "Still dark"
            font.family: Theme.font
            font.pixelSize: Theme.textXs
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            color: map.words
            opacity: 0.55
        }
    }
}

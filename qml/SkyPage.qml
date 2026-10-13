pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design as Design

/*
    A world's Sky (`/sky`): its milestones as stars in named constellations,
    lit as they are reached, with the comets caught and the real sky's nights
    after them. The map on top; under it a card per constellation, its story
    and its stars, each lit one with its day. A world adds the page and its
    `sky` command (which gives `sol_quick::sky::show`'s view); the lighting,
    the comets and the real sky are the kit's.

    In an app that carries moons, the moons without a Sky page of their
    own have theirs here too: a tab per world, the planet's first
    (`/sky?tab=titan`), each from that world's own `sky` command on its
    own link.

        pages: ({ "/sky": skyPage }) … Component { id: skyPage; SkyPage { } }
*/
Design.Screen {
    id: page

    title: "Sky"

    property var sky: null
    property string chosen: params.star || ""
    /** The worlds whose skies show here, as tabs: this page's, then the moons the window carries without a Sky of their own. */
    readonly property var worlds: {
        const sh = page.shell
        const moons = sh && page.world === "" ? sh.moons.filter(m => !sh.pages["/" + m + "/sky"]) : []
        return moons.length ? [Sol.world].concat(moons) : []
    }
    /** The world whose sky shows: this page's, or the tab's. */
    readonly property string showing: head.current !== "" && head.current !== Sol.world ? head.current : page.world
    readonly property var sol: Sol.of(page.showing)
    property int asked: 0
    function load() {
        const n = ++asked
        // The world asked of now, not `sol`, which may not have followed a new tab yet.
        const of = Sol.of(page.showing)
        of.call("sky").then(v => { if (n === page.asked) Sol.update(page, "sky", v) }).catch(why => of.fail("Couldn’t draw the sky", why))
    }
    Component.onCompleted: load()
    // Another world's sky: the one before goes, and nothing is chosen in it.
    onShowingChanged: { sky = null; chosen = params.star || ""; load() }
    // (Through `shown`: inside a Watch, `page` is the Watch's own.)
    QtObject { id: shown; readonly property string world: page.showing; function load() { page.load() } }
    Design.Watch { world: shown.world; collections: ["sky"]; onChanged: shown.load() }

    readonly property int lit: sky ? sky.lit : 0
    readonly property int total: sky ? sky.total : 0

    header: Design.PageHead {
        id: head
        eyebrow: "Your sky"
        title: "Sky"
        tabs: page.worlds.map(w => ({ id: w, label: Worlds.get(w).name, hint: Worlds.get(w).role }))
        tab: page.params.tab || ""
        lead: !page.sky ? "" : page.lit === 0 ? "Still dark: every milestone lights a star."
            : Format.plural(page.lit, "star") + " lit of " + page.total
    }

    Design.SkyMap {
        width: parent.width
        height: Math.max(320, Math.min(600, width * 0.58))
        view: page.sky
        chosen: page.chosen
        onChoose: key => page.chosen = key
    }

    Design.Grid {
        min: 300
        Repeater {
            model: page.sky ? page.sky.constellations : []
            delegate: Design.Card {
                id: c
                required property var modelData
                title: modelData.title
                readonly property var stars: page.sky ? page.sky.stars.filter(s => s.constellation === c.modelData.id) : []
                // Each is headed as a constellation, with how many of its stars are lit.
                jp: "星座 " + c.stars.filter(s => s.lit).length + "/" + c.stars.length
                Design.Words { width: parent.width; visible: text !== ""; quiet: true; small: true; text: c.modelData.story }
                Repeater {
                    model: c.stars
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: parent ? parent.width : 0
                        height: Math.max(name.implicitHeight, 22)
                        readonly property bool held: page.chosen === modelData.key
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.modelData.lit ? 7 : 5; height: width; radius: width / 2
                            x: 4 - width / 2
                            color: row.modelData.lit ? Theme.textWorld : "transparent"
                            border.width: row.modelData.lit ? 0 : 1
                            border.color: Theme.textFaint
                        }
                        Text {
                            id: name
                            x: 16
                            width: parent.width - x - when.implicitWidth - Theme.s2
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.title
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: Theme.textS
                            font.weight: row.held ? Theme.weightName : Font.Normal
                            color: row.modelData.lit ? Theme.text : Theme.textQuiet
                        }
                        Text {
                            id: when
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.lit ? Format.date(row.modelData.at) : ""
                            font.family: Theme.font
                            font.pixelSize: Theme.textXs
                            color: Theme.textFaint
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.chosen = row.held ? "" : row.modelData.key
                        }
                    }
                }
                Design.Quiet { text: c.modelData.lit + " of " + c.modelData.total + " lit" }
            }
        }
    }
}

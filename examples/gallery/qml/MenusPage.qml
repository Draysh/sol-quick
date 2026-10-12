pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    Things with menus (`/menus`, a child of Panels in the sidebar): rows
    and a card that are things, each with one menu given to its
    right-click (MenuArea, Card's `menu`) and its ⋯ (MoreButton), and a
    nested entry ("Rate…", its numbers inside). `_nested=1` in the shot path
    opens the card's menu with "Rate…" out.
*/
Screen {
    id: page

    title: "Menus"
    property bool menuOpen: false
    readonly property var win: page.Window.window as AppWindow

    readonly property var stations: [{ name: "Night drive", kind: "Radio", rating: 8 }, { name: "Morning light", kind: "Radio", rating: 6 }, { name: "Rain on glass", kind: "Ambient", rating: 0 }]

    /** One thing's menu: the same for its row, its card and its ⋯. */
    function menuFor(thing) {
        return [
            { label: "Play", icon: "play", run: () => Notices.show({ world: "neptune", title: "Playing", body: thing.name }) },
            { label: "Rate…", icon: "star", items: Array.from({ length: 10 }, (_, n) => ({ label: String(n + 1) + (thing.rating === n + 1 ? " (now)" : ""), run: () => Notices.show({ world: "saturn", title: "Rated " + (n + 1), body: thing.name }) })) },
            { separator: true },
            { label: "Remove", danger: true, run: () => { } }
        ]
    }

    header: PageHead { title: "Menus"; lead: "Right-click a thing, or its More button" }

    Timer { id: menuLater; interval: 900; onTriggered: { page.win.menu.openAt(stationCard.moreButton, null, page.menuFor(page.stations[0])); page.win.menu.choose(page.win.menu.entries[1], 1, page.win.menu.rowY(page.win.menu.entries, 1)) } }
    Settling { when: menuLater.running }
    Component.onCompleted: if (menuOpen && win) menuLater.start()
    onMenuOpenChanged: if (menuOpen && win) menuLater.start()

    Grid {
        width: parent.width
        min: 300
        Card {
            id: stationCard
            title: page.stations[0].name
            menu: () => page.menuFor(page.stations[0])
            Words { width: parent.width; quiet: true; text: "A card that is a thing: right-click it, or the button in its head." }
        }
        Card {
            title: "Rows that are things"
            Column {
                width: parent.width
                Repeater {
                    model: page.stations
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Theme.target
                        Rectangle { anchors.fill: parent; radius: Theme.radiusM; color: rowMouse.containsMouse ? Theme.surface : "transparent" }
                        Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.line }
                        Words { x: Theme.s2; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.name }
                        Quiet { anchors.right: rowMore.left; anchors.rightMargin: Theme.s2; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.kind }
                        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true }
                        MenuArea { anchors.fill: parent; menu: () => page.menuFor(row.modelData) }
                        MoreButton { id: rowMore; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; hint: "More for " + row.modelData.name; menu: () => page.menuFor(row.modelData) }
                    }
                }
            }
        }
    }
}

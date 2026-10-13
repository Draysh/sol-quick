import QtQuick
import Sol.Design

/*
    The gallery moon's first page (`/moon`): a Sheet, and a reply from the
    moon's own command through its own link, as a carried moon's pages
    reach theirs (`Sol.of(world)`).
*/
Screen {
    id: page

    title: "Tonight"
    padded: false
    readonly property var sol: Sol.of("moon")
    property string said: ""
    Component.onCompleted: page.sol.call("hello").then(t => page.said = t).catch(why => page.sol.fail("No answer", why))

    header: Sheet {
        world: "luna"
        name: "Moon"
        callout: ["Carried = in the gallery", "Its link = its own"]
        figures: [{ value: page.sol.paired ? "On" : "—", label: "Paired", jp: "接続" }]
    }

    Column {
        x: page.margin
        width: parent.width - page.margin * 2
        spacing: Theme.s4
        Card {
            width: parent.width
            title: "From the moon's own command"
            world: "moon"
            Words { width: parent.width; text: page.said }
        }
    }
}

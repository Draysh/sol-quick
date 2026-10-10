pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    What sits over the pages, on glass: the right-click menu (with a list
    that opens beside it), the command palette, the dialog both ways, the
    notices (one with a button), what's kept aside instead of sent, and a
    hint. Each has a button here; the shot keys stage them too (`_palette`,
    `_ask`, `_notice`, `_notify`, `_kept`, `_problem=newer|damaged`, and the
    gallery's own `_menu`).
*/
Screen {
    id: page

    title: "Overlays"
    /** The menu opens under its button as the page shows (`_menu=1`). */
    property bool menuOpen: false

    readonly property var win: page.Window.window
    readonly property var entries: [
        { label: "Rename", run: () => { } },
        { label: "Move to", items: () => [{ label: "Watching", run: () => { } }, { label: "Later", run: () => { } }, { label: "Done", run: () => { } }] },
        { label: "Open in Sol", run: () => { } },
        { separator: true },
        { label: "Remove", danger: true, run: () => { } }
    ]
    property string answer: ""
    /** The dialog, the palette or the menu is over the page: the pinned hint steps aside. */
    readonly property bool covered: !!win && (!!win.ask.current || win.commandPalette.open || win.menu.open || win.keptAside.shown)
    readonly property var kept: [
        { seq: 1, why: "conflict", kind: "put", collection: "habits", id: "walk", data: { name: "Walk outside, 30 min" }, theirs: { version: 9, deleted: false, data: { name: "Walk outside" } } },
        { seq: 2, why: "rejected", kind: "put", collection: "entries", id: "2026-10-10", data: { text: "A very long diary entry" }, message: "a document is at most 1 MiB" },
        { seq: 3, why: "earlier", kind: "event", data: { summary: "Did “Read”, 4 days in a row" } }
    ]

    Timer { id: menuLater; interval: 900; onTriggered: page.win.menu.showUnder(menuButton, page.entries) }
    Component.onCompleted: if (menuOpen) menuLater.start()

    header: PageHead {
        title: "Overlays"
        lead: "The menu, the palette, the dialog, notices and hints"
    }

    Grid {
        width: parent.width
        min: 360

        Card {
            title: "ContextMenu"
            menu: page.entries
            Flow {
                width: parent.width
                spacing: Theme.s2
                Button { id: menuButton; text: "Open the menu"; onClicked: page.win.menu.showUnder(menuButton, page.entries) }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Or right-click this card. Up and Down choose, Right opens Move to, Escape closes." }
        }
        Card {
            title: "CommandPalette"
            Button { text: "Open the palette"; hint: "Ctrl+K, anywhere"; onClicked: page.win.commandPalette.show() }
            Words { width: parent.width; small: true; quiet: true; text: "Finds the pages, the window’s own commands, and the worlds by name as you type." }
        }
        Card {
            title: "Ask"
            Flow {
                width: parent.width
                spacing: Theme.s2
                Button { text: "A name"; onClicked: page.win.ask.name("New playlist", "Name", "Late nights", "Create").then(n => page.answer = n === null ? "No name" : "Named “" + n + "”") }
                Button { variant: "quiet"; text: "A yes or no"; onClicked: page.win.ask.confirm("Remove it?", "Its status, rating and notes go too. Everything else stays.", "Remove").then(yes => page.answer = yes ? "Removed" : "Kept") }
            }
            DataRows { width: parent.width; rows: [{ label: "Answered", value: page.answer || "nothing yet" }] }
        }
        Card {
            title: "Notice"
            Flow {
                width: parent.width
                spacing: Theme.s2
                Button { text: "A notice"; onClicked: Notices.show({ world: page.win.world, title: "Saved", body: "A notice, on glass, over the page." }) }
                Button { variant: "quiet"; text: "A failure"; onClicked: Sol.fail("Not saved", "Sol isn’t answering; it’s kept here and sent when it is.") }
                Button { variant: "quiet"; text: "With a button"; hint: "A conflict’s notice, and what it opens"
                    onClicked: Notices.show({ world: page.win.world, title: "Changed on another device too", body: "Both copies are kept; you choose which stays.", action: "See both", run: () => page.win.keptAside.open(page.kept) }) }
                Button { variant: "quiet"; text: "On the desktop"; hint: "A desktop notification, with a button"; onClicked: Sol.call("notify", { title: "A notification", body: "From the gallery, on the desktop.", action: ["hello", "Say hello"] }).catch(why => Sol.fail("Not shown", why)) }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Each leaves after six seconds (one with a button, twelve); the time stops while the pointer is on one." }
        }
        Card {
            title: "Hint"
            Toggle { id: pinHint; width: parent.width; label: "Show the hint"; checked: true; onToggled: on => checked = on }
            Item {
                width: parent.width
                height: Theme.control
                Button { id: hinted; text: "Rest the pointer here"; hint: "A button’s own hint, on hover" }
            }
            Item {
                width: 1; height: Theme.s5
                Hint { text: "One line, a moment after the pointer rests"; when: page.visible && pinHint.checked && !page.covered }
            }
        }
    }
}

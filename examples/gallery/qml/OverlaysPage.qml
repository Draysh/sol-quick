pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    What sits over the pages, on glass: the right-click menu (with a list
    that opens beside it), the command palette, the dialog both ways, the
    notices (one with a button), what's kept aside instead of sent, and a
    hint, and a moment (a scene over the whole window, played once). Each
    has a button here; the shot keys stage them too (`_palette`, `_ask`, `_tour`,
    `_notice`, `_notify`, `_kept`, `_problem=newer|damaged`, `_capture=<line>`,
    and the gallery's own `_menu` and `_moment`).
*/
Screen {
    id: page

    title: "Overlays"
    /** The menu opens under its button as the page shows (`_menu=1`). */
    property bool menuOpen: false
    /** The moment plays as the page shows (`_moment=1`). */
    property bool momentNow: false
    function playMoment() { page.win.moment.play({ scene: sampleMoment, chime: true, facts: { title: "Frieren", lead: "Finished", line: "Started in March, finished tonight", facts: [{ label: "Episodes", value: "28" }, { label: "Hours", value: "11" }, { label: "Rated", value: "9" }] } }) }

    readonly property var win: page.Window.window
    readonly property var entries: [
        { label: "Rename", icon: "edit", run: () => { } },
        { label: "Move to", items: () => [{ label: "Watching", run: () => { } }, { label: "Later", run: () => { } }, { label: "Done", run: () => { } }] },
        { label: "Open in Sol", icon: "external", run: () => { } },
        { separator: true },
        { label: "Remove", icon: "trash", danger: true, run: () => { } }
    ]
    property string answer: ""
    /** The dialog, the palette or the menu is over the page: the pinned hint steps aside. */
    readonly property bool covered: !!win && (!!win.ask.current || win.moment.showing || win.commandPalette.open || win.menu.open || win.keptAside.shown)
    readonly property var kept: [
        { seq: 1, why: "conflict", kind: "put", collection: "habits", id: "walk", data: { name: "Walk outside, 30 min" }, theirs: { version: 9, deleted: false, data: { name: "Walk outside" } } },
        { seq: 2, why: "rejected", kind: "put", collection: "entries", id: "2026-10-10", data: { text: "A very long diary entry" }, message: "a document is at most 1 MiB" },
        { seq: 3, why: "earlier", kind: "event", data: { summary: "Did “Read”, 4 days in a row" } }
    ]

    Timer { id: menuLater; interval: 900; onTriggered: page.win.menu.showUnder(menuButton, page.entries) }
    Timer { id: momentLater; interval: 600; onTriggered: page.playMoment() }
    Component.onCompleted: { if (menuOpen) menuLater.start(); if (momentNow) momentLater.start() }
    // Asked for again by the next picture of a batch.
    onMenuOpenChanged: if (menuOpen) menuLater.start()
    onMomentNowChanged: if (momentNow) momentLater.start()
    Settling { when: menuLater.running || momentLater.running }

    // A moment's scene: a world drifting up behind the words, and its rings lit.
    Component {
        id: sampleMoment
        Item {
            id: scene
            property var moment
            readonly property real p: moment ? moment.progress : 0
            Body {
                id: big
                world: "saturn"
                disc: Math.min(scene.width * 0.62, scene.height * 0.9, 760)
                x: (scene.width - disc) / 2 + (1 - scene.p) * 40
                y: scene.height * 0.34 - disc / 2 - scene.p * 20
                opacity: 0.85
            }
            Rings {
                cx: big.x + big.disc / 2; cy: big.y + big.disc / 2 - big.disc * 0.008
                body: big.disc * 0.2; radii: [2.44]; aspect: 0.093; color: "#ffe2a8"; soft: true; line: 3; alpha: 0.9
                // Lit up, then settling to a glow that stays.
                opacity: scene.p < 0.35 ? scene.p / 0.35 : 1 - (scene.p - 0.35) * 0.6
            }
            MomentCaption {
                moment: scene.moment
                width: Math.min(scene.width - 64, 720)
                x: (scene.width - width) / 2
                // Standing on the bottom bar, as Saturn's does, so its figures are never under it.
                y: scene.height - implicitHeight - (scene.moment ? scene.moment.barHeight : 0) - Theme.s7
                lead: scene.moment ? scene.moment.facts.lead : ""
                title: scene.moment ? scene.moment.facts.title : ""
                line: scene.moment ? scene.moment.facts.line : ""
                facts: scene.moment ? scene.moment.facts.facts : []
            }
        }
    }

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
                Button { variant: "quiet"; text: "A machine’s failure"; hint: "Said as a person would, the raw words under Details"; onClicked: Sol.fail("Couldn’t play that", "ALSA function 'snd_pcm_open' failed with error 'ENOENT: No such file or directory'") }
                Button { variant: "quiet"; text: "With a button"; hint: "A conflict’s notice, and what it opens"
                    onClicked: Notices.show({ world: page.win.world, title: "Changed on another device too", body: "Both copies are kept; you choose which stays.", action: "See both", run: () => page.win.keptAside.open(page.kept) }) }
                Button { variant: "quiet"; text: "On the desktop"; hint: "A desktop notification, with a button"; onClicked: Sol.call("notify", { title: "A notification", body: "From the gallery, on the desktop.", action: ["hello", "Say hello"] }).catch(why => Sol.fail("Not shown", why)) }
            }
            Words { width: parent.width; small: true; quiet: true; text: "Each leaves after six seconds (one with a button, twelve); the time stops while the pointer is on one." }
        }
        Card {
            title: "Moment"
            Button { text: "Play a moment"; hint: "A scene over the window, once; any key ends it"; onClicked: page.playMoment() }
            Words { width: parent.width; small: true; quiet: true; text: "Plays once for each occasion, on any device; short and still with less motion." }
        }
        Card {
            title: "Tour"
            Button { text: "Take the tour"; hint: "Three cards, once on a device; ? opens it again"; onClicked: page.win.tourSheet.show() }
            Words { width: parent.width; small: true; quiet: true; text: "What the world does, its best key, where to start. Skippable; shown the first time the window is in front." }
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

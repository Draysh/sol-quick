pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
// By name, for Screen: Qt has one of its own.
import Sol.Design as Design

/*
    The moons' part of the planet's Settings page: each carried moon that
    declares one (`Moon.settings`), under the moon's own name and role,
    below the planet's cards. `/settings?part=<moon>` (and so
    `/<moon>/settings`) opens the page scrolled to that moon's part.
    Nothing shows while the app carries no moon with settings.

        Screen { header: PageHead { title: "Settings" }  Grid { … the planet's cards … }  MoonSettings { } }
*/
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: Theme.s6
    topPadding: Theme.s4

    /** The moons' parts, from the window: `{ world, settings }`. */
    readonly property var parts: {
        const win = root.Window.window as Design.AppWindow
        return win ? win.moonSettings : []
    }
    visible: parts.length > 0

    /** The page it is on, and the moon's part it was asked to show. */
    readonly property Design.Screen page: Theme.screenOf(root) as Design.Screen
    readonly property string part: page && page.params ? page.params.part || "" : ""
    onPartChanged: if (part !== "") { reachLater.left = 3; reachLater.restart() }
    Component.onCompleted: if (part !== "") reachLater.start()
    // Asked again while the cards above take their places and heights (a narrow window stacks them all).
    Timer { id: reachLater; interval: 250; repeat: true; property int left: 3; onTriggered: { root.reach(); if (--left <= 0) stop() } }
    Settling { when: reachLater.running }

    /** Scrolls the page so the asked moon's part starts at the top. */
    function reach() {
        if (!page) return
        for (const c of root.children) {
            if (!c.modelData || c.modelData.world !== root.part) continue
            const at = c.mapToItem(page.flickable.contentItem, 0, 0).y - Theme.s4
            page.scrollBy(at - page.contentY)
            return
        }
    }

    Repeater {
        model: root.parts
        delegate: Column {
            id: moon
            required property var modelData
            readonly property var w: Worlds.get(modelData.world)
            width: root.width
            spacing: Theme.s4

            // The moon's name and role over a hairline, as the sidebar names its group.
            Item {
                width: parent.width
                height: name.implicitHeight + Theme.s3 + 1
                WorldGlyph { id: glyph; world: moon.modelData.world; size: 14; anchors.verticalCenter: name.verticalCenter }
                Design.Heading { id: name; x: glyph.width + Theme.s2; level: 2; text: moon.w.name }
                Quiet { anchors.left: name.right; anchors.leftMargin: Theme.s3; anchors.baseline: name.baseline; width: parent.width - x; elide: Text.ElideRight; text: moon.w.role }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
            }
            Loader { width: parent.width; sourceComponent: moon.modelData.settings }
        }
    }
}

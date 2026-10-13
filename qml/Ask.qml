import QtQuick

/*
    A name to type, or a yes/no, on a veil over the window. Each returns a
    promise: the name (or null), or true/false.

        Ask { id: ask }   // once, in the window
        ask.name("New playlist", "Name", "", "Create").then(n => …)
        ask.confirm("Delete playlist", "It goes for every app. The songs stay.", "Delete").then(yes => …)

    A yes that can't be taken back (Delete, Remove, Forget, Unpair, Archive,
    Stop, Clear) is the vermilion danger button; `danger` says so for any other.
*/
Item {
    id: ask

    /** The question waiting for an answer, or null. */
    property var current: null
    /** The question on screen: the last one, still there while it fades out. */
    property var shown: null
    /** What had the keys before; it gets them back after. */
    property Item before: null

    anchors.fill: parent
    visible: !!current || box.opacity > 0
    z: 950

    function name(title, label, value, action) {
        return new Promise(done => begin({ kind: "name", title: title, label: label, value: value || "", action: action || "Save", done: done }))
    }
    function confirm(title, body, action, danger) {
        const yes = action || "Yes"
        const risky = danger !== undefined ? !!danger : /^(delete|remove|forget|unpair|archive|stop|clear|discard)\b/i.test(yes)
        return new Promise(done => begin({ kind: "confirm", title: title, body: body, action: yes, danger: risky, done: done }))
    }
    // A new question while one is open answers the open one with "no".
    function begin(question) {
        const open = current
        if (!open) { before = Window.window ? Window.window.activeFocusItem : null; Sounds.open() }
        current = question
        shown = question
        field.text = question.kind === "name" ? question.value : ""
        Qt.callLater(() => { if (ask.current === question) (question.kind === "name" ? field.input : box).forceActiveFocus() })
        if (open) open.done(open.kind === "name" ? null : false)
    }
    function finish(answer) {
        const d = current
        if (!d) return
        current = null
        Sounds.close()
        const name = field.text.trim()
        field.input.focus = false
        box.focus = false
        if (before) before.forceActiveFocus()
        before = null
        if (d.kind === "name") d.done(answer && name ? name : null)
        else d.done(answer)
    }

    Item { anchors.fill: parent; opacity: ask.current ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.5; tint: Theme.tint(Theme.frost, Theme.light ? 0.86 : 0.55) }
        MouseArea { anchors.fill: parent; enabled: !!ask.current; onClicked: ask.finish(false) } }

    Item {
        id: box
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        height: card.implicitHeight
        opacity: ask.current ? 1 : 0
        scale: ask.current ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing: Theme.easeOut } }
        Keys.onEscapePressed: ask.finish(false)
        Keys.onReturnPressed: ask.finish(true)
        Keys.onEnterPressed: ask.finish(true)
        MouseArea { anchors.fill: parent }
        Card {
            id: card
            width: parent.width
            radius: Theme.radiusL
            title: ask.shown ? ask.shown.title : ""
            gap: Theme.s4
            Field { id: field; visible: !!ask.shown && ask.shown.kind === "name"; width: parent.width; label: ask.shown ? ask.shown.label || "" : ""; maxLength: 200; onAccepted: ask.finish(true) }
            Words { visible: !!ask.shown && ask.shown.kind === "confirm"; width: parent.width; text: ask.shown ? ask.shown.body || "" : "" }
            Row { spacing: Theme.s2
                Button { variant: ask.shown && ask.shown.danger ? "danger" : "primary"; text: ask.shown ? ask.shown.action : ""; enabled: !!ask.current && (ask.current.kind !== "name" || field.text.trim() !== ""); onClicked: ask.finish(true) }
                Button { variant: "quiet"; text: "Cancel"; enabled: !!ask.current; onClicked: ask.finish(false) } }
        }
    }
}

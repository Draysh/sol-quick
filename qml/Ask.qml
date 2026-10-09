import QtQuick

/*
    A name to type, or a yes/no, on a veil over the window. Each returns a
    promise: the name (or null), or true/false.

        Ask { id: ask }   // once, in the window
        ask.name("New playlist", "Name", "", "Create").then(n => …)
        ask.confirm("Delete playlist", "It goes for every app. The songs stay.", "Delete").then(yes => …)
*/
Item {
    id: ask

    property var current: null

    anchors.fill: parent
    visible: !!current
    z: 950

    function name(title, label, value, action) {
        return new Promise(done => ask.current = { kind: "name", title: title, label: label, value: value || "", action: action || "Save", done: done })
    }
    function confirm(title, body, action) {
        return new Promise(done => ask.current = { kind: "confirm", title: title, body: body, action: action || "Yes", done: done })
    }
    function finish(answer) {
        const d = current
        current = null
        if (!d) return
        if (d.kind === "name") d.done(answer && field.text.trim() ? field.text.trim() : null)
        else d.done(answer)
    }
    onCurrentChanged: if (current) { field.text = current.kind === "name" ? current.value : ""; Qt.callLater(() => current && current.kind === "name" ? field.input.forceActiveFocus() : box.forceActiveFocus()) }

    Keys.onEscapePressed: finish(false)
    Item { anchors.fill: parent; opacity: ask.current ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Glass { anchors.fill: parent; blur: 0.5; tint: Qt.rgba(0, 0, 0, 0.55) }
        MouseArea { anchors.fill: parent; onClicked: ask.finish(false) } }

    Item {
        id: box
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        height: card.implicitHeight
        focus: true
        opacity: ask.current ? 1 : 0
        scale: ask.current ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.settle } }
        Behavior on scale { NumberAnimation { duration: Theme.settle; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        Keys.onEscapePressed: ask.finish(false)
        Keys.onReturnPressed: ask.finish(true)
        MouseArea { anchors.fill: parent }
        Card {
            id: card
            width: parent.width
            title: ask.current ? ask.current.title : ""
            gap: Theme.s4
            Field { id: field; visible: !!ask.current && ask.current.kind === "name"; width: parent.width; label: ask.current ? ask.current.label || "" : ""; maxLength: 200; onAccepted: ask.finish(true) }
            Words { visible: !!ask.current && ask.current.kind === "confirm"; width: parent.width; text: ask.current ? ask.current.body || "" : "" }
            Row { spacing: Theme.s2
                Button { variant: "primary"; text: ask.current ? ask.current.action : ""; enabled: !ask.current || ask.current.kind !== "name" || field.text.trim() !== ""; onClicked: ask.finish(true) }
                Button { variant: "quiet"; text: "Cancel"; onClicked: ask.finish(false) } }
        }
    }
}

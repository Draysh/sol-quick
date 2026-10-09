import QtQuick

/*
    The top of a working page: a slim toolbar that stays put while the
    page scrolls under it. The title in the name style, a quiet line beside
    it, and the page's actions on the right. On a page opened from another,
    the way back comes first. Put it in a Screen's `header`.

        Screen { header: PageHead { title: "Settings"; lead: "…"; Button { text: "Export" } } … }
*/
Item {
    id: root

    property string title: ""
    /** A quiet label before the title, e.g. the world it belongs to. */
    property string eyebrow: ""
    property string lead: ""
    default property alias actions: actionRow.data
    /** The Screen this heads; set by Screen. */
    property var screen: null
    /** The title can be changed in place: click it and type; `renamed` carries the new one. */
    property bool editable: false
    signal renamed(string title)

    readonly property var back: screen && screen.back ? screen.back : null
    readonly property real margin: Theme.margin(width)

    implicitHeight: Math.max(Theme.navHeight, Math.max(textRow.implicitHeight, actionRow.implicitHeight) + Theme.s2 * 2)

    Rectangle { anchors.fill: parent; color: Theme.deep }
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
    // What slides under the bar dims out over a few pixels first; nothing has, nothing dims.
    readonly property real scrolled: screen && screen.contentY > 0 ? Math.min(1, screen.contentY / 32) : 0
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.bottom
        height: 14
        opacity: root.scrolled
        gradient: Gradient { GradientStop { position: 0; color: Theme.tint(Theme.deep, 0.8) } GradientStop { position: 1; color: Theme.tint(Theme.deep, 0) } }
    }

    Flow {
        id: textRow
        anchors.left: parent.left
        anchors.leftMargin: root.margin
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - root.margin * 2 - (actionRow.implicitWidth > 0 ? actionRow.implicitWidth + Theme.s4 : 0)
        spacing: Theme.s3

        Back { visible: !!root.back; label: root.back ? root.back.label : ""; onGo: root.back.go() }
        Quiet { visible: root.eyebrow !== ""; text: root.eyebrow; height: 32; verticalAlignment: Text.AlignVCenter }
        Heading { visible: !root.editable; level: 3; text: root.title; height: 32; verticalAlignment: Text.AlignVCenter }
        Editable { visible: root.editable; text: root.title; size: Theme.textM; weight: Theme.weightName; caps: true; color: Theme.text; height: 32; hint: "Click to rename"; onCommitted: t => root.renamed(t) }
        Text {
            visible: root.lead !== ""
            text: root.lead
            height: 32; verticalAlignment: Text.AlignVCenter
            font.family: Theme.font; font.pixelSize: Theme.textS; font.weight: Theme.weightValue
            color: Theme.textQuiet
            onTextChanged: fade.restart()
            NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.fade; running: false }
        }
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: root.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s2
    }
}

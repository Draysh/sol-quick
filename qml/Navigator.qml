import QtQuick
import QtQuick.Shapes

/*
    The world's navigator in the Yozora look: a character's portrait
    (`Theme.mascotOf`, a picture on this computer only) in a frame with
    one corner cut, its name in the mono face, and a speech panel over it
    with what it says about the page: the page's own `say`, the line of
    its empty state, a greeting on the first page, else what the section
    is for. A moon's pages have their planet's. The sidebar keeps it in
    its foot while the rows leave room; without the portrait it isn't
    there at all.

        Navigator { width: parent.width; line: shell.navigatorLine }
*/
Item {
    id: root

    /** What it says: a sentence or two. */
    property string line: ""
    /** Whose navigator: the window's world (a moon's is its planet's). */
    property string world: Sol.world
    readonly property string portrait: Theme.yozora ? Theme.mascotOf(world) : ""
    /** Whether there is one to show: the look is on and the portrait is here. */
    readonly property bool here: portrait !== "" && face.status !== Image.Error
    /** Small: the portrait smaller, the speech beside it, for a short sidebar. */
    property bool compact: false
    /** How tall it is in each size, for the sidebar to choose. */
    readonly property real fullHeight: (line !== "" ? Math.min(5, Math.ceil(line.length / 30)) * 16 + Theme.s2 * 2 + 1 + Theme.s2 + 6 : 0) + 72
    /** The height the sidebar can give it: small, the speech grows into it to say more of the line. */
    property real space: 0
    readonly property real compactHeight: Math.max(58, Math.min(space, measure.implicitHeight + Theme.s2 * 2))
    /** One line of its words, in pixels, for how many fit. */
    readonly property real lineStep: measure.lineCount > 0 ? measure.implicitHeight / measure.lineCount : 18

    implicitHeight: !here ? 0 : compact ? compactHeight : frame.y + frame.height
    visible: here

    // What it says, in a panel with a tail down to the portrait.
    Item {
        id: speech
        x: root.compact ? frame.width + Theme.s2 : 0
        width: parent.width - x
        // Nothing to say: the portrait alone.
        visible: root.line !== ""
        height: visible ? (root.compact ? root.compactHeight : words.implicitHeight + Theme.s2 * 2 + 1) : 0
        Rectangle {
            anchors.fill: parent
            color: Theme.tint(Theme.hud.ground, 0.55)
            border.width: 1
            border.color: Theme.tint(Theme.hudAccent, 0.45)
        }
        // The tail, down towards the portrait.
        Shape {
            visible: !root.compact
            x: 20; y: parent.height - 1
            width: 12; height: 7
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.tint(Theme.hudAccent, 0.45)
                fillColor: Theme.tint(Theme.hud.ground, 0.55)
                startX: 0; startY: 0
                PathLine { x: 6; y: 7 }
                PathLine { x: 12; y: 0 }
            }
        }
        Text {
            id: words
            x: Theme.s2 + 2; y: Theme.s2
            width: parent.width - x * 2
            text: root.line
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? Math.max(3, Math.floor((root.compactHeight - Theme.s2 * 2) / root.lineStep)) : 5
            elide: Text.ElideRight
            lineHeight: 1.15
            font.family: Theme.font; font.pixelSize: Theme.textXs + 1
            color: Theme.hudText
            onTextChanged: if (words.text !== "") said.restart()
            NumberAnimation on opacity { id: said; from: 0; to: 1; duration: Theme.settle; running: false }
        }
        // The whole line at the small size's width, unseen: how tall the speech would like to be.
        Text {
            id: measure
            visible: false
            width: (root.width - frame.width - Theme.s2) - (Theme.s2 + 2) * 2
            text: root.line
            wrapMode: Text.Wrap
            lineHeight: 1.15
            font: words.font
        }
    }

    // The portrait, cut at a corner, and its name beside it.
    Item {
        id: frame
        y: speech.visible && !root.compact ? speech.height + Theme.s2 + 6 : 0
        width: root.compact ? 46 : 58; height: root.compact ? Math.min(root.compactHeight, 72) : 72
        Image {
            id: face
            anchors.fill: parent
            anchors.margins: 1
            source: root.portrait
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            asynchronous: true
            smooth: true
            sourceSize.width: 160
            visible: false
        }
        // Cut like the panels: the picture shows through the glass shader's shape.
        ShaderEffect {
            anchors.fill: parent
            property variant source: face
            property vector2d size: Qt.vector2d(width, height)
            property vector4d cuts: Qt.vector4d(0, 14, 0, 0)
            property color tint: Theme.hud.ground
            property real tintAlpha: 0
            property color line: Theme.hudAccent
            property real lineAlpha: 0.9
            property real glassy: face.status === Image.Ready ? 1 : 0
            property vector4d rect: Qt.vector4d(0, 0, 1, 1)
            property color accent: Theme.hudAccent
            property real motif: 0
            property real glow: 0
            fragmentShader: "../shaders/hud.frag.qsb"
        }
        Settling { when: face.status === Image.Loading }
    }
    Column {
        visible: !root.compact
        x: frame.width + Theme.s2 + 2
        anchors.bottom: frame.bottom
        width: parent.width - x
        spacing: 2
        Text {
            text: "案内役"
            font.family: Theme.fontTitle; font.pixelSize: Theme.textXs; font.weight: Font.Bold
            color: Theme.hudAccent
        }
        Text {
            width: parent.width
            text: Theme.yozoraOf(root.world).navigator || ""
            elide: Text.ElideRight
            font.family: Theme.fontMono; font.pixelSize: Theme.textXs; font.weight: Font.Bold
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.hudText
        }
        Text {
            text: "Navigator"
            font.family: Theme.fontMono; font.pixelSize: Theme.textXs - 1
            font.letterSpacing: Theme.track(Theme.trackHud, Theme.textXs); font.capitalization: Font.AllUppercase
            color: Theme.hudFaint
        }
    }
}

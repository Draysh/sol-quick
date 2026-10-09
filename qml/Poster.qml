import QtQuick

/*
    A cover from the network, 2:3, with a hairline around it and the name
    in its place while it loads or when there is none. Lifts a touch on
    hover when `lift` is on.

        Poster { source: Titan.art(pick.poster); name: pick.name; width: 92 }
*/
Item {
    id: root

    property string source: ""
    property string name: ""
    property bool lift: false
    property bool hovered: false

    implicitWidth: 92
    implicitHeight: width * 1.5
    height: width * 1.5
    clip: true

    Rectangle { anchors.fill: parent; color: Theme.surface; border.width: 1; border.color: Theme.line }
    Text {
        anchors.fill: parent
        anchors.margins: Theme.s2
        visible: picture.status !== Image.Ready
        text: root.name
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font; font.pixelSize: Theme.textXs; font.weight: Theme.weightValue
        color: Theme.textQuiet
    }
    Image {
        id: picture
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 342
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        scale: root.lift && root.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.rise; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
    }
}

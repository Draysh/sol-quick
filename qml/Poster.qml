import QtQuick

/*
    A cover from the network, 2:3, with a hairline around it and the name
    in its place while it loads or when there is none: a Picture with
    those set. Lifts a touch while `hovered` (the caller says when) when
    `lift` is on.

        Poster { source: Titan.art(pick.poster); name: pick.name; width: 92 }
*/
Picture {
    id: root

    /** The cover's address. */
    property alias source: root.url

    implicitWidth: 92
    outline: true
    nameLines: 1000
    sourceWidth: 342
    mipmap: false
}

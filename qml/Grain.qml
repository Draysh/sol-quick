import QtQuick

/*
    Film grain over the whole screen: black specks of varying alpha,
    nothing to see over pure black, a fine texture over photographs and
    light type. One tiled layer the compositor lays over everything; none
    in the Yozora look.
*/
Image {
    anchors.fill: parent
    source: "../assets/grain.png"
    fillMode: Image.Tile
    // By day the specks show as speckle on paper: a touch only.
    opacity: Theme.day ? 0.04 : 0.14
    enabled: false
    // The Yozora look has no grain: its stills are clean.
    visible: !Theme.yozora
    z: 100
}

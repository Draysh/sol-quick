import QtQuick

/*
    Film grain over the whole screen: black specks of varying alpha,
    nothing to see over pure black, a fine texture over photographs and
    light type. One tiled layer the compositor lays over everything.
*/
Image {
    anchors.fill: parent
    source: "../assets/grain.png"
    fillMode: Image.Tile
    opacity: 0.14
    enabled: false
    z: 100
}

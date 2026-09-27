import QtQuick
import "../BrandingArt.js" as BrandingArt

Image {
    property var artwork: null
    property color logoColor: "white"

    source: BrandingArt.source(artwork, String(logoColor))
    sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}

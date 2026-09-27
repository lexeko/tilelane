pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property string fontFamily: "monospace"
    property real opticalSize: 13
    property real sourceFontSize: 64
    readonly property rect paintedBounds: glyphMetrics.tightBoundingRect
    readonly property real sourceExtent: Math.max(1, paintedBounds.width, paintedBounds.height)
    readonly property real sourceAreaExtent: Math.sqrt(Math.max(1, paintedBounds.width * paintedBounds.height))
    readonly property real areaScale: Math.max(0, opticalSize) / sourceAreaExtent
    readonly property real maximumExtentScale: Math.max(0, opticalSize) * 1.35 / sourceExtent
    readonly property real fitScale: Math.min(areaScale, maximumExtentScale)
    readonly property real paintedWidth: paintedBounds.width * fitScale
    readonly property real paintedHeight: paintedBounds.height * fitScale
    readonly property real paintedCenterX: glyph.x + fitScale * (paintedBounds.x + paintedBounds.width / 2)
    readonly property real paintedCenterY: glyph.y + fitScale * (glyph.baselineOffset + paintedBounds.y + paintedBounds.height / 2)

    width: opticalSize
    height: opticalSize

    TextMetrics {
        id: glyphMetrics

        font.family: root.fontFamily
        font.pixelSize: root.sourceFontSize
        font.hintingPreference: Font.PreferNoHinting
        text: root.text
    }

    Text {
        id: glyph

        x: root.width / 2 - root.fitScale * (root.paintedBounds.x + root.paintedBounds.width / 2)
        y: root.height / 2 - root.fitScale * (baselineOffset + root.paintedBounds.y + root.paintedBounds.height / 2)
        textFormat: Text.PlainText
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.sourceFontSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.NativeRendering
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: root.fitScale
            yScale: root.fitScale
        }
    }
}

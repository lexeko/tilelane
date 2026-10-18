pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property string fontFamily: "monospace"
    property real uiScale: 1
    property real opticalSize: 12 * uiScale
    property real sourceFontSize: 64
    readonly property rect paintedBounds: glyphMetrics.tightBoundingRect
    readonly property real sourceExtent: Math.max(1, paintedBounds.width, paintedBounds.height)
    // Fit painted bounds, not the font's advance, line box, or bounding area.
    // Every glyph shares one maximum extent, including narrow and wide shapes.
    readonly property real fitScale: Math.max(0, opticalSize) / sourceExtent
    readonly property real paintedWidth: paintedBounds.width * fitScale
    readonly property real paintedHeight: paintedBounds.height * fitScale
    readonly property real paintedCenterX: glyph.x + fitScale * (paintedBounds.x + paintedBounds.width / 2)
    readonly property real paintedCenterY: glyph.y + fitScale * (glyph.baselineOffset + paintedBounds.y + paintedBounds.height / 2)

    width: opticalSize
    height: opticalSize
    implicitWidth: opticalSize
    implicitHeight: opticalSize

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
        renderType: Text.QtRendering
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: root.fitScale
            yScale: root.fitScale
        }
    }
}

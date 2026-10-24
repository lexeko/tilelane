pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property string fontFamily: "monospace"
    property real uiScale: 1
    // Standalone pictograms need optical sizing; related state glyphs must
    // retain one font scale so added detail does not shrink the base symbol.
    property bool opticalSizing: false
    readonly property real opticalSize: 16 * uiScale
    readonly property real opticalInset: uiScale
    readonly property int renderedFontSize: opticalSizing ? 64 : Math.max(1, Math.round(13 * uiScale))
    readonly property rect paintedBounds: glyphMetrics.tightBoundingRect
    readonly property real fitScale: opticalSizing ? (opticalSize - 2 * opticalInset) / Math.max(1, paintedBounds.width, paintedBounds.height) : 1
    readonly property real paintedWidth: paintedBounds.width * fitScale
    readonly property real paintedHeight: paintedBounds.height * fitScale
    readonly property real paintedCenterX: glyph.x + fitScale * (paintedBounds.x + paintedBounds.width / 2)
    readonly property real paintedCenterY: glyph.y + fitScale * (glyph.baselineOffset + paintedBounds.y + paintedBounds.height / 2)
    readonly property real baselineY: glyph.y + glyph.baselineOffset * fitScale

    width: opticalSize
    height: opticalSize
    implicitWidth: opticalSize
    implicitHeight: opticalSize

    TextMetrics {
        id: glyphMetrics
        font: glyph.font
        text: root.text
    }

    Text {
        id: glyph

        x: root.width / 2 - root.fitScale * (root.paintedBounds.x + root.paintedBounds.width / 2)
        y: root.opticalSizing ? root.height / 2 - root.fitScale * (baselineOffset + root.paintedBounds.y + root.paintedBounds.height / 2) : (root.height - height) / 2
        textFormat: Text.PlainText
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.renderedFontSize
        font.hintingPreference: root.opticalSizing ? Font.PreferNoHinting : Font.PreferDefaultHinting
        renderType: root.opticalSizing ? Text.QtRendering : Text.NativeRendering
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: root.fitScale
            yScale: root.fitScale
        }
    }
}

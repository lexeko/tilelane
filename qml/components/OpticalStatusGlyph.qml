pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property string fontFamily: "monospace"
    property real uiScale: 1
    readonly property real opticalSize: 16 * uiScale
    readonly property int renderedFontSize: Math.max(1, Math.round(13 * uiScale))
    readonly property rect paintedBounds: glyphMetrics.tightBoundingRect
    readonly property real paintedWidth: paintedBounds.width
    readonly property real paintedHeight: paintedBounds.height
    readonly property real paintedCenterX: glyph.x + paintedBounds.x + paintedBounds.width / 2
    readonly property real paintedCenterY: glyph.y + glyph.baselineOffset + paintedBounds.y + paintedBounds.height / 2
    readonly property real baselineY: glyph.y + glyph.baselineOffset

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

        // Match Omarchy's fixed font and baseline. Only horizontal placement
        // follows painted bounds; changing glyphs must never rescale the font.
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        anchors.horizontalCenterOffset: implicitWidth / 2 - (root.paintedBounds.x + root.paintedBounds.width / 2)
        textFormat: Text.PlainText
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.renderedFontSize
        renderType: Text.NativeRendering
    }
}

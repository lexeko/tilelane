import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui

Ui.OpticalGlyph {
    id: root

    property bool pointsLeft: false
    property bool compact: false
    // Keep hit areas sized for the original bar glyph as the visible icon shrinks.
    readonly property real controlGlyphWidth: controlMetrics.tightBoundingRect.width

    width: Commons.Style.bar.iconCanvas
    height: Commons.Style.bar.iconCanvas
    text: pointsLeft ? "\uf053" : "\uf054"
    fontFamily: Commons.Style.font.family
    fontSize: Math.max(1, Math.round(Commons.Style.font.subtitle * (compact ? 0.75 : 0.9)))

    TextMetrics {
        id: controlMetrics

        font.family: root.fontFamily
        font.pixelSize: Commons.Style.bar.iconFont
        text: root.text
    }
}

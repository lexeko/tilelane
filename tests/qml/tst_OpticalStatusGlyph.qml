import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    name: "OpticalStatusGlyph"
    when: windowShown

    OpticalStatusGlyph {
        id: cloud

        text: "\ue33d"
        opticalSize: 13.4
        sourceFontSize: 64
    }

    OpticalStatusGlyph {
        id: sun

        text: "\uf185"
        opticalSize: 13.4
        sourceFontSize: 64
    }

    function test_dynamicGlyphsStayCentered() {
        fuzzyCompare(cloud.paintedCenterX, cloud.width / 2, 0.01);
        fuzzyCompare(cloud.paintedCenterY, cloud.height / 2, 0.01);
        fuzzyCompare(sun.paintedCenterX, sun.width / 2, 0.01);
        fuzzyCompare(sun.paintedCenterY, sun.height / 2, 0.01);
    }

    function test_dynamicGlyphsUseBoundedAreaNormalization() {
        verify(cloud.paintedWidth > 0);
        verify(cloud.paintedHeight > 0);
        verify(sun.paintedWidth > 0);
        verify(sun.paintedHeight > 0);
        verify(Math.max(cloud.paintedWidth, cloud.paintedHeight) <= cloud.opticalSize * 1.35 + 0.01);
        verify(Math.max(sun.paintedWidth, sun.paintedHeight) <= sun.opticalSize * 1.35 + 0.01);
    }
}

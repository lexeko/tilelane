import "../../qml/BarGeometry.js" as BarGeometry
import QtQuick
import QtTest

TestCase {
    function test_defaultBarHeight() {
        compare(BarGeometry.barScale(1, true, 1), 1);
        compare(BarGeometry.barHeight(1), 44);
    }

    function test_fontScalingMatchesReferenceContract() {
        compare(BarGeometry.barScale(1, true, 1.5), 1.5);
        compare(BarGeometry.barHeight(1.5), 66);
        compare(BarGeometry.barScale(1, false, 2), 1);
    }

    function test_supportedScaleMatrix_data() {
        return [
            {
                "tag": "1x",
                "scale": 1,
                "height": 44
            },
            {
                "tag": "1.25x",
                "scale": 1.25,
                "height": 55
            },
            {
                "tag": "1.5x",
                "scale": 1.5,
                "height": 66
            },
            {
                "tag": "2x",
                "scale": 2,
                "height": 88
            }
        ];
    }

    function test_supportedScaleMatrix(data) {
        compare(BarGeometry.barHeight(data.scale), data.height);
        verify(32 * data.scale >= 32);
        verify(36 * data.scale <= data.height);
    }

    function test_spacingAndFontScaleCompose() {
        compare(BarGeometry.barScale(1.25, true, 1.2), 1.5);
        compare(BarGeometry.barHeight(1.5), 66);
    }

    function test_invalidValuesUseSafeDefaults() {
        compare(BarGeometry.barScale(0, true, -1), 1);
        compare(BarGeometry.barHeight(NaN), 44);
    }

    function test_statusAreaCompactsAtNarrowLogicalWidths() {
        verify(BarGeometry.statusCompact(899, 1));
        verify(!BarGeometry.statusCompact(900, 1));
        verify(BarGeometry.statusCompact(1600, 2));
        verify(!BarGeometry.statusCompact(1920, 2));
        verify(!BarGeometry.statusCompact(0, 1));
    }

    function test_reducedMotionPreservesStateWithZeroDuration() {
        compare(BarGeometry.motionDuration(600, false), 600);
        compare(BarGeometry.motionDuration(600, true), 0);
        compare(BarGeometry.motionDuration(-1, false), 0);
    }

    function test_taskOverflowUsesHalfPixelTolerance() {
        verify(!BarGeometry.taskOverflowing(500, 500));
        verify(!BarGeometry.taskOverflowing(500.5, 500));
        verify(BarGeometry.taskOverflowing(500.6, 500));
        verify(!BarGeometry.taskOverflowing(-1, 0));
    }

    function test_taskScrollClampsAtBothEdges() {
        compare(BarGeometry.taskMaximumScroll(900, 500), 400);
        compare(BarGeometry.taskMaximumScroll(400, 500), 0);
        compare(BarGeometry.taskScrollOffset(100, 180, 900, 500), 280);
        compare(BarGeometry.taskScrollOffset(100, -180, 900, 500), 0);
        compare(BarGeometry.taskScrollOffset(350, 180, 900, 500), 400);
        compare(BarGeometry.taskScrollOffset(NaN, NaN, 900, 500), 0);
    }

    function test_taskWidthsKeepShortTitlesAndShareCompression() {
        const widths = [52, 110, 224, 224];
        compare(BarGeometry.taskWidthCap(widths, 700, 4, 140), 224);
        compare(BarGeometry.taskWidthCap(widths, 500, 4, 140), 163);
        compare(BarGeometry.taskWidthCap(widths, 454, 4, 140), 140);
        compare(BarGeometry.taskWidthCap(widths, 400, 4, 140), 140);
        compare(widths, [52, 110, 224, 224]);
    }

    function test_taskWidthsHandleEmptySingleAndShortOnlyLanes() {
        compare(BarGeometry.taskWidthCap([], 500, 4, 140), 0);
        compare(BarGeometry.taskWidthCap([52], 60, 4, 140), 52);
        compare(BarGeometry.taskWidthCap([224], 180, 4, 140), 180);
        compare(BarGeometry.taskWidthCap([224], 0, 4, 140), 140);
        const widths = [52, 80];
        const cap = BarGeometry.taskWidthCap(widths, 100, 4, 140);
        compare(widths.map(width => Math.min(width, cap)), widths);
    }

    function test_taskWidthsRespectScaleAndInputOrder() {
        for (const scale of [1, 1.25, 1.5, 2]) {
            const widths = [224, 52, 224, 110].map(width => width * scale);
            compare(BarGeometry.taskWidthCap(widths, 500 * scale, 4 * scale, 140 * scale), 163 * scale);
        }
    }

    name: "BarGeometry"
}

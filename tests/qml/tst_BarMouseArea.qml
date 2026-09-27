import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "BarMouseArea"
    when: windowShown
    visible: true
    width: 400
    height: 60
    property int presses: 0

    QtObject {
        id: fakeBar

        property real barHeight: 44
        function registerClickTarget(target) {
        }
        function unregisterClickTarget(target) {
        }
    }

    Item {
        id: surface

        width: 400
        height: fakeBar.barHeight

        Item {
            x: 10
            y: 6
            width: 30
            height: 32

            BarMouseArea {
                id: buttonArea

                bar: fakeBar
                forwardPress: function (button) {
                    testCase.presses++;
                    return true;
                }
                onClicked: testCase.presses++
            }
        }

        Item {
            x: 320
            y: 4
            width: 75
            height: 36

            BarMouseArea {
                bar: fakeBar
                rightPadding: 5
                onClicked: testCase.presses++
            }
        }

        Flickable {
            id: viewport

            x: 100
            width: 80
            height: 44
            contentWidth: 200
            clip: true

            Item {
                y: 4
                width: 80
                height: 36

                BarMouseArea {
                    id: clippedArea

                    bar: fakeBar
                    onClicked: testCase.presses++
                }
            }
        }
    }

    function init() {
        presses = 0;
        viewport.contentX = 0;
    }

    function test_bottomEdgeOutsideVisualButtonIsClickable() {
        compare(buttonArea.height, 38);
        mouseClick(surface, 20, 43);
        compare(presses, 1);
        mouseClick(surface, 45, 43);
        compare(presses, 1);
    }

    function test_clockIncludesBottomRightCorner() {
        mouseClick(surface, 399, 43);
        compare(presses, 1);
    }

    function test_scrolledTasksOnlyExposeVisibleHitArea() {
        viewport.contentX = 40;
        compare(clippedArea.x, 40);
        compare(clippedArea.width, 40);
        mouseClick(surface, 110, 43);
        compare(presses, 1);
        mouseClick(surface, 150, 43);
        compare(presses, 1);
        viewport.contentX = 100;
        compare(clippedArea.width, 0);
    }

    function test_forwardedClickRespectsAcceptedButtons() {
        verify(buttonArea.triggerPress(Qt.LeftButton));
        verify(!buttonArea.triggerPress(Qt.RightButton));
        compare(presses, 1);
    }
}

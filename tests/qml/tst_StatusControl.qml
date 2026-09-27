import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase
    name: "StatusControl"
    when: windowShown
    visible: true
    width: 300
    height: 80
    property int clicks: 0
    property int lastButton: 0

    StatusControl {
        id: control
        x: 10
        y: 10
        width: 60
        height: 32
        activation: function (button) {
            testCase.clicks++;
            testCase.lastButton = button;
            if (button === Qt.LeftButton)
                opened = !opened;
            return true;
        }
    }

    Item {
        id: elsewhere
        x: 100
        width: 30
        height: 30
        activeFocusOnTab: true
    }

    function init() {
        control.opened = false;
        control.pressActionButtons = 0;
        control.wheelAction = null;
        clicks = 0;
        elsewhere.forceActiveFocus();
    }

    function test_mousePanelLifecycleDoesNotLeaveFocusOrUnderline() {
        mouseClick(control, 20, 16, Qt.LeftButton);
        compare(clicks, 1);
        verify(control.opened);
        verify(control.indicatorVisible);
        verify(!control.activeFocus);
        control.opened = false;
        verify(!control.indicatorVisible);
        compare(control.border.width, 0);
        mouseClick(control, 20, 16, Qt.LeftButton);
        mouseClick(control, 20, 16, Qt.LeftButton);
        compare(clicks, 3);
        verify(!control.indicatorVisible);
    }

    function test_keyboardFocusRemainsVisibleAndActivates() {
        control.forceActiveFocus(Qt.TabFocusReason);
        verify(control.indicatorVisible);
        keyClick(Qt.Key_Return);
        compare(clicks, 1);
        verify(control.opened);
        keyClick(Qt.Key_Space);
        verify(!control.opened);
        verify(control.indicatorVisible);
        elsewhere.forceActiveFocus(Qt.TabFocusReason);
        verify(!control.indicatorVisible);
    }

    function test_secondaryButtonsRetainTheirIdentity() {
        mouseClick(control, 20, 16, Qt.RightButton);
        compare(lastButton, Qt.RightButton);
        mouseClick(control, 20, 16, Qt.MiddleButton);
        compare(lastButton, Qt.MiddleButton);
        verify(!control.activeFocus);
    }

    function test_trayPressActionRunsOnceAndKeepsWheelInput() {
        control.pressActionButtons = Qt.RightButton;
        mousePress(control, 20, 16, Qt.RightButton);
        compare(clicks, 1);
        mouseRelease(control, 20, 16, Qt.RightButton);
        compare(clicks, 1);
        let delta = 0;
        control.wheelAction = function (event) {
            delta = event.angleDelta.y;
        };
        mouseWheel(control, 20, 16, 0, 120);
        compare(delta, 120);
    }
}

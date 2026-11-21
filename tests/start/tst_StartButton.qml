import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "StartButton"
    when: windowShown
    visible: true
    width: 240
    height: 80
    property int leftClicks: 0
    property int rightClicks: 0

    QtObject {
        id: fakeBar

        property string shownHint: ""
        property var hintTarget: null
        function registerClickTarget(target) {
        }
        function unregisterClickTarget(target) {
        }
        function showTooltip(target, text) {
            if (target.tooltipHovered) {
                shownHint = text;
                hintTarget = target;
            }
        }
        function hideTooltip(target) {
            if (hintTarget === target) {
                shownHint = "";
                hintTarget = null;
            }
        }
    }

    StartButton {
        id: button

        x: 0
        y: 10
        bar: fakeBar
        leftHitPadding: 5
        bottomHitPadding: 4
        onClicked: testCase.leftClicks++
        onContextMenuRequested: testCase.rightClicks++
    }

    Item {
        id: elsewhere

        x: 160
        width: 30
        height: 30
        activeFocusOnTab: true
    }

    function init() {
        mouseMove(testCase, 200, 60);
        fakeBar.shownHint = "";
        fakeBar.hintTarget = null;
        button.menuOpen = false;
        button.contextMenuOpen = false;
        leftClicks = 0;
        rightClicks = 0;
        elsewhere.forceActiveFocus();
    }

    function test_leftAndRightClicksTriggerExpectedActionsWithoutForcingFocus() {
        mouseMove(button, 20, 16);
        verify(button.tooltipHovered);
        compare(fakeBar.shownHint, "Applications & places");

        mouseClick(button, 20, 16, Qt.LeftButton);
        compare(leftClicks, 1);
        compare(rightClicks, 0);
        compare(fakeBar.shownHint, "");
        verify(!button.activeFocus);

        mouseClick(button, 20, 16, Qt.RightButton);
        compare(leftClicks, 1);
        compare(rightClicks, 1);
        verify(!button.activeFocus);
    }

    function test_forwardedPressHandlesBothButtonsAndRejectsMiddle() {
        verify(button.triggerPress(Qt.LeftButton));
        compare(leftClicks, 1);
        verify(button.triggerPress(Qt.RightButton));
        compare(rightClicks, 1);
        verify(!button.triggerPress(Qt.MiddleButton));
        compare(leftClicks, 1);
        compare(rightClicks, 1);
    }

    function test_contextMenuOpenSuppressesAndClearsTooltip() {
        mouseMove(button, 20, 16);
        verify(button.tooltipHovered);
        compare(fakeBar.shownHint, "Applications & places");

        button.contextMenuOpen = true;
        verify(!button.tooltipHovered);
        compare(fakeBar.shownHint, "");
    }

    function test_keyboardShortcutsOpenMenuAndContextMenu() {
        button.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        compare(leftClicks, 1);
        keyClick(Qt.Key_Menu);
        compare(rightClicks, 1);
        keyClick(Qt.Key_F10, Qt.ShiftModifier);
        compare(rightClicks, 2);
    }
}

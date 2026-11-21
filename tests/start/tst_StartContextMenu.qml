import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "StartContextMenu"
    when: windowShown
    visible: true
    width: 320
    height: 160
    property int superToggles: 0
    property int translucentToggles: 0

    QtObject {
        id: fakeBar

        property var activePopout: null
        function releasePopout(owner) {
            if (activePopout === owner)
                activePopout = null;
        }
    }

    Item {
        id: anchor

        width: 80
        height: 36
    }

    StartContextMenu {
        id: menu

        anchorItem: anchor
        bar: fakeBar
        superStartEnabled: false
        semiTransparent: true
        onSuperStartToggled: {
            testCase.superToggles++;
            superStartEnabled = !superStartEnabled;
        }
        onSemiTransparentToggled: {
            testCase.translucentToggles++;
            semiTransparent = !semiTransparent;
        }
    }

    function init() {
        mouseMove(testCase, 300, 150);
        superToggles = 0;
        translucentToggles = 0;
        menu.open = false;
        menu.superStartEnabled = false;
        menu.semiTransparent = true;
        menu.open = true;
        menu.focusTarget.forceActiveFocus();
        waitForRendering(menu);
    }

    function test_defaultsAndCheckboxMouseTogglesKeepMenuOpen() {
        compare(menu.menuItems.length, 2);
        compare(menu.menuItems[0].action, "super-start");
        compare(menu.checkedFor("super-start"), false);
        compare(menu.menuItems[1].action, "semi-transparent");
        compare(menu.checkedFor("semi-transparent"), true);

        mouseClick(menu, 100, 20, Qt.LeftButton);
        compare(superToggles, 1);
        compare(menu.superStartEnabled, true);
        compare(menu.checkedFor("super-start"), true);
        verify(menu.open);

        mouseClick(menu, 100, 60, Qt.LeftButton);
        compare(translucentToggles, 1);
        compare(menu.semiTransparent, false);
        compare(menu.checkedFor("semi-transparent"), false);
        verify(menu.open);
    }

    function test_keyboardNavigationTogglesAndEscapeCloses() {
        compare(menu.currentIndex, 0);
        keyClick(Qt.Key_Space);
        compare(superToggles, 1);
        compare(menu.superStartEnabled, true);
        verify(menu.open);

        keyClick(Qt.Key_Down);
        compare(menu.currentIndex, 1);
        keyClick(Qt.Key_Return);
        compare(translucentToggles, 1);
        compare(menu.semiTransparent, false);
        verify(menu.open);

        keyClick(Qt.Key_Up);
        compare(menu.currentIndex, 0);

        keyClick(Qt.Key_Escape);
        verify(!menu.open);
    }
}

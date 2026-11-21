import "../../qml/SuperStartLogic.js" as SuperStartLogic
import QtQuick
import QtTest

TestCase {
    function test_luaPayloadsUseReleaseHandlesWithoutUnbind() {
        const enable = SuperStartLogic.enableLua();
        const disable = SuperStartLogic.disableLua();
        verify(enable.indexOf("SUPER + Super_L") !== -1);
        verify(enable.indexOf("SUPER + Super_R") !== -1);
        verify(enable.indexOf("release = true") !== -1);
        verify(enable.indexOf("tilelane:start.toggle") !== -1);
        verify(enable.indexOf("set_enabled(true)") !== -1);
        verify(enable.indexOf("unbind") === -1);
        verify(enable.indexOf(":remove(") === -1);
        verify(disable.indexOf("set_enabled(false)") !== -1);
        verify(disable.indexOf("unbind") === -1);
        verify(disable.indexOf(":remove(") === -1);
        compare(SuperStartLogic.syncLua(true), enable);
        compare(SuperStartLogic.syncLua(false), disable);
    }

    function test_reloadOnlyHandledWhenEnabled() {
        verify(SuperStartLogic.shouldHandleReload("configreloaded", true));
        verify(!SuperStartLogic.shouldHandleReload("configreloaded", false));
        verify(!SuperStartLogic.shouldHandleReload("focusedmon", true));
        verify(!SuperStartLogic.shouldHandleReload("", true));
    }

    function test_pickStartMenuToggleUsesFocusedMonitorAndClosesAnyOpen() {
        const menus = [
            {
                open: false,
                screenName: "eDP-1"
            },
            {
                open: false,
                screenName: "DP-1"
            }
        ];
        const openSecond = SuperStartLogic.pickStartMenuToggle(menus, "DP-1");
        compare(openSecond.action, "open");
        compare(openSecond.index, 1);

        const openFallback = SuperStartLogic.pickStartMenuToggle(menus, "HDMI-A-1");
        compare(openFallback.action, "open");
        compare(openFallback.index, 0);

        const closeOther = SuperStartLogic.pickStartMenuToggle([
            {
                open: true,
                screenName: "eDP-1"
            },
            {
                open: false,
                screenName: "DP-1"
            }
        ], "DP-1");
        compare(closeOther.action, "close");
        compare(closeOther.indices, [0]);

        const empty = SuperStartLogic.pickStartMenuToggle([], "DP-1");
        compare(empty.action, "none");
        compare(empty.index, -1);
    }

    name: "SuperStartLogic"
}

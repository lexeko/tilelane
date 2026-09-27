import QtQuick
import QtTest
import "../../qml/PanelRouting.js" as PanelRouting

TestCase {
    name: "PanelRouting"

    function test_closedPanelsUseFocusedOutput() {
        const rows = [
            {
                host: "first",
                screenName: "DP-1",
                opened: false
            },
            {
                host: "second",
                screenName: "DP-2",
                opened: false
            }
        ];
        compare(PanelRouting.pickHost(rows, "DP-2"), "second");
    }

    function test_toggleClosesExistingPanelOnAnotherOutput() {
        const rows = [
            {
                host: "first",
                screenName: "DP-1",
                opened: true
            },
            {
                host: "second",
                screenName: "DP-2",
                opened: false
            }
        ];
        compare(PanelRouting.pickHost(rows, "DP-2"), "first");
    }

    function test_primaryOnlyBarRemainsReachableFromOtherOutputs() {
        compare(PanelRouting.pickHost([
            {
                host: "primary",
                screenName: "DP-1",
                opened: false
            }
        ], "DP-2"), "primary");
        compare(PanelRouting.pickHost([], "DP-2"), null);
    }

    function test_numberedShortcutsFollowVisibleOrder() {
        const rows = [
            {
                host: {
                    moduleName: "clock"
                },
                screenName: "DP-1",
                visible: true,
                x: 900
            },
            {
                host: {
                    moduleName: "power"
                },
                screenName: "DP-1",
                visible: false,
                x: 850
            },
            {
                host: {
                    moduleName: "audio"
                },
                screenName: "DP-1",
                visible: true,
                x: 800
            }
        ];
        compare(PanelRouting.panelIdAt(rows, 1, "DP-1"), "audio");
        compare(PanelRouting.panelIdAt(rows, 2, "DP-2"), "clock");
        compare(PanelRouting.panelIdAt(rows, 3, "DP-1"), "");
        compare(PanelRouting.panelIdAt(rows, 0, "DP-1"), "");
    }
}

import "../../qml/TipLogic.js" as TipLogic
import QtQuick
import QtTest

TestCase {
    function test_onlyCurrentTipIsDismissed() {
        const tips = [
            {
                "id": "dock-overlap",
                "eligible": true
            },
            {
                "id": "future-change",
                "eligible": true
            }
        ];
        compare(TipLogic.select(tips, [], []).id, "dock-overlap");
        compare(TipLogic.select(tips, ["dock-overlap"], []).id, "future-change");
        compare(TipLogic.select(tips, [], ["dock-overlap"]).id, "future-change");
        compare(TipLogic.select(tips, ["dock-overlap", "future-change"], []), null);
    }

    function test_dockNeedsVisibleBottomConflict() {
        const state = {
            "dockEnabled": true,
            "dockPosition": "bottom",
            "dockAutohide": false,
            "barPosition": "bottom",
            "workspaceMode": "floating",
            "fullscreenMode": 0,
            "screenName": "HDMI-A-2"
        };
        verify(TipLogic.dockOverlap(state));
        for (const changed of [
            {
                "dockEnabled": false
            },
            {
                "dockPosition": "left"
            },
            {
                "dockAutohide": true
            },
            {
                "barPosition": "top"
            },
            {
                "workspaceMode": "dwindle"
            },
            {
                "workspaceMode": ""
            },
            {
                "fullscreenMode": 1
            },
            {
                "fullscreenMode": 2
            },
            {
                "screenName": ""
            }
        ]) {
            const candidate = Object.assign({}, state, changed);
            verify(!TipLogic.dockOverlap(candidate), JSON.stringify(changed));
        }
    }

    function test_dockChoicesUseSequentialValidatedCommands() {
        for (const position of ["left", "top", "right"]) {
            const commands = TipLogic.dockActionCommands(position);
            compare(JSON.stringify(commands), JSON.stringify([["omarchy", "dock", "position", position], ["omarchy", "dock", "autohide", "on"]]));
        }
        compare(TipLogic.dockActionCommands("bottom").length, 0);
        compare(TipLogic.dockActionCommands("left; false").length, 0);
    }

    name: "TipLogic"
}

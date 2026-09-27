import QtQuick
import QtTest
import "../../qml/StatusLogic.js" as StatusLogic

TestCase {
    name: "StatusLogic"

    function test_fractionClampsInvalidAndOutOfRangeValues() {
        compare(StatusLogic.clampFraction(-1), 0);
        compare(StatusLogic.clampFraction(2), 1);
        compare(StatusLogic.clampFraction("bad"), 0);
        compare(StatusLogic.clampFraction(0.42), 0.42);
    }

    function test_wifiStrengthUsesStableFiveStepRing() {
        compare(StatusLogic.wifiIcon(false, 1), "󰤮");
        compare(StatusLogic.wifiIcon(true, 0), "󰤯");
        compare(StatusLogic.wifiIcon(true, 0.41), "󰤢");
        compare(StatusLogic.wifiIcon(true, 1), "󰤨");
    }

    function test_batteryIconSeparatesChargingAndThresholdStates() {
        compare(StatusLogic.batteryIcon(false, 0.5, false, false, false), "");
        compare(StatusLogic.batteryIcon(true, 0.5, false, false, false), "󰁿");
        compare(StatusLogic.batteryIcon(true, 0.5, true, false, false), "󰂉");
        compare(StatusLogic.batteryIcon(true, 0.5, true, false, true), "󰁿");
        compare(StatusLogic.batteryIcon(true, 1, true, true, false), "󰂅");
    }

    function test_trayFilterPreservesSourceOrder() {
        const first = {
            "id": "first",
            "status": 1
        };
        const passive = {
            "id": "passive",
            "status": 0
        };
        const last = {
            "id": "last",
            "status": 2
        };
        const result = StatusLogic.activeTrayItems([first, null, passive, last], 0);
        compare(result.length, 2);
        compare(result[0].id, "first");
        compare(result[1].id, "last");
    }

    function test_trayFilterExcludesNativeOwnedItems() {
        const result = StatusLogic.activeTrayItems([
            {
                "id": "dropbox-client-123",
                "status": 1
            },
            {
                "id": "chat",
                "title": "Chat",
                "status": 1
            }
        ], 0, ["dropbox"]);
        compare(result.length, 1);
        compare(result[0].id, "chat");
    }
}

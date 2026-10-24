import QtQuick
import QtTest
import "../../qml/models"

TestCase {
    id: testCase
    name: "TipController"

    QtObject {
        id: fakeSettings
        property var values: ({
                tilelaneDismissedTips: []
            })
        property bool allowSave: true
        property int saveCount: 0

        function setValue(key, value) {
            testCase.compare(key, "tilelaneDismissedTips");
            saveCount++;
            if (!allowSave)
                return false;
            values = ({
                    tilelaneDismissedTips: value
                });
            return true;
        }
    }

    TipController {
        id: controller
        settings: fakeSettings
    }

    function init() {
        fakeSettings.values = ({
                tilelaneDismissedTips: []
            });
        fakeSettings.allowSave = true;
        fakeSettings.saveCount = 0;
        controller.hiddenThisSession = [];
        controller.actionPending = false;
        controller.actionFailed = false;
        controller.stableDockConflict = false;
        controller.errorKey = "";
        controller.pendingCommands = [];
        controller.commandIndex = 0;
    }

    function finishSecondDockCommand(exitCode) {
        controller.pendingCommands = [["position"], ["autohide"]];
        controller.commandIndex = 1;
        controller.actionPending = true;
        controller.dockAction.exited(exitCode);
    }

    function test_successfulChoicePersistsDismissal() {
        controller.stableDockConflict = true;
        compare(controller.currentTip.id, "dock-overlap");
        finishSecondDockCommand(0);
        compare(fakeSettings.values.tilelaneDismissedTips, ["dock-overlap"]);
        compare(fakeSettings.saveCount, 1);
        compare(controller.hiddenThisSession, []);
        verify(!controller.actionPending);
        verify(!controller.actionFailed);
        compare(controller.currentTip, null);
        fakeSettings.values = ({
                tilelaneDismissedTips: []
            });
        compare(controller.currentTip.id, "dock-overlap");
    }

    function test_explicitDismissalCanBeResetDuringSession() {
        controller.stableDockConflict = true;
        verify(controller.dismiss("dock-overlap"));
        compare(controller.currentTip, null);
        fakeSettings.values = ({
                tilelaneDismissedTips: []
            });
        compare(controller.currentTip.id, "dock-overlap");
    }

    function test_laterRemainsHiddenForSession() {
        controller.stableDockConflict = true;
        controller.later("dock-overlap");
        compare(controller.currentTip, null);
        fakeSettings.values = ({
                tilelaneDismissedTips: ["dock-overlap"]
            });
        fakeSettings.values = ({
                tilelaneDismissedTips: []
            });
        compare(controller.currentTip, null);
    }

    function test_commandFailureKeepsTipAvailable() {
        finishSecondDockCommand(1);
        compare(fakeSettings.values.tilelaneDismissedTips, []);
        compare(fakeSettings.saveCount, 0);
        verify(controller.actionFailed);
        compare(controller.currentTip.id, "dock-overlap");
    }

    function test_saveFailureKeepsTipAvailable() {
        fakeSettings.allowSave = false;
        finishSecondDockCommand(0);
        compare(fakeSettings.values.tilelaneDismissedTips, []);
        compare(fakeSettings.saveCount, 1);
        verify(controller.actionFailed);
        compare(controller.errorKey, "tips.saveError");
        compare(controller.currentTip.id, "dock-overlap");
    }
}

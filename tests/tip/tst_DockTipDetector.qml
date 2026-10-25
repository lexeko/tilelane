import QtQuick
import QtTest
import Quickshell.Hyprland
import "../../qml/models"

TestCase {
    id: testCase
    name: "DockTipDetector"

    Component {
        id: detectorComponent
        DockTipDetector {}
    }

    function test_onlyPossibleOverlapRequestsWorkspaceMode() {
        Hyprland.focusedMonitor = {
            name: "TEST",
            activeWorkspace: {
                id: 2
            }
        };
        const detector = createTemporaryObject(detectorComponent, testCase, {
            capabilities: {
                workspaceLayout: true
            },
            shellConfig: {
                dock: {
                    position: "bottom",
                    autohide: false
                }
            }
        });
        verify(!detector.modeMonitor.active);
        detector.dockEnabled = true;
        verify(detector.modeMonitor.active);
        detector.shellConfig = {
            dock: {
                position: "left",
                autohide: false
            }
        };
        verify(!detector.modeMonitor.active);
        detector.shellConfig = {
            dock: {
                position: "bottom",
                autohide: true
            }
        };
        verify(!detector.modeMonitor.active);
        detector.shellConfig = {
            dock: {
                position: "bottom",
                autohide: false
            }
        };
        verify(detector.modeMonitor.active);
        Hyprland.toplevels = {
            values: [
                {
                    workspace: {
                        id: 2
                    },
                    lastIpcObject: {
                        fullscreen: 2
                    }
                }
            ]
        };
        verify(!detector.modeMonitor.active);
        Hyprland.toplevels = {
            values: []
        };
        verify(detector.modeMonitor.active);
        detector.capabilities = {
            workspaceLayout: false
        };
        verify(!detector.modeMonitor.active);
        verify(!detector.modeMonitor.retry.running);
        Hyprland.focusedMonitor = null;
    }
}

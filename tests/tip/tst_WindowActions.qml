import QtQuick
import QtTest
import Quickshell
import Quickshell.Hyprland
import "../../qml/models"

TestCase {
    id: testCase
    name: "WindowActionsCompatibility"

    QtObject {
        id: model
        property bool initialized: true
        property int revision: 0
        property var record: ({})
        property var source: ({})
        function recordFor(address) {
            return address === "0x123" ? record : null;
        }
        function toplevelFor(address) {
            return address === "0x123" ? source : null;
        }
    }

    Component {
        id: actionsComponent
        WindowActions {
            windowModel: model
        }
    }

    function init() {
        Quickshell.detachedCommands = [];
        Hyprland.dispatches = [];
        Hyprland.monitors = {
            values: [
                {
                    activeWorkspace: {
                        id: 2
                    }
                }
            ]
        };
        model.record = {
            workspaceName: "2",
            workspaceId: 2,
            minimized: false,
            omarchyFloatingWorkspace: true
        };
        model.source = {
            wayland: {
                appId: "test",
                parent: null
            },
            lastIpcObject: {
                tags: []
            }
        };
    }

    function test_nativeMinimizeRequiresAvailableHelper_data() {
        return [
            {
                tag: "older-host",
                native: false
            },
            {
                tag: "rc-host",
                native: true
            }
        ];
    }

    function test_nativeMinimizeRequiresAvailableHelper(data) {
        const actions = createTemporaryObject(actionsComponent, testCase, {
            capabilities: {
                workspaceLayout: data.native,
                nativeMinimize: data.native
            }
        });
        verify(actions.invoke("0x123", "minimize"));
        const commands = Quickshell.detachedCommands;
        compare(commands.length, 1);
        if (data.native) {
            compare(commands[0], ["omarchy-hyprland-window-minimize", "0x123"]);
            compare(actions.fallbackOrigins["0x123"], undefined);
        } else {
            compare(commands[0][0], "hyprctl");
            verify(commands[0][2].indexOf("special:tilelane-minimized") !== -1);
            compare(actions.fallbackOrigins["0x123"], "2");
        }
        actions.fallbackOrigins = ({});
    }

    function test_modeChangeMigratesOnlyOnSupportedHost_data() {
        return [
            {
                tag: "older-host",
                supported: false
            },
            {
                tag: "rc-host",
                supported: true
            }
        ];
    }

    function test_modeChangeMigratesOnlyOnSupportedHost(data) {
        model.record = {
            workspaceName: "special:tilelane-minimized",
            workspaceId: -1,
            minimized: true
        };
        const actions = createTemporaryObject(actionsComponent, testCase, {
            capabilities: {
                workspaceLayout: data.supported,
                nativeMinimize: data.supported
            }
        });
        actions.fallbackOrigins = {
            "0x123": "2"
        };
        const monitor = actions.modeMonitor;
        compare(monitor.active, data.supported);
        if (data.supported) {
            tryCompare(monitor.modeProbe, "running", true);
            monitor.modeProbe.stdout.text = "floating\n";
            monitor.modeProbe.stdout.streamFinished();
            // A candidate update can invalidate an in-flight probe.
            if (Hyprland.dispatches.length === 0) {
                monitor.modeProbe.running = false;
                monitor.modeProbe.exited(0);
                tryCompare(monitor.modeProbe, "running", true);
                monitor.modeProbe.stdout.streamFinished();
            }
            compare(Hyprland.dispatches.length, 1);
            verify(Hyprland.dispatches[0].indexOf("+omarchy-minimized-from-2") !== -1);
            verify(Hyprland.dispatches[0].indexOf('workspace = "special:minimized"') !== -1);
            compare(actions.fallbackOrigins["0x123"], "2");
        } else {
            verify(!monitor.modeProbe.running);
            verify(!monitor.retry.running);
            compare(Hyprland.dispatches.length, 0);
        }
        actions.fallbackOrigins = ({});
    }
}

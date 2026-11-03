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
        Hyprland.dispatchFails = false;
        model.initialized = true;
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

    function test_savedOriginsDiscardRestoredAndClosedWindows_data() {
        return [
            {
                tag: "restored",
                record: {
                    workspaceName: "7",
                    workspaceId: 7,
                    minimized: false
                }
            },
            {
                tag: "closed",
                record: null
            }
        ];
    }

    function test_savedOriginsDiscardRestoredAndClosedWindows(data) {
        model.record = data.record;
        const actions = createTemporaryObject(actionsComponent, testCase);
        actions.loadOrigins('{"version":1,"origins":{"0x123":"2"}}');
        compare(actions.fallbackOrigins["0x123"], undefined);
        actions.restoreOwnedWindows();
        compare(Quickshell.detachedCommands.length, 0);
        // Reusing a closed window's address must not inherit its old origin.
        model.record = {
            workspaceName: "7",
            workspaceId: 7,
            minimized: false
        };
        model.revision++;
        actions.restoreOwnedWindows();
        compare(Quickshell.detachedCommands.length, 0);
    }

    function test_savedHiddenOriginsWaitForModelInitialization_data() {
        return [
            {
                tag: "tilelane",
                workspace: "special:tilelane-minimized"
            },
            {
                tag: "dock",
                workspace: "special:minimized"
            }
        ];
    }

    function test_savedHiddenOriginsWaitForModelInitialization(data) {
        model.initialized = false;
        model.record = null;
        const actions = createTemporaryObject(actionsComponent, testCase);
        actions.loadOrigins('{"version":1,"origins":{"0x123":"2"}}');
        compare(actions.fallbackOrigins["0x123"], "2");
        model.record = {
            workspaceName: data.workspace,
            minimized: true
        };
        model.initialized = true;
        compare(actions.fallbackOrigins["0x123"], "2");
        compare(actions.observedOrigins["0x123"], true);
        model.record = {
            workspaceName: "7",
            minimized: false
        };
        model.revision++;
        compare(actions.fallbackOrigins["0x123"], undefined);
    }

    function test_savedOriginWaitsForWorkspaceDetails() {
        model.record = {
            workspaceName: "",
            minimized: false
        };
        const actions = createTemporaryObject(actionsComponent, testCase);
        actions.loadOrigins('{"version":1,"origins":{"0x123":"2"}}');
        compare(actions.fallbackOrigins["0x123"], "2");
        model.record = {
            workspaceName: "special:tilelane-minimized",
            minimized: true
        };
        model.revision++;
        compare(actions.fallbackOrigins["0x123"], "2");
        compare(actions.observedOrigins["0x123"], true);
        actions.fallbackOrigins = ({});
    }

    function test_currentMinimizeSurvivesJournalReadAndOrdinaryUpdates() {
        const actions = createTemporaryObject(actionsComponent, testCase);
        verify(actions.rememberOrigin("0x123", "3"));
        actions.loadOrigins('{"version":1,"origins":{"0x123":"2"}}');
        model.revision++;
        compare(actions.fallbackOrigins["0x123"], "3");
        compare(actions.observedOrigins["0x123"], false);
        model.record = {
            workspaceName: "special:tilelane-minimized",
            minimized: true
        };
        model.revision++;
        compare(actions.observedOrigins["0x123"], true);
        model.record = {
            workspaceName: "3",
            minimized: false
        };
        model.revision++;
        compare(actions.fallbackOrigins["0x123"], undefined);
    }

    function test_closedPendingMinimizeLosesItsOrigin() {
        const actions = createTemporaryObject(actionsComponent, testCase);
        actions.loadOrigins("");
        verify(actions.rememberOrigin("0x123", "2"));
        model.record = null;
        model.revision++;
        compare(actions.fallbackOrigins["0x123"], undefined);
    }

    function test_unloadRestoresOnlyOwnedHiddenWindows_data() {
        return [
            {
                tag: "normal",
                workspace: "7",
                minimized: false,
                expected: 0
            },
            {
                tag: "other-special",
                workspace: "special:scratchpad",
                minimized: false,
                expected: 0
            },
            {
                tag: "native-flag-only",
                workspace: "7",
                minimized: true,
                expected: 0
            },
            {
                tag: "tilelane",
                workspace: "special:tilelane-minimized",
                minimized: true,
                expected: 1
            },
            {
                tag: "dock",
                workspace: "special:minimized",
                minimized: true,
                expected: 1
            }
        ];
    }

    function test_unloadRestoresOnlyOwnedHiddenWindows(data) {
        model.record = {
            workspaceName: data.workspace,
            minimized: data.minimized
        };
        const actions = createTemporaryObject(actionsComponent, testCase);
        // Exercise the unload guard independently of startup reconciliation.
        actions.fallbackOrigins = {
            "0x123": "2"
        };
        actions.restoreOwnedWindows();
        const commands = Quickshell.detachedCommands;
        compare(commands.length, data.expected);
        if (commands.length) {
            verify(commands[0][2].indexOf('workspace = "2"') !== -1);
            verify(commands[0][2].indexOf('hl.get_window') !== -1);
            verify(commands[0][2].indexOf('hl.dsp.focus') === -1);
            verify(commands[0][2].indexOf('alter_zorder') === -1);
        }
    }

    function test_restoreDispatchFailureStillActivatesTheWindow() {
        model.record = {
            workspaceName: "special:tilelane-minimized",
            minimized: true
        };
        const actions = createTemporaryObject(actionsComponent, testCase);
        actions.loadOrigins('{"version":1,"origins":{"0x123":"2"}}');
        Hyprland.dispatchFails = true;
        verify(actions.invoke("0x123", "restore"));
        compare(Quickshell.detachedCommands.length, 1);
        const code = Quickshell.detachedCommands[0][2];
        verify(code.indexOf('hl.dsp.focus({ workspace = "2" })') !== -1);
        verify(code.indexOf('hl.dsp.focus({ window = "address:0x123" })') !== -1);
        verify(code.indexOf('cursor.no_warps') !== -1);
        actions.fallbackOrigins = ({});
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
        if (data.native) {
            compare(commands.length, 0);
            compare(Hyprland.dispatches.length, 1);
            verify(Hyprland.dispatches[0].indexOf('cursor.no_warps') !== -1);
            verify(Hyprland.dispatches[0].indexOf('workspace = "special:minimized"') !== -1);
            verify(Hyprland.dispatches[0].indexOf('hl.dsp.focus({ workspace = "2" })') !== -1);
            compare(actions.fallbackOrigins["0x123"], undefined);
        } else {
            compare(commands.length, 1);
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

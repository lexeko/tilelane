import "../../qml/TaskLogic.js" as TaskLogic
import QtQuick
import QtTest

TestCase {
    function test_primaryActionUsesConfirmedState() {
        compare(TaskLogic.primaryAction(false, false), "activate");
        compare(TaskLogic.primaryAction(true, false), "minimize");
        compare(TaskLogic.primaryAction(false, true), "restore");
        compare(TaskLogic.primaryAction(true, true), "restore");
    }

    function test_titleFallbackIsAlwaysAccessible() {
        compare(TaskLogic.displayTitle("Document", "editor"), "Document");
        compare(TaskLogic.displayTitle("", "editor"), "editor");
        compare(TaskLogic.displayTitle("", ""), "Application");
    }

    function test_visualPriorityIsDeterministic() {
        compare(TaskLogic.visualState(false, false, false, false, false, false, false), "idle");
        compare(TaskLogic.visualState(false, false, false, false, false, true, true), "active");
        compare(TaskLogic.visualState(false, false, false, false, true, true, false), "urgent");
        compare(TaskLogic.visualState(false, false, true, true, true, true, false), "hovered");
        compare(TaskLogic.visualState(false, true, true, true, true, true, false), "focused");
        compare(TaskLogic.visualState(true, true, true, true, true, true, false), "pressed");
    }

    function test_fallbackCommandsValidateAndEscapeInputs() {
        compare(TaskLogic.fallbackCode("activate", "not-an-address", ""), "");
        compare(TaskLogic.fallbackCode("activate", "0x123456789abcdef01", ""), "");
        verify(TaskLogic.fallbackCode("activate", "0xabc", "").indexOf('hl.dsp.window.alter_zorder({ mode = "top", window = "address:0xabc" })') !== -1);
        compare(TaskLogic.fallbackCode("close", "0xabc", ""), "return hl.dispatch(hl.dsp.window.close({ window = \"address:0xabc\" }))");
        const minimized = TaskLogic.fallbackCode("minimize", "0xABC", "");
        verify(minimized.indexOf("special:tilelane-minimized") !== -1);
        verify(minimized.indexOf("address:0xABC") !== -1);
        const restored = TaskLogic.fallbackCode("restore", "0xabc", "name:work\\\"room");
        verify(restored.indexOf("name:work\\\\\\\"room") !== -1);
        compare(TaskLogic.fallbackCode("restore", "0xabc", ""), "");
        compare(TaskLogic.fallbackCode("maximize", "0xabc", ""), "return hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", window = \"address:0xabc\" }))");
        compare(TaskLogic.fallbackCode("float", "0xabc", ""), "return hl.dispatch(hl.dsp.window.float({ action = \"toggle\", window = \"address:0xabc\" }))");
    }

    function test_activationTargetsWorkspaceThenExactWindow() {
        const commands = TaskLogic.activationDispatches("0xABC", "name:work\"room");
        compare(commands.length, 4);
        compare(commands[0], "hl.dsp.focus({ workspace = \"name:work\\\"room\" })");
        compare(commands[1], "hl.dsp.focus({ window = \"address:0xABC\" })");
        compare(commands[2], TaskLogic.guardedRaiseDispatch("address:0xABC"));
        compare(commands[3], commands[1]);
        const minimized = TaskLogic.activationDispatches("0xabc", TaskLogic.minimizedWorkspace);
        compare(minimized.length, 3);
        verify(minimized[0].indexOf("address:0xabc") !== -1);
        compare(TaskLogic.activationDispatches("not-an-address", "2").length, 0);
    }

    function test_restoreTargetsWindowWithoutChangingLayout() {
        const commands = TaskLogic.restoreDispatches("0xABC", "name:work\"room");
        compare(commands.length, 5);
        verify(commands[0].indexOf("follow = false") !== -1);
        verify(commands[0].indexOf("name:work\\\"room") !== -1);
        compare(commands[1], "hl.dsp.focus({ workspace = \"name:work\\\"room\" })");
        compare(commands[2], "hl.dsp.focus({ window = \"address:0xABC\" })");
        compare(commands[3], TaskLogic.guardedRaiseDispatch("address:0xABC"));
        compare(commands[4], commands[2]);
        verify(commands.join(" ").indexOf("hl.dsp.layout") === -1);
        compare(TaskLogic.restoreDispatches("bad", "2").length, 0);
        compare(TaskLogic.restoreDispatches("0xabc", TaskLogic.minimizedWorkspace).length, 0);
    }

    function test_omarchyRestoreUsesTheTaskMonitorActiveWorkspace() {
        const monitors = [
            {
                name: "DP-1",
                activeWorkspace: {
                    id: 2
                }
            },
            {
                name: "HDMI-A-1",
                activeWorkspace: {
                    id: 4
                }
            }
        ];
        compare(TaskLogic.restoreWorkspaceForMonitor("DP-1", monitors, monitors[1]), "2");
        compare(TaskLogic.restoreWorkspaceForMonitor("missing", monitors, monitors[1]), "4");
        compare(TaskLogic.restoreWorkspaceForMonitor("DP-1", [
            {
                name: "DP-1",
                activeWorkspace: {
                    id: -99
                }
            }
        ], monitors[1]), "4");
        compare(TaskLogic.restoreWorkspaceForMonitor("", [], {
            activeWorkspace: {
                id: -99
            }
        }), "");
        compare(TaskLogic.restoreWorkspaceForMonitor("", [], {
            activeWorkspace: {
                id: 2147483648
            }
        }), "");
    }

    function test_dockMinimizeRequiresFloatingWorkspaceAndDockVisibleWindow() {
        const record = {
            omarchyFloatingWorkspace: true,
            workspaceId: 2
        };
        const wayland = {
            appId: "org.example.Editor",
            parent: null
        };
        verify(TaskLogic.canMinimizeToOmarchyDock(record, wayland));
        verify(!TaskLogic.canMinimizeToOmarchyDock({
            omarchyFloatingWorkspace: false,
            workspaceId: 2
        }, wayland));
        verify(!TaskLogic.canMinimizeToOmarchyDock({
            omarchyFloatingWorkspace: true,
            workspaceId: -98
        }, wayland));
        verify(!TaskLogic.canMinimizeToOmarchyDock(record, null));
        verify(!TaskLogic.canMinimizeToOmarchyDock(record, {
            appId: "",
            parent: null
        }));
        verify(!TaskLogic.canMinimizeToOmarchyDock(record, {
            appId: "org.example.Dialog",
            parent: {}
        }));
    }

    function test_dockMigrationGuardsTheHiddenWindowAndUpdatesItsOriginTag() {
        const code = TaskLogic.dockMigrationCode("0xabc", 3, ["omarchy-minimized-from-2", "other"]);
        verify(code.indexOf('hl.get_window("address:0xabc")') !== -1);
        verify(code.indexOf('window.workspace.name ~= "special:tilelane-minimized"') !== -1);
        verify(code.indexOf('"-omarchy-minimized-from-2"') !== -1);
        verify(code.indexOf('"+omarchy-minimized-from-3"') !== -1);
        verify(code.indexOf('workspace = "special:minimized"') !== -1);
        verify(code.indexOf('hl.dsp.focus({ workspace = focus })') !== -1);
        compare(TaskLogic.dockMigrationCode("bad", 3, []), "");
        compare(TaskLogic.dockMigrationCode("0xabc", 0, []), "");
        compare(TaskLogic.dockMigrationCode("0xabc", "name:work", []), "");
    }

    function test_originJournalIsVersionedAndSanitized() {
        const parsed = TaskLogic.parseOrigins(JSON.stringify({
            "version": 1,
            "origins": {
                "0xABC": "2",
                "0xdef": "name:work",
                "bad": "3",
                "0x123": "special:tilelane-minimized",
                "0x456": 7
            }
        }));
        compare(Object.keys(parsed).length, 2);
        compare(parsed["0xabc"], "2");
        compare(parsed["0xdef"], "name:work");
        compare(Object.keys(TaskLogic.parseOrigins("not json")).length, 0);
        compare(Object.keys(TaskLogic.parseOrigins('{"version":2,"origins":{"0x1":"2"}}')).length, 0);
        const serialized = TaskLogic.serializeOrigins({
            "0xABC": "2",
            "invalid": "3"
        });
        const roundTrip = JSON.parse(serialized);
        compare(roundTrip.version, 1);
        compare(Object.keys(roundTrip.origins).length, 1);
        compare(roundTrip.origins["0xabc"], "2");
    }

    name: "TaskLogic"
}

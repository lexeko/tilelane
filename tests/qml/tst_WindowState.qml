import QtQuick
import QtTest
import "../../qml/models/WindowState.js" as WindowState
import "../fixtures/WindowFixtures.js" as Fixtures

TestCase {
    name: "WindowState"

    function test_identityPrecedenceNormalizesNativeAndXWayland() {
        const native = WindowState.normalizeRecord(Fixtures.clone(Fixtures.nativeWindow));
        const legacy = WindowState.normalizeRecord(Fixtures.clone(Fixtures.xwaylandWindow));
        compare(native.appId, "org.example.Editor.desktop");
        compare(legacy.appId, "Legacy.App");
        verify(legacy.xwayland);
        const bareAddress = Fixtures.clone(Fixtures.nativeWindow);
        bareAddress.address = "ABC123";
        compare(WindowState.normalizeRecord(bareAddress).address, "0xabc123");
        bareAddress.terminalPrograms = ["cliamp", "cliamp", "bash"];
        compare(WindowState.normalizeRecord(bareAddress).terminalPrograms, "[\"cliamp\",\"bash\"]");
    }

    function test_terminalProbeSeparatesHostMarkerAndPrograms() {
        const pending = WindowState.parseTerminalProbe("__tilelane_terminal_host__\n");
        verify(pending.ownsTerminal);
        compare(pending.programs.length, 0);

        const ready = WindowState.parseTerminalProbe("__tilelane_terminal_host__\ncliamp\ncliamp\n");
        verify(ready.ownsTerminal);
        compare(ready.programs.length, 1);
        compare(ready.programs[0], "cliamp");

        const graphical = WindowState.parseTerminalProbe("");
        verify(!graphical.ownsTerminal);
        compare(graphical.programs.length, 0);
    }

    function test_creationOrderUsesCompositorHexCounter() {
        compare(WindowState.creationOrder("18000008"), 0x18000008);
        compare(WindowState.creationOrder("1800003a"), 0x1800003a);
        compare(WindowState.creationOrder("0x1800003A"), 0x1800003a);
        compare(WindowState.creationOrder(0x1800003a), 0x1800003a);
        verify(WindowState.creationOrder("18000008") < WindowState.creationOrder("1800003a"));
        for (const invalid of [undefined, null, "", "not-an-id", "12oops", "0", -1, 1.5, "ffffffffffffffff"])
            compare(WindowState.creationOrder(invalid), 0);
    }

    function test_openingOrderSurvivesReloadAndLateWindowDetails() {
        function rebuild(snapshot) {
            let state = {
                records: [],
                nextOrder: 1
            };
            for (const window of snapshot)
                state = WindowState.applyEvent(state.records, Object.assign({
                    type: "upsert"
                }, window), state.nextOrder);
            return state;
        }
        function orderedAddresses(state) {
            return state.records.slice().sort((a, b) => a.orderKey - b.orderKey).map(record => record.address).join(",");
        }
        // Same-process windows, delivered in focus/enumeration order.
        const snapshot = [
            {
                address: "0xc",
                stableId: "18000030",
                pid: 42,
                active: true
            },
            {
                address: "0xa",
                stableId: "18000010",
                pid: 42
            },
            {
                address: "0xb",
                stableId: "18000020",
                pid: 42
            }
        ];
        let state = rebuild(snapshot);
        compare(orderedAddresses(state), "0xa,0xb,0xc");
        compare(orderedAddresses(rebuild(snapshot.slice().reverse())), "0xa,0xb,0xc");
        state = WindowState.applyEvent(state.records, {
            type: "upsert",
            address: "0xd"
        }, state.nextOrder);
        compare(orderedAddresses(state), "0xa,0xb,0xc,0xd");
        state = WindowState.applyEvent(state.records, {
            type: "upsert",
            address: "0xd",
            stableId: "18000040"
        }, state.nextOrder);
        for (const change of [
            {
                minimized: true
            },
            {
                minimized: false,
                active: true
            },
            {
                maximized: true
            },
            {
                maximized: false
            }
        ]) {
            state = WindowState.applyEvent(state.records, Object.assign({
                type: "upsert",
                address: "0xb",
                stableId: "18000020"
            }, change), state.nextOrder);
            compare(orderedAddresses(state), "0xa,0xb,0xc,0xd");
        }
    }

    function test_retitleDoesNotReorder() {
        let state = WindowState.applyEvent([], Object.assign({
            type: "upsert"
        }, Fixtures.clone(Fixtures.nativeWindow)), 1);
        state = WindowState.applyEvent(state.records, Object.assign({
            type: "upsert"
        }, Fixtures.clone(Fixtures.xwaylandWindow)), state.nextOrder);
        const changed = Fixtures.clone(Fixtures.nativeWindow);
        changed.type = "upsert";
        changed.title = "A title that sorts first";
        state = WindowState.applyEvent(state.records, changed, state.nextOrder);
        compare(state.records[0].address, "0xaaa");
        compare(state.records[0].orderKey, 1);
        compare(state.records[1].address, "0xbbb");
        compare(state.records[1].orderKey, 2);
    }

    function test_terminalStartupRetriesPastShellAndLauncherProcesses() {
        const starting = WindowState.parseTerminalProbe("");
        verify(WindowState.retryTerminalProbe(starting, 1, 4));
        verify(!WindowState.retryTerminalProbe(starting, 2, 4));
        const wrapper = WindowState.parseTerminalProbe("__tilelane_terminal_host__\nsh\nsleep\n");
        verify(WindowState.retryTerminalProbe(wrapper, 1, 4));
        verify(WindowState.retryTerminalProbe(wrapper, 3, 4));
        verify(!WindowState.retryTerminalProbe(wrapper, 4, 4));
        const ready = WindowState.parseTerminalProbe("__tilelane_terminal_host__\ncliamp\n");
        verify(!WindowState.retryTerminalProbe(ready, 4, 4));
    }

    function test_liveRoleChangesAreIdempotentAndKeepOrder() {
        const initial = Object.assign({
            type: "upsert"
        }, Fixtures.clone(Fixtures.nativeWindow));
        let state = WindowState.applyEvent([], initial, 1);
        const originalOrder = state.records[0].orderKey;
        const changed = Fixtures.clone(Fixtures.nativeWindow);
        changed.type = "upsert";
        changed.title = "Renamed while running";
        changed.active = false;
        changed.urgent = true;
        changed.workspaceId = 7;
        changed.workspaceName = "7";
        changed.monitorId = 2;
        changed.monitorName = "DP-3";
        state = WindowState.applyEvent(state.records, changed, state.nextOrder);
        compare(state.records.length, 1);
        compare(state.records[0].title, "Renamed while running");
        verify(!state.records[0].active);
        verify(state.records[0].urgent);
        compare(state.records[0].workspaceName, "7");
        compare(state.records[0].monitorName, "DP-3");
        compare(state.records[0].orderKey, originalOrder);

        const identical = WindowState.normalizeRecord(changed);
        identical.orderKey = originalOrder;
        verify(WindowState.sameRecord(state.records[0], identical));
        state = WindowState.applyEvent(state.records, changed, state.nextOrder);
        verify(WindowState.sameRecord(state.records[0], identical));
        compare(state.records[0].orderKey, originalOrder);
    }

    function test_outOfOrderCloseCannotRemoveReplacement() {
        const first = Object.assign({
            type: "upsert"
        }, Fixtures.clone(Fixtures.nativeWindow));
        let state = WindowState.applyEvent([], first, 1);
        const replacement = Fixtures.clone(Fixtures.nativeWindow);
        replacement.type = "upsert";
        replacement.generation = 9;
        replacement.title = "Replacement";
        state = WindowState.applyEvent(state.records, replacement, state.nextOrder);
        state = WindowState.applyEvent(state.records, {
            type: "close",
            address: "0xaaa",
            generation: 1
        }, state.nextOrder);
        compare(state.records.length, 1);
        compare(state.records[0].title, "Replacement");
        compare(state.records[0].generation, 9);
        state = WindowState.applyEvent(state.records, {
            type: "close",
            address: "0xaaa",
            generation: 9
        }, state.nextOrder);
        compare(state.records.length, 0);
    }

    function test_monitorAndWorkspaceFiltering() {
        const first = WindowState.normalizeRecord(Fixtures.clone(Fixtures.nativeWindow));
        const second = WindowState.normalizeRecord(Fixtures.clone(Fixtures.xwaylandWindow));
        let visible = WindowState.filterRecords([first, second], "DP-1", "all", "");
        compare(visible.length, 1);
        compare(visible[0].address, "0xaaa");
        visible = WindowState.filterRecords([first, second], "DP-1", "active", "1");
        compare(visible.length, 0);
        const minimized = Fixtures.clone(Fixtures.nativeWindow);
        minimized.workspaceName = WindowState.minimizedWorkspace;
        minimized.minimized = true;
        visible = WindowState.filterRecords([WindowState.normalizeRecord(minimized)], "DP-1", "active", "1");
        compare(visible.length, 1);
    }

    function test_hiddenAndUnmappedWindowsAreExcluded() {
        const hidden = Fixtures.clone(Fixtures.nativeWindow);
        hidden.hidden = true;
        const unmapped = Fixtures.clone(Fixtures.xwaylandWindow);
        unmapped.mapped = false;
        compare(WindowState.filterRecords([WindowState.normalizeRecord(hidden), WindowState.normalizeRecord(unmapped)], "", "all", "").length, 0);
    }
}

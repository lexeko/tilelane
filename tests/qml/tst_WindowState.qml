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

import QtQuick
import QtTest
import "../../qml/models"

TestCase {
    id: testCase
    name: "WorkspaceModeMonitor"

    Component {
        id: monitorComponent
        WorkspaceModeMonitor {}
    }

    function makeMonitor() {
        return createTemporaryObject(monitorComponent, testCase);
    }

    function finish(monitor, text) {
        monitor.modeProbe.stdout.text = text;
        monitor.modeProbe.stdout.streamFinished();
        monitor.modeProbe.running = false;
        monitor.modeProbe.exited(0);
    }

    function test_unavailableHostDoesNotProbeOrWatch() {
        const monitor = makeMonitor();
        monitor.workspaceIds = [2];
        monitor.refresh();
        monitor.directoryChanged();
        verify(!monitor.modeProbe.running);
        verify(!monitor.retry.running);
        compare(monitor.directoryWatch.path, "");
        compare(monitor.defaultFileWatch.path, "");
        compare(monitor.workspaceFileWatches.count, 0);
        compare(monitor.pendingIds.length, 0);
        compare(monitor.modeFor(2), "");
    }

    function test_supportedHostTracksModeChanges() {
        const monitor = makeMonitor();
        monitor.workspaceIds = [2];
        monitor.available = true;
        tryCompare(monitor.modeProbe, "running", true);
        compare(monitor.modeProbe.command, ["omarchy-hyprland-workspace-layout-current", "2"]);
        verify(monitor.retry.running);
        finish(monitor, "dwindle\n");
        compare(monitor.modeFor(2), "dwindle");
        monitor.refresh();
        tryCompare(monitor.modeProbe, "running", true);
        finish(monitor, "floating\n");
        compare(monitor.modeFor(2), "floating");
        verify(monitor.directoryWatch.watchChanges);
        compare(monitor.workspaceFileWatches.count, 1);
    }

    function test_deactivationRejectsInflightResultsAndStopsRetries() {
        const monitor = makeMonitor();
        monitor.available = true;
        monitor.workspaceIds = [2];
        tryCompare(monitor.modeProbe, "running", true);
        monitor.workspaceIds = [];
        finish(monitor, "floating\n");
        compare(monitor.modeFor(2), "");
        verify(!monitor.retry.running);
        compare(monitor.directoryWatch.path, "");
        compare(monitor.workspaceFileWatches.count, 0);
        compare(monitor.pendingIds.length, 0);
    }

    function test_workspaceChangeDiscardsOldResultAndQueriesNewWorkspace() {
        const monitor = makeMonitor();
        monitor.available = true;
        monitor.workspaceIds = [2];
        tryCompare(monitor.modeProbe, "running", true);
        monitor.workspaceIds = [3];
        finish(monitor, "floating\n");
        compare(monitor.modeFor(2), "");
        tryCompare(monitor.modeProbe, "running", true);
        compare(monitor.modeProbe.command[1], "3");
        finish(monitor, "dwindle\n");
        compare(monitor.modeFor(3), "dwindle");
    }
}

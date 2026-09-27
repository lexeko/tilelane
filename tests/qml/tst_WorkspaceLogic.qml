import QtQuick
import QtTest
import "../../qml/WorkspaceLogic.js" as WorkspaceLogic

TestCase {
    name: "WorkspaceLogic"

    function test_defaultAndLiveWorkspaceIdsAreBoundedAndSorted() {
        const values = [
            {
                "id": 8
            },
            {
                "id": -99
            },
            {
                "id": 3
            },
            {
                "id": 11
            }
        ];
        compare(WorkspaceLogic.workspaceIds(values, 5), [1, 2, 3, 4, 5, 8]);
        compare(WorkspaceLogic.validId("7"), 7);
        compare(WorkspaceLogic.validId(0), 0);
        compare(WorkspaceLogic.validId("bad"), 0);
    }

    function test_recordsPreserveEventBackedState() {
        const records = WorkspaceLogic.records([
            {
                "id": 2,
                "name": "work",
                "active": true,
                "urgent": true,
                "hasFullscreen": true,
                "monitor": {
                    "name": "DP-1"
                },
                "toplevels": {
                    "values": [
                        {}
                    ]
                }
            }
        ], 2, 2);
        compare(records.length, 2);
        verify(records[1].focused);
        verify(records[1].active);
        verify(records[1].urgent);
        verify(records[1].fullscreen);
        verify(records[1].occupied);
        compare(records[1].monitorName, "DP-1");
        verify(WorkspaceLogic.sameRecord(records[1], records[1]));
    }

    function monitorWorkspaces() {
        return [
            {
                "id": 1,
                "active": true,
                "focused": true,
                "monitor": {
                    "name": "eDP-1"
                }
            },
            {
                "id": 2,
                "active": false,
                "focused": false,
                "monitor": {
                    "name": "eDP-1"
                }
            },
            {
                "id": 3,
                "active": true,
                "focused": false,
                "monitor": {
                    "name": "DP-1"
                }
            }
        ];
    }

    function test_monitorIndicatorsIgnoreFocusChanges() {
        const values = monitorWorkspaces();
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
        values[0].focused = false;
        values[2].focused = true;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
    }

    function test_workspaceChangeOnlyUpdatesItsMonitor() {
        const values = monitorWorkspaces();
        values[0].active = false;
        values[1].active = true;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 2);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
    }

    function test_monitorReassignmentAndRemoval() {
        const values = monitorWorkspaces();
        values[0].monitor = {
            "name": "DP-1"
        };
        values[2].monitor = {
            "name": "eDP-1"
        };
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 3);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 1);
        values[2].monitor = null;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 0);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "FALLBACK"), 0);
        compare(WorkspaceLogic.activeIdForMonitor(values, ""), 0);
        compare(WorkspaceLogic.activeIdForMonitor(null, "DP-1"), 0);
    }
}
